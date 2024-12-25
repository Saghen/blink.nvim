--- @class blink.delimiters.Parser
--- @field definition blink.delimiters.LanguageDefinition
--- @field parse_line fun(line: string, state: blink.delimiters.ParserState): blink.delimiters.Match[], blink.delimiters.ParserState
--- @field parse fun(lines: string[])

--- @class blink.delimiters.Match
--- @field text string
--- @field row integer
--- @field col integer
--- @field closing? string If the match is an opening delimiter, this will close it

--- @class blink.delimiters.MatchWithHighlight : blink.delimiters.Match
--- @field highlight string

--- @enum blink.delimiters.ParserState
local States = {
  CODE = 1,
  STRING = 2,
  BLOCK_STRING = 3,
  BLOCK_COMMENT = 4,
}

local config = require('blink.delimiters.config')
local utils = require('blink.delimiters.utils')
local parser = {}

--- @param definition blink.delimiters.LanguageDefinition
function parser.new(definition)
  local self = setmetatable({}, { __index = parser })

  self.delimiter_openers = definition.delimiters
  self.delimiter_closers = {}
  for k, v in pairs(definition.delimiters) do
    self.delimiter_closers[v] = k
  end

  self.block_comment_opener = definition.block_comment[1]
  self.block_comment_closer = definition.block_comment[2]

  self.block_string_opener = definition.block_string[1]
  self.block_string_closer = definition.block_string[1]

  self.line_comment = definition.line_comment
  self.string = definition.string

  self.definition = definition

  self.attached_buffers = {}
  self.buffer_parsed_by_line = {}
  self.buffer_matches_with_highlights_by_line = {}
  self.buffer_stacks_by_line = {}

  -- Cleanup on buffer delete
  vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(event)
      self.attached_buffers[event.buf] = nil
      self.buffer_parsed_by_line[event.buf] = nil
      self.buffer_matches_with_highlights_by_line[event.buf] = nil
      self.buffer_stacks_by_line[event.buf] = nil
    end,
  })

  return self
end

--- @class blink.delimiters.ParsedLine
--- @field matches blink.delimiters.Match[]
--- @field state blink.delimiters.ParserState
--- @field reset_state_on string | nil

--- @param line_number number
--- @param line string
--- @param state blink.delimiters.ParserState
--- @param reset_state_on? string
--- @return blink.delimiters.ParsedLine
function parser:parse_line(line_number, line, state, reset_state_on)
  local matches = {}
  local is_escaped = false

  -- PERF: create is_block_comment_opener, ... that check the string char by char

  local char
  for i = 1, #line do
    char = line:sub(i, i)

    --- Escaped characters
    --- TODO: handle escaped new lines such as for line strings
    if char == '\\' then
      is_escaped = not is_escaped
      goto continue
    end
    if is_escaped then
      is_escaped = false
      goto continue
    end

    if state == States.BLOCK_COMMENT or state == States.BLOCK_STRING or state == States.STRING then
      assert(reset_state_on ~= nil, 'reset_state_on must be provided for strings, block strings and block comments')
      if line:sub(i, i + #reset_state_on - 1) == reset_state_on then
        state = States.CODE
        reset_state_on = nil
      end
      goto continue
    end

    -- state must be CODE because COMMENT immediately returns

    --- Block Comments/Strings
    -- check for these first since i.e. for lua, they're an extension of the line comment/string
    if self.block_comment_opener and line:sub(i, i + #self.block_comment_opener - 1) == self.block_comment_opener then
      state = States.BLOCK_COMMENT
      reset_state_on = self.block_comment_closer
      goto continue
    end

    if self.block_string_opener and line:sub(i, i + #self.block_string_opener - 1) == self.block_string_opener then
      state = States.BLOCK_STRING
      reset_state_on = self.block_string_closer
      goto continue
    end

    --- Line comments/strings
    -- immediately return for line comments since they must go until the end of line
    for _, line_comment in ipairs(self.line_comment) do
      if line:sub(i, i + #line_comment - 1) == line_comment then
        return { matches = matches, state = States.CODE, reset_state_on = nil }
      end
    end

    for _, string in ipairs(self.string) do
      if line:sub(i, i + #string - 1) == string then
        state = States.STRING
        reset_state_on = string
        goto continue
      end
    end

    --- Parenthesis
    if self.delimiter_openers[char] then
      table.insert(matches, {
        text = char,
        row = line_number,
        col = i,
        closing = self.delimiter_openers[char],
      })
    end
    if self.delimiter_closers[char] then
      table.insert(matches, {
        text = char,
        row = line_number,
        col = i,
      })
    end

    ::continue::
  end

  return {
    matches = matches,
    state = state,
    reset_state_on = reset_state_on,
  }
end

function parser:attach_to_buffer(bufnr)
  if self.attached_buffers[bufnr] ~= nil then return end
  self.attached_buffers[bufnr] = true

  self:incremental_parse(bufnr, 1, 0, vim.api.nvim_buf_line_count(bufnr))
  self:incremental_highlights(bufnr, 1, 0, vim.api.nvim_buf_line_count(bufnr))

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, _, start, old_end, new_end)
      -- detach if we're no longer attached
      if self.attached_buffers[bufnr] == nil then return true end
      vim.print('Update range, Start: ' .. start .. ', Old end: ' .. old_end .. ', New end: ' .. new_end)

      self:incremental_parse(bufnr, start + 1, old_end, new_end)
      self:incremental_highlights(bufnr, start + 1, old_end, new_end)
    end,
  })
end

--- Incrementally updates the parsed lines
--- @param bufnr number
--- @param start number 0-indexed
--- @param old_end number 0-indexed
--- @param new_end number 0-indexed
--- @return blink.delimiters.ParsedLine[]
function parser:incremental_parse(bufnr, start, old_end, new_end)
  local start_time = vim.loop.hrtime()

  self.buffer_parsed_by_line[bufnr] = self.buffer_parsed_by_line[bufnr] or {}
  local parsed_by_line = self.buffer_parsed_by_line[bufnr]

  -- Parse all of the new lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, start - 1, new_end, false)
  local new_parsed_by_lines = utils.map_accum(
    lines,
    parsed_by_line[start - 1] or { state = States.CODE }, -- previous parsed line
    function(last_parsed_line, line, line_number)
      line_number = line_number + start - 1
      return self:parse_line(line_number, line, last_parsed_line.state, last_parsed_line.reset_state_on)
    end
  )
  utils.splice(parsed_by_line, start, old_end, new_parsed_by_lines)

  if config.debug then vim.print('parsing time: ' .. (vim.loop.hrtime() - start_time) / 1e6 .. ' ms') end
end

--- Incrementally updates the highlights from the parsed lines
--- @param bufnr number
--- @param start number 1-indexed
--- @param old_end number 1-indexed
--- @param new_end number 1-indexed
--- @return blink.delimiters.MatchWithHighlight[][]
function parser:incremental_highlights(bufnr, start, old_end, new_end)
  local start_time = vim.loop.hrtime()

  local parsed_by_line = self.buffer_parsed_by_line[bufnr]
  assert(parsed_by_line ~= nil, 'incremental_parse must be called before incremental_highlights')

  self.buffer_matches_with_highlights_by_line[bufnr] = self.buffer_matches_with_highlights_by_line[bufnr] or {}
  local matches_with_highlights_by_line = self.buffer_matches_with_highlights_by_line[bufnr]

  self.buffer_stacks_by_line[bufnr] = self.buffer_stacks_by_line[bufnr] or {}
  local stacks_by_line = self.buffer_stacks_by_line[bufnr]

  local highlights = config.highlights

  local new_matches_with_highlights_by_line, new_stacks_by_line = utils.map_accum(
    utils.slice(parsed_by_line, start, new_end),
    stacks_by_line[start - 1] or {}, -- previous stack
    function(stack, parsed_line)
      stack = utils.shallow_copy(stack)

      local matches = {}
      for _, match in ipairs(parsed_line.matches) do
        --- @cast match blink.delimiters.MatchWithHighlight
        local opening_match = stack[#stack]

        -- opening delimiter
        if match.closing then
          match.highlight = highlights[#stack % #highlights + 1]
          table.insert(stack, match)
          table.insert(matches, match)

        -- closing delimiter
        -- TODO: maybe search down the stack a bit, in case there's an opening delimiter that's not closed
        elseif opening_match ~= nil and opening_match.closing == match.text then
          table.remove(stack)
          match.highlight = highlights[#stack % #highlights + 1]
          table.insert(matches, match)
        end
      end
      return matches, stack
    end
  )

  local last_stack = new_stacks_by_line[#new_stacks_by_line] or {}
  local previous_stack_for_line = stacks_by_line[old_end] or {}

  utils.splice(matches_with_highlights_by_line, start, old_end, new_matches_with_highlights_by_line)
  utils.splice(stacks_by_line, start, old_end, new_stacks_by_line)

  -- If the stack has changed, we re-highlight everything
  -- TODO: we should instead only re-highlight lines until we reach a stack that is equal
  if not vim.deep_equal(last_stack, previous_stack_for_line) and new_end ~= vim.api.nvim_buf_line_count(bufnr) then
    vim.print('Stack changed')
    vim.print(previous_stack_for_line)
    vim.print(last_stack)
    self:incremental_highlights(
      bufnr,
      new_end + 1,
      #matches_with_highlights_by_line,
      vim.api.nvim_buf_line_count(bufnr)
    )
  end

  if config.debug then vim.print('highlighting time: ' .. (vim.loop.hrtime() - start_time) / 1e6 .. ' ms') end
end

return parser

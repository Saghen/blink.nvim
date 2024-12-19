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

  self.buffer_parsed_lines = {}
  self.buffer_highlights = {}

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
  if self.buffer_parsed_lines[bufnr] ~= nil then return end
  self.buffer_parsed_lines[bufnr] = {}
  local parsed_lines = self.buffer_parsed_lines[bufnr]

  local function parse(first_line, old_last_line, new_last_line)
    local start_time = vim.loop.hrtime()

    -- Parse all of the new lines
    local previous_parsed_line = parsed_lines[first_line] or { state = States.CODE }
    local lines = vim.api.nvim_buf_get_lines(bufnr, first_line, new_last_line, false)
    for line_number, line in ipairs(lines) do
      line_number = line_number + first_line
      local parsed_line =
        self:parse_line(line_number, line, previous_parsed_line.state, previous_parsed_line.reset_state_on)
      previous_parsed_line = parsed_line

      if line_number <= old_last_line then
        parsed_lines[line_number] = parsed_line
      else
        table.insert(parsed_lines, line_number, parsed_line)
      end
    end

    -- Remove the previous parsed lines, outside of the new range
    for i = new_last_line, old_last_line - 1 do
      table.remove(parsed_lines, i + 1)
    end

    -- Reassign the highlights
    self.buffer_highlights[bufnr] = parser:assign_highlights(parsed_lines, config.highlights)

    if config.debug then vim.print('parsing time: ' .. (vim.loop.hrtime() - start_time) / 1e6 .. ' ms') end
  end

  parse(0, 0, vim.api.nvim_buf_line_count(bufnr))

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, _, first_line, old_last_line, new_last_line)
      parse(first_line, old_last_line, new_last_line)
    end,
  })
end

--- @param parsed_lines blink.delimiters.ParsedLine[]
--- @param highlights string[]
--- @return blink.delimiters.MatchWithHighlight[][]
function parser:assign_highlights(parsed_lines, highlights)
  local matches_by_line_with_highlights = {}
  --- @type blink.delimiters.MatchWithHighlight[]
  local stack = {}
  local highlight_idx = 0

  for line_number, parsed_line in pairs(parsed_lines) do
    local matches = parsed_line.matches
    matches_by_line_with_highlights[line_number] = {}
    for _, match in ipairs(matches) do
      --- @cast match blink.delimiters.MatchWithHighlight

      -- opening delimiter
      if match.closing then
        table.insert(stack, match)

        match.highlight = highlights[highlight_idx % #highlights + 1]
        highlight_idx = highlight_idx + 1
        table.insert(matches_by_line_with_highlights[line_number], match)

      -- closing delimiter
      -- TODO: maybe search down the stack a bit, in case there's an opening delimiter that's not closed
      else
        local opening_match = stack[#stack]
        if opening_match ~= nil and opening_match.closing == match.text then
          table.remove(stack)

          highlight_idx = highlight_idx - 1
          match.highlight = highlights[highlight_idx % #highlights + 1]
          table.insert(matches_by_line_with_highlights[line_number], match)
        end
      end
    end
  end

  return matches_by_line_with_highlights
end

return parser

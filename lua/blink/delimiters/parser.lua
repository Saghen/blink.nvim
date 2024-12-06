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

local parser = {}

--- @param definition blink.delimiters.LanguageDefinition
function parser.new(definition)
  local self = setmetatable({}, { __index = parser })

  self.delimiter_openers = vim.tbl_keys(definition.delimiters)
  self.delimiter_closers = vim.tbl_values(definition.delimiters)
  self.delimiters = definition.delimiters

  self.block_comment_opener = definition.block_comment[1]
  self.block_comment_closer = definition.block_comment[2]

  self.block_string_opener = definition.block_string[1]
  self.block_string_closer = definition.block_string[1]

  self.line_comment = definition.line_comment
  self.string = definition.string

  self.definition = definition
  return self
end

--- @param line_number number
--- @param line string
--- @param state blink.delimiters.ParserState
--- @param reset_state_on? string
--- @return blink.delimiters.Match[], blink.delimiters.ParserState, string | nil
function parser:parse_line(line_number, line, state, reset_state_on)
  local matches = {}
  local is_escaped = false
  for i = 1, #line do
    local char = line:sub(i, i)
    local log = function(msg)
      if require('blink.delimiters.config').debug then
        vim.print(string.format('%d:%d: "%s" %s', line_number, i, char, msg))
      end
    end

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
      log('block comment')
      state = States.BLOCK_COMMENT
      reset_state_on = self.block_comment_closer
      goto continue
    end

    if self.block_string_opener and line:sub(i, i + #self.block_string_opener - 1) == self.block_string_opener then
      log('block string')
      state = States.BLOCK_STRING
      reset_state_on = self.block_string_closer
      goto continue
    end

    --- Line comments/strings
    -- immediately return for line comments since they must go until the end of line
    for _, line_comment in ipairs(self.line_comment) do
      if line:sub(i, i + #line_comment - 1) == line_comment then
        log('line comment')
        return matches, States.CODE, nil
      end
    end

    for _, string in ipairs(self.string) do
      if line:sub(i, i + #string - 1) == string then
        log('string')
        state = States.STRING
        reset_state_on = string
        goto continue
      end
    end

    --- Parenthesis
    if vim.tbl_contains(self.delimiter_openers, char) then
      log('delimiter opening')
      local closing = self.delimiters[char]
      table.insert(matches, {
        text = char,
        row = line_number,
        col = i,
        closing = closing,
      })
    end
    if vim.tbl_contains(self.delimiter_closers, char) then
      log('delimiter closing')
      table.insert(matches, {
        text = char,
        row = line_number,
        col = i,
      })
    end

    ::continue::
  end

  return matches, state, reset_state_on
end

function parser:parse_buffer(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local all_matches = {}
  local state = States.CODE
  local reset_state_on = nil

  for line_number, line in ipairs(lines) do
    local line_matches, line_state, line_reset_state_on = self:parse_line(line_number, line, state, reset_state_on)
    all_matches[line_number] = line_matches
    state = line_state
    reset_state_on = line_reset_state_on
  end

  return all_matches
end

--- @param matches_by_line blink.delimiters.Match[][]
--- @param highlights string[]
--- @return blink.delimiters.MatchWithHighlight[][]
function parser:asign_highlights(matches_by_line, highlights)
  local matches_by_line_with_highlights = {}
  --- @type blink.delimiters.MatchWithHighlight[]
  local stack = {}
  local highlight_idx = 0

  for line_number, matches in pairs(matches_by_line) do
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

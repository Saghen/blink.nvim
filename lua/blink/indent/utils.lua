local M = {}

local config = require('blink.indent.config')

local blocked_filetypes = {}
for _, ft in ipairs(config.blocked.filetypes) do
  blocked_filetypes[ft] = true
end

local blocked_buftypes = {}
for _, buftype in ipairs(config.blocked.buftypes) do
  blocked_buftypes[buftype] = true
end

function M.get_shiftwidth(bufnr)
  local shiftwidth = vim.api.nvim_get_option_value('shiftwidth', { buf = bufnr })
  -- todo: is this correct?
  if shiftwidth == 0 then shiftwidth = vim.api.nvim_get_option_value('tabstop', { buf = bufnr }) end
  -- default to 2 if shiftwidth and tabwidth are 0
  return math.max(shiftwidth, 2)
end

function M.get_line_indent_level(bufnr, line_number, shiftwidth)
  local line = M.get_line(bufnr, line_number)

  local whitespace_chars = line:match('^%s*')
  local whitespace_char_count = string.len(string.gsub(whitespace_chars, '\t', string.rep(' ', shiftwidth)))

  return whitespace_char_count / shiftwidth, #whitespace_chars == #line
end

function M.get_indent_level(line, shiftwidth)
  local whitespace_chars = line:match('^%s*')
  local whitespace_char_count = string.len(string.gsub(whitespace_chars, '\t', string.rep(' ', shiftwidth)))

  return math.floor(whitespace_char_count / shiftwidth), #whitespace_chars == #line
end

function M.get_line(bufnr, line_idx) return vim.api.nvim_buf_get_lines(bufnr, line_idx - 1, line_idx, false)[1] end

function M.get_rainbow_hl(idx, underline)
  local hl_groups = underline and config.highlights.underline_groups or config.highlights.groups
  return hl_groups[(math.floor(idx)) % #hl_groups + 1]
end

M.is_buf_blocked = function(buf)
  local filetype = vim.api.nvim_get_option_value('filetype', { buf = buf })
  local is_blocked_filetype = blocked_filetypes[filetype] ~= nil

  local buftype = vim.api.nvim_get_option_value('buftype', { buf = buf })
  local is_blocked_buftype = blocked_buftypes[buftype] ~= nil

  return is_blocked_filetype or is_blocked_buftype
end

M.get_win_scroll_range = function(winnr)
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  -- Get the scrolled range (start and end line)
  local start_line = math.max(1, vim.fn.line('w0', winnr) - 1)
  local end_line = math.max(start_line, math.min(line_count, vim.fn.line('w$', winnr) + 1))

  local horizontal_offset = vim.fn.winsaveview().leftcol

  return { bufnr = bufnr, start_line = start_line, end_line = end_line, horizontal_offset = horizontal_offset }
end

return M

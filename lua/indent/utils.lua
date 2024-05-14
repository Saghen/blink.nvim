local M = {}

local blocked_filetypes = {
  lspinfo = true,
  packer = true,
  checkhealth = true,
  help = true,
  man = true,
  gitcommit = true,
  TelescopePrompt = true,
  TelescopeResults = true,
  dashboard = true,
  [''] = true,
}
local blocked_buftypes = { terminal = true, quickfix = true, nofile = true, prompt = true }
local rainbow_hl_groups = { 'RainbowOrange', 'RainbowPurple', 'RainbowBlue' }
local rainbow_underline_hl_groups = { 'RainbowOrangeUnderline', 'RainbowPurpleUnderline', 'RainbowBlueUnderline' }

function M.get_shiftwidth(bufnr) return math.max(vim.api.nvim_buf_get_option(bufnr, 'shiftwidth'), 1) end

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
  local hl_groups = underline and rainbow_underline_hl_groups or rainbow_hl_groups
  return hl_groups[(math.floor(idx) - 1) % #hl_groups + 1]
end

M.is_buf_blocked = function(buf)
  local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
  local is_blocked_filetype = blocked_filetypes[filetype] ~= nil

  local buftype = vim.api.nvim_buf_get_option(buf, 'buftype')
  local is_blocked_buftype = blocked_buftypes[buftype] ~= nil

  return is_blocked_filetype or is_blocked_buftype
end

M.get_scroll_range = function()
  local start_line = math.max(1, vim.fn.line('w0') - 1)
  local end_line = vim.fn.line('w$')

  return { start_line, end_line }
end

return M

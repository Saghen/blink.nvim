local M = {}

-- implementation from https://github.com/saifulapm/chartoggle.nvim
-- todo: make a blink plugin with config, delimiters per language, filetype blocklist
function M.toggle_char_eol(character)
  local api = vim.api
  local delimiters = { ',', ';' }

  local mode = api.nvim_get_mode().mode
  local is_visual = mode == 'v' or mode == 'V' or mode == '\22' -- <C-v>

  -- have to exit visual mode for the marks to update
  if is_visual then vim.fn.feedkeys(':', 'nx') end

  local start_line = is_visual and vim.fn.getpos("'<")[2] or api.nvim_win_get_cursor(0)[1]
  local end_line = is_visual and vim.fn.getpos("'>")[2] or start_line

  for line_idx = start_line, end_line do
    local line = api.nvim_buf_get_lines(0, line_idx - 1, line_idx, false)[1]
    local last_char = line:sub(-1)

    if last_char == character then
      api.nvim_buf_set_lines(0, line_idx - 1, line_idx, false, { line:sub(1, #line - 1) })
    elseif vim.tbl_contains(delimiters, last_char) then
      api.nvim_buf_set_lines(0, line_idx - 1, line_idx, false, { line:sub(1, #line - 1) .. character })
    else
      api.nvim_buf_set_lines(0, line_idx - 1, line_idx, false, { line .. character })
    end
  end
end

return M

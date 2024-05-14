local M = {}

Utils = require('blink.indent.utils')

M.partial_draw = function(ns, indent_levels, bufnr, start_line, end_line, min_start_line, max_end_line)
  local shiftwidth = Utils.get_shiftwidth(bufnr)
  local symbol = '▎'

  local previous_indent_level = indent_levels[math.max(1, start_line - 1)]
  local indent_level = indent_levels[start_line]

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local starting_from_next_line = cursor_line + 1 == start_line

  -- nothing to do
  if indent_level == 0 then return end

  -- highlight the line above the first line if it has a lower indent level
  -- and we didn't start from that line
  if start_line > 1 and not starting_from_next_line then
    -- if previous_indent_level < indent_level then
    -- 	local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 2, start_line - 1, false)[1]
    -- 	local whitespace_chars = line:match('^%s*')
    -- 	vim.api.nvim_buf_add_highlight(
    -- 		bufnr,
    -- 		ns,
    -- 		Utils.get_rainbow_hl(previous_indent_level, true),
    -- 		start_line - 2,
    -- 		#whitespace_chars,
    -- 		-1
    -- 	)
    -- end
    indent_level = previous_indent_level
  elseif starting_from_next_line then
    indent_level = previous_indent_level
  end

  -- apply the highlight
  local hl_group = Utils.get_rainbow_hl(indent_level)
  for i = math.max(min_start_line, start_line), math.min(max_end_line, end_line) do
    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
      virt_text = { { symbol, hl_group } },
      virt_text_pos = 'overlay',
      virt_text_win_col = indent_level * shiftwidth,
      hl_mode = 'combine',
      priority = 2,
    })
  end
end

return M

-- Adds a virtual text to the left of the line to show the indent level
-- Somewhat equivalent to indent-blankline but fast
local Utils = require('blink.indent.utils')

local M = {}

M.attached_bufs = {}

M.setup = function(config)
  local static = require('blink.indent.static')
  local scope = require('blink.indent.scope')

  M.deferred = false

  local ns = vim.api.nvim_create_namespace('indent')

  vim.api.nvim_create_autocmd({ 'BufEnter', 'FileType' }, {
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local is_blocked = Utils.is_buf_blocked(bufnr)
      if is_blocked then
        M.attached_bufs[bufnr] = nil
        -- fixme: should clear
        return
      end
      M.attached_bufs[bufnr] = true
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'CursorMoved', 'CursorMovedI', 'WinScrolled' }, {
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      if M.attached_bufs[bufnr] == nil then return end
      local scroll_range = Utils.get_scroll_range()
      measure_time(function()
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        local indent_levels, scope_range = M.get_indent_levels(bufnr, scroll_range[1], scroll_range[2])
        scope.partial_draw(ns, indent_levels, bufnr, scope_range[1], scope_range[2], scroll_range[1], scroll_range[2])
        static.partial_draw(ns, indent_levels, bufnr, scroll_range[1], scroll_range[2])
      end, 0)
    end,
  })
end

M.get_indent_levels = function(bufnr, start_line, end_line)
  local indent_levels = {}
  local shiftwidth = Utils.get_shiftwidth(bufnr)

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local scope_indent_level = Utils.get_indent_level(Utils.get_line(bufnr, cursor_line), shiftwidth)
  local scope_next_line = Utils.get_line(bufnr, cursor_line + 1)
  local scope_next_indent_level = scope_next_line ~= nil and Utils.get_indent_level(scope_next_line, shiftwidth)
    or scope_indent_level

  -- start from the next line if it's indent level its higher
  local starting_from_next_line = scope_next_indent_level > scope_indent_level
  if starting_from_next_line then
    cursor_line = cursor_line + 1
    scope_indent_level = scope_next_indent_level
  end

  -- move up and down to find the scope
  local scope_start_line = cursor_line
  while scope_start_line > 1 do
    local prev_indent_level, is_all_whitespace = Utils.get_line_indent_level(bufnr, scope_start_line - 1, shiftwidth)
    indent_levels[scope_start_line - 1] = prev_indent_level

    if not is_all_whitespace and scope_indent_level > prev_indent_level then break end
    scope_start_line = scope_start_line - 1
  end
  local scope_end_line = cursor_line
  while scope_end_line < end_line do
    local next_indent_level, is_all_whitespace = Utils.get_line_indent_level(bufnr, scope_end_line + 1, shiftwidth)
    indent_levels[scope_end_line + 1] = next_indent_level

    if not is_all_whitespace and scope_indent_level > next_indent_level then break end
    scope_end_line = scope_end_line + 1
  end

  start_line = math.min(start_line, scope_start_line)
  end_line = math.max(end_line, scope_end_line)

  -- fill in remaining lines with their indent levels
  for line_number = start_line, end_line do
    if indent_levels[line_number] == nil then
      local indent_level = Utils.get_line_indent_level(bufnr, line_number, shiftwidth)
      indent_levels[line_number] = indent_level
    end
  end

  return indent_levels, { scope_start_line, scope_end_line }
end

return M

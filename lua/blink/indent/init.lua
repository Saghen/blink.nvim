-- Adds a virtual text to the left of the line to show the indent level
-- Somewhat equivalent to indent-blankline but fast
local Utils = require('blink.indent.utils')

local M = {}

M.setup = function(config)
  local ns = vim.api.nvim_create_namespace('indent')

  vim.api.nvim_create_autocmd({ 'WinScrolled', 'WinResized' }, {
    callback = function()
      local scroll_ranges = Utils.get_scroll_ranges_from_win_scrolled(vim.v.event)
      vim.defer_fn(function() M.draw(ns, scroll_ranges) end, 0)
    end,
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'CursorMoved', 'CursorMovedI' }, {
    pattern = '*',
    callback = function()
      local scroll_ranges = Utils.get_scroll_ranges(vim.api.nvim_get_current_buf())
      vim.defer_fn(function() M.draw(ns, scroll_ranges) end, 0)
    end,
  })
end

M.draw = function(ns, scroll_ranges)
  local static = require('blink.indent.static')
  local scope = require('blink.indent.scope')

  for _, range in ipairs(scroll_ranges) do
    if Utils.is_buf_blocked(range.bufnr) then goto continue end

    local indent_levels, scope_range = M.get_indent_levels(range.bufnr, range.start_line, range.end_line)
    vim.api.nvim_buf_clear_namespace(range.bufnr, ns, 0, -1)
    scope.partial_draw(ns, indent_levels, range.bufnr, scope_range[1], scope_range[2], range.start_line, range.end_line)
    static.partial_draw(ns, indent_levels, range.bufnr, range.start_line, range.end_line)

    ::continue::
  end
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

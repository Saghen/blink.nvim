-- Adds a virtual text to the left of the line to show the indent level
-- Somewhat equivalent to indent-blankline but fast

local M = {}

--- @param opts IndentConfig
M.setup = function(opts)
  -- todo: could also check filetype/buftype to see if the indents would be enabled
  vim.api.nvim_create_autocmd('BufEnter', { callback = function() M.internal_setup(opts) end, once = true })
end

--- @param opts IndentConfig
M.internal_setup = function(opts)
  local config = require('blink.indent.config')
  config.setup(opts)
  M.setup_hl_groups()

  local utils = require('blink.indent.utils')
  local ns = vim.api.nvim_create_namespace('indent')

  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, winnr, bufnr)
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      if not config.visible or utils.is_buf_blocked(bufnr) then return end

      local range = utils.get_win_scroll_range(winnr)
      if range.end_line == range.start_line then return end

      local indent_levels, scope_range = M.get_indent_levels(winnr, range.bufnr, range.start_line, range.end_line)
      if config.static.enabled then
        require('blink.indent.static').partial_draw(
          ns,
          indent_levels,
          range.bufnr,
          range.start_line,
          range.end_line,
          range.horizontal_offset
        )
      end
      if config.scope.enabled then
        require('blink.indent.scope').partial_draw(
          ns,
          indent_levels,
          range.bufnr,
          scope_range[1],
          scope_range[2],
          range.start_line,
          range.end_line,
          range.horizontal_offset
        )
      end
    end,
  })
end

M.get_indent_levels = function(winnr, bufnr, start_line, end_line)
  local utils = require('blink.indent.utils')

  local indent_levels = {}
  local shiftwidth = utils.get_shiftwidth(bufnr)

  local cursor_line = vim.api.nvim_win_get_cursor(winnr)[1]

  local scope_indent_level = utils.get_indent_level(utils.get_line(bufnr, cursor_line), shiftwidth)
  local scope_next_line = utils.get_line(bufnr, cursor_line + 1)
  local scope_next_indent_level = scope_next_line ~= nil and utils.get_indent_level(scope_next_line, shiftwidth)
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
    local prev_indent_level, is_all_whitespace = utils.get_line_indent_level(bufnr, scope_start_line - 1, shiftwidth)
    indent_levels[scope_start_line - 1] = prev_indent_level

    if not is_all_whitespace and scope_indent_level > prev_indent_level then break end
    scope_start_line = scope_start_line - 1
  end
  local scope_end_line = cursor_line
  while scope_end_line < end_line do
    local next_indent_level, is_all_whitespace = utils.get_line_indent_level(bufnr, scope_end_line + 1, shiftwidth)
    indent_levels[scope_end_line + 1] = next_indent_level

    if not is_all_whitespace and scope_indent_level > next_indent_level then break end
    scope_end_line = scope_end_line + 1
  end

  start_line = math.min(start_line, scope_start_line)
  end_line = math.max(end_line, scope_end_line)

  -- fill in remaining lines with their indent levels
  for line_number = start_line, end_line do
    if indent_levels[line_number] == nil then
      local indent_level = utils.get_line_indent_level(bufnr, line_number, shiftwidth)
      indent_levels[line_number] = indent_level
    end
  end

  return indent_levels, { scope_start_line, scope_end_line }
end

M.setup_hl_groups = function()
  vim.api.nvim_set_hl(0, 'BlinkIndent', { default = true, link = 'Whitespace' })

  local function set_hl(color, fg)
    vim.api.nvim_set_hl(0, 'BlinkIndent' .. color, { default = true, fg = fg, ctermfg = color:match('Indent(%w+)') })
    vim.api.nvim_set_hl(0, 'BlinkIndent' .. color .. 'Underline', { default = true, sp = fg, underline = true })
  end

  set_hl('Red', '#cc241d')
  set_hl('Orange', '#d65d0e')
  set_hl('Yellow', '#d79921')
  set_hl('Green', '#689d6a')
  set_hl('Cyan', '#a89984')
  set_hl('Blue', '#458588')
  set_hl('Violet', '#b16286')
end

--- Enables the visibility of indent guides
--- @return boolean success Returns true if state changed, false if already enabled
M.enable = function()
  local config = require('blink.indent.config')

  if config.visible then
    -- Already enabled
    return false
  end

  config.visible = true

  return true
end

--- Disables the visibility of indent guides
--- @return boolean success Returns true if state changed, false if already disabled
M.disable = function()
  local config = require('blink.indent.config')

  if not config.visible then
    -- Already disabled
    return false
  end

  config.visible = false
  local ns = vim.api.nvim_create_namespace('indent')

  -- Clear indent markers from all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end

  return true
end

--- Toggles the visibility of indent guides
--- @return boolean new_state Returns the new visibility state
M.toggle = function()
  local config = require('blink.indent.config')
  return config.visible and M.disable() or M.enable()
end

return M

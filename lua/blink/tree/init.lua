-- todo: symlinks
local api = vim.api
local M = {}

function M.setup()
  M.setup_highlights()

  local instance = require('blink.tree.window').new()

  vim.api.nvim_create_user_command('BlinkTree', function(args)
    local arg = args.args
    arg = arg or 'toggle'

    if arg == 'toggle' then
      instance:toggle()
    elseif arg == 'open' then
      instance:open()
    elseif arg == 'close' then
      instance:close()
    elseif arg == 'toggle-focus' then
      instance:toggle_focus()
    elseif arg == 'focus' then
      instance:focus()
    elseif arg == 'update' then
      instance:update()
    end
  end, { nargs = 1 })
end

function M.setup_highlights()
  api.nvim_set_hl(0, 'BlinkTreeNormal', { link = 'Normal', default = true })
  api.nvim_set_hl(0, 'BlinkTreeNormalNC', { link = 'NormalNC', default = true })
  api.nvim_set_hl(0, 'BlinkTreeSignColumn', { link = 'SignColumn', default = true })
  api.nvim_set_hl(0, 'BlinkTreeCursorLine', { link = 'CursorLine', default = true })
  api.nvim_set_hl(0, 'BlinkTreeFloatBorder', { link = 'FloatBorder', default = true })
  api.nvim_set_hl(0, 'BlinkTreeStatusLine', { link = 'StatusLine', default = true })
  api.nvim_set_hl(0, 'BlinkTreeStatusLineNC', { link = 'StatusLineNC', default = true })
  api.nvim_set_hl(0, 'BlinkTreeVertSplit', { link = 'VertSplit', default = true })
end

return M

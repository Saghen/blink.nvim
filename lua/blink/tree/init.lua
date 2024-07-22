-- todo: symlinks
local api = vim.api
local M = {}

function M.setup(opts)
  require('blink.tree.config').setup(opts)

  M.setup_highlights()

  local inst
  vim.api.nvim_create_user_command('BlinkTree', function(args)
    if inst == nil then inst = require('blink.tree.window').new() end

    local arg = args.args
    arg = arg or 'toggle'

    if arg == 'toggle' then
      inst:toggle()
    elseif arg == 'open' then
      inst:open()
    elseif arg == 'close' then
      inst:close()
    elseif arg == 'toggle-focus' then
      inst:toggle_focus()
    elseif arg == 'focus' then
      inst:focus()
    elseif arg == 'refresh' then
      inst:refresh()
    elseif arg == 'reveal' then
      inst:reveal()
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

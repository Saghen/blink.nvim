-- todo: symlinks
local api = vim.api
local M = {}

function M.setup(opts)
  require('blink.tree.config').setup(opts)

  M.setup_highlights()

  local inst
  vim.api.nvim_create_user_command('BlinkTree', function(info)
    if inst == nil then inst = require('blink.tree.window').new() end

    local args = vim.split(info.args, ' ')
    local command = args[1] or 'toggle'
    local silent = args[2] == 'silent'

    if command == 'toggle' then
      inst:toggle()
    elseif command == 'open' then
      inst:open(silent)
    elseif command == 'close' then
      inst:close()
    elseif command == 'toggle-focus' then
      inst:toggle_focus()
    elseif command == 'focus' then
      inst:focus()
    elseif command == 'refresh' then
      inst:refresh()
    elseif command == 'reveal' then
      inst:reveal(silent)
    end
  end, { nargs = '*' })
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

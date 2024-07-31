-- todo: symlinks
local api = vim.api
local M = {
  inst = nil,
}

function M.setup(opts)
  require('blink.tree.config').setup(opts)

  M.setup_highlights()

  vim.api.nvim_create_user_command('BlinkTree', function(info)
    local args = vim.split(info.args, ' ')
    local command = args[1] or 'toggle'
    local silent = args[2] == 'silent'

    if command == 'toggle' then
      M.toggle()
    elseif command == 'open' then
      M.open(silent)
    elseif command == 'close' then
      M.close()
    elseif command == 'toggle-focus' then
      M.toggle_focus()
    elseif command == 'focus' then
      M.focus()
    elseif command == 'refresh' then
      M.refresh()
    elseif command == 'reveal' then
      M.reveal(silent)
    end
  end, { nargs = '*' })
end

function M.get_inst()
  if M.inst == nil then M.inst = require('blink.tree.window').new() end
  return M.inst
end

function M.toggle() M.get_inst():toggle() end
function M.open(silent) M.get_inst():open(silent) end
function M.close() M.get_inst():close() end
function M.toggle_focus() M.get_inst():toggle_focus() end
function M.focus() M.get_inst():focus() end
function M.refresh() M.get_inst():refresh() end
function M.reveal(silent) M.get_inst():reveal(silent) end

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

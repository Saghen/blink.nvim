local api = vim.api

local Binds = {}

function Binds.attach_to_instance(inst)
  local function map(mode, lhs, callback, opts)
    opts = opts or {}
    opts.callback = function() callback(inst.renderer:get_hovered_node(), inst) end
    api.nvim_buf_set_keymap(inst.bufnr, mode, lhs, '', opts)
  end

  map('n', 'q', function() inst:close() end)
  map('n', 'R', function() inst.tree:refresh() end)

  local activate = require('blink.tree.binds.activate')
  local expand = require('blink.tree.binds.expand')
  map('n', '<CR>', activate)
  map('n', '<2-LeftMouse>', activate)
  map('n', '<Tab>', expand)

  local basic = require('blink.tree.binds.basic')
  map('n', 'a', basic.new_file)
  map('n', 'd', basic.delete_file)
  map('n', 'r', basic.rename_file)

  local move = require('blink.tree.binds.move')
  map('n', 'x', move.cut)
  map('n', 'y', move.copy)
  map('n', 'p', move.paste)
end

return Binds

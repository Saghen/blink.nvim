local Basic = {}

function Basic.new_file(hovered_node, inst)
  while hovered_node ~= nil and hovered_node.is_dir == false do
    hovered_node = hovered_node.parent
  end
  if hovered_node == nil then return end

  local popup = require('blink.tree.popup')
  local fs = require('blink.tree.lib.fs')

  popup.new_input({ title = 'New File (append / for dir)', title_pos = 'center' }, function(input)
    if input == nil then return end
    local final_path = fs.create_file(hovered_node.path, input)
    inst.tree:expand_path(final_path)
    inst.renderer:once_after_render(function() inst.renderer:select_path(final_path) end)
  end)
end

function Basic.delete_file(hovered_node)
  local uv = require('blink.tree.lib.uv')
  uv.exec_async({ command = { 'trash', hovered_node.path } }, function(code)
    if code ~= 0 then print('Failed to delete: ' .. hovered_node.path) end
  end)
end

function Basic.rename_file(hovered_node, inst)
  local popup = require('blink.tree.popup')
  local fs = require('blink.tree.lib.fs')

  if hovered_node == inst.tree.root then vim.print('Cannot rename root') end

  popup.new_input({ title = 'Rename', title_pos = 'center', initial_text = hovered_node.filename }, function(input)
    local new_path = hovered_node.parent.path .. '/' .. input
    -- FIXME: would break if they rename the top level dir
    fs.rename(hovered_node.path, new_path)
    inst.tree:expand_path(new_path)
    inst.renderer:once_after_render(function() inst.renderer:select_path(new_path) end)
  end)
end

return Basic

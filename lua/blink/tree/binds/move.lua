local Move = {}

function Move.cut(node, inst)
  node.flags.copy = false
  node.flags.cut = not node.flags.cut
  inst.renderer:redraw()
end

function Move.copy(node, inst)
  node.flags.cut = false
  node.flags.copy = not node.flags.copy
  inst.renderer:redraw()
end

function Move.paste(hovered_node, inst)
  while hovered_node ~= nil and hovered_node.is_dir == false do
    hovered_node = hovered_node.parent
  end
  if hovered_node == nil then return end

  local lib_tree = require('blink.tree.lib.tree')
  local cut_nodes = {}
  local copied_nodes = {}
  lib_tree.traverse(inst.tree.root, function(node)
    if node.flags.cut then
      table.insert(cut_nodes, node)
    elseif node.flags.copy then
      table.insert(copied_nodes, node)
    end
  end)

  local fs = require('blink.tree.lib.fs')
  for _, cut_node in ipairs(cut_nodes) do
    fs.rename(cut_node.path, hovered_node.path .. '/' .. cut_node.filename)
    cut_node.flags.cut = false
  end
  for _, copied_node in ipairs(copied_nodes) do
    fs.copy_file(copied_node.path, hovered_node.path .. '/' .. copied_node.filename)
    copied_node.flags.copy = false
  end

  inst.renderer:redraw()
end

return Move

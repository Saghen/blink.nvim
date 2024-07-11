local fs = require('blink.tree.lib.fs')
local lib_tree = require('blink.tree.lib.tree')
local Tree = {}

function Tree.new(path, on_changed)
  local self = setmetatable({}, { __index = Tree })
  self.path = path
  self.root = lib_tree.make_root(path)
  self.on_changed = on_changed

  -- immediately build
  lib_tree.build_tree(self.root, function(tree)
    self.root = tree
    self:on_changed()
  end, function() self:on_changed() end)

  return self
end

--------------------
--- Public API

function Tree:collapse(node)
  if not node.expanded then return end

  node.expanded = false
  lib_tree.clear_watch(node)

  self:on_changed()
end

function Tree:expand(node, callback)
  if node.expanded then return end

  node.expanded = true
  local on_initial = function()
    self:on_changed()
    if callback then callback() end
  end
  local on_change = function() self:on_changed() end

  lib_tree.build_tree(node, on_initial, on_change)
end

function Tree:expand_path(path, callback)
  callback = callback or function() end
  if not fs.path_starts_with(path, self.root.path) then return callback('Path is not contained in tree', nil) end

  local function expand_and_recurse(node, cb)
    for _, child in ipairs(node.children) do
      if fs.path_starts_with(path, child.path) then
        return self:expand(child, function()
          -- final child
          if child.path == path then return cb(nil, child) end
          -- or recurse
          return expand_and_recurse(child, cb)
        end)
      end
    end

    return callback('Path not found', nil)
  end

  expand_and_recurse(self.root, callback)
end

function Tree:find_node_by_path(path, parent)
  parent = parent or self.root
  if parent.path == path then return parent end

  for _, child in ipairs(parent.children) do
    if fs.path_starts_with(path, child.path) then return self:find_node_by_path(path, child) end
  end

  return nil
end

function Tree:destroy()
  lib_tree.traverse(self.root, function(node)
    if node.watch_unsubscribe then node.watch_unsubscribe() end
    if node.git_repo then node.git_repo:destroy() end
  end)
end

---------------------
--- On Changed

function Tree:aggregate_changed(cb)
  local on_changed = self.on_changed
  local was_changed = false
  self.on_changed = function() was_changed = true end

  cb()

  self.on_changed = on_changed
  if was_changed then self:on_changed() end
end

function Tree:aggregate_changed_async(cb)
  local on_changed = self.on_changed
  local was_changed = false
  self.on_changed = function() was_changed = true end

  cb(function()
    self.on_changed = on_changed
    if was_changed then self:on_changed() end
  end)
end

function Tree:on_changed()
  if self.on_changed then self:on_changed() end
end

return Tree

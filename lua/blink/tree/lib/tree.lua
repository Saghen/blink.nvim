local config = {
  hide_dotfiles = true,
  hide = { ['node_modules'] = true, ['.git'] = true, ['.cache'] = true },
  never_show = { ['.git'] = true, ['node_modules'] = true },
}

local Tree = {}

function Tree.make_root(path)
  -- replace home with ~
  local filename = path
  local home = vim.env.HOME
  if home ~= nil and vim.startswith(path, home) then filename = '~' .. string.sub(path, string.len(home) + 1) end

  local node = Tree.make_node(nil, path, filename, true)
  node.expanded = true
  return node
end

function Tree.make_node(parent, path, filename, is_dir)
  local node = {
    parent = parent,
    children = {},

    path = path,
    filename = filename,
    is_dir = is_dir,
    expanded = false,

    flags = {
      cut = false,
      copy = false,
    },
  }

  return node
end

function Tree.destroy_node(node)
  if node.git_repo then node.git_repo.destroy() end

  if node.children then
    for _, child in ipairs(node.children) do
      Tree.destroy_node(child)
    end
  end
end

function Tree.new(filename, is_dir, expanded)
  return {
    filename = filename,
    is_dir = is_dir,
    expanded = expanded,
    children = {},
  }
end

-- loops through the nodes and treats the second argument as the source
-- of truth, adding and removing nodes as needed, but using the object reference
-- from the first list whenever possible
function Tree.merge_nodes(old_nodes, nodes)
  local old_node_count = #old_nodes
  local changed = false

  local merged_nodes = {}

  -- FIXME: probably breaks if theres two files like FILE.md and file.md
  local old_node_idx = 1
  for _, node in ipairs(nodes) do
    while old_node_idx <= old_node_count do
      local old_node = old_nodes[old_node_idx]

      if not old_node.is_dir and node.is_dir then goto continue end
      if old_node.is_dir == node.is_dir and string.lower(old_node.filename) >= string.lower(node.filename) then
        goto continue
      end

      old_node_idx = old_node_idx + 1
      changed = true
    end
    ::continue::

    if old_node_idx <= old_node_count and old_nodes[old_node_idx].filename == node.filename then
      table.insert(merged_nodes, old_nodes[old_node_idx])
      old_node_idx = old_node_idx + 1
      Tree.destroy_node(node) -- didn't include new node so we destroy it
    else
      table.insert(merged_nodes, node)
      changed = true
    end
  end

  -- didn't include all the previous nodes
  if old_node_idx < old_node_count then changed = true end

  -- destroy old nodes that weren't included
  -- TODO: probably slow
  for i = old_node_idx, old_node_count do
    local old_node = old_nodes[i]
    if not vim.tbl_contains(merged_nodes, old_node) then Tree.destroy_node(old_node) end
  end

  return merged_nodes, changed
end

function Tree.make_children(parent, entries)
  local children = {}

  -- scan directory and build nodes
  for _, entry in ipairs(entries) do
    local path = parent.path .. '/' .. entry.name
    local node = Tree.make_node(parent, path, entry.name, entry.type == 'directory')
    if config.never_show[node.filename] == nil then table.insert(children, node) end
  end

  -- sort by name (insensitive) and then by type (dir first)
  table.sort(children, function(a, b)
    if a.is_dir == b.is_dir then return string.lower(a.filename) < string.lower(b.filename) end
    return a.is_dir
  end)

  return children
end

function Tree.build_tree(parent, on_initial, on_change)
  local fs = require('blink.tree.lib.fs')
  local git = require('blink.tree.git')
  if not parent.is_dir or not parent.expanded or parent.watch_unsubscribe then
    on_initial(parent, false)
    return
  end

  local is_initial = true
  parent.watch_unsubscribe = fs.watch_dir(parent.path, function(entries)
    -- check if this is a git repo
    if not parent.git_repo then
      for _, entry in ipairs(entries) do
        if entry.type == 'directory' and entry.name == '.git' then
          parent.git_repo = git.new(parent.path, on_change)
          break
        end
      end
    end

    local cb = is_initial and on_initial or on_change
    is_initial = false

    -- update the children
    local children, changed = Tree.merge_nodes(parent.children, Tree.make_children(parent, entries))
    parent.children = children

    -- scan child directories and hook up the on_change cb
    local pending_scans = 0
    for _, child in ipairs(children) do
      -- scan child directories
      if child.is_dir and child.expanded then
        pending_scans = pending_scans + 1

        Tree.build_tree(child, function(_, child_changed)
          changed = changed or child_changed
          pending_scans = pending_scans - 1
          if pending_scans == 0 then cb(parent, changed) end
        end, on_change)
      end
    end

    -- no child directories
    if pending_scans == 0 then cb(parent, changed) end
  end)
end

function Tree.clear_watch(node)
  Tree.traverse(node, function()
    if node.watch_unsubscribe then
      node.watch_unsubscribe()
      node.watch_unsubscribe = nil
    end
  end)
end

function Tree.get_repo(node)
  local repo = node.git_repo
  local parent = node.parent
  while parent ~= nil and repo == nil do
    repo = parent.git_repo
    parent = parent.parent
  end
  return repo
end

function Tree.traverse(node, cb)
  cb(node)
  for _, child in ipairs(node.children) do
    Tree.traverse(child, cb)
  end
end

return Tree

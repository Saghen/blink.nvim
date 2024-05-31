local uv = vim.loop
local config = {
  hide_dotfiles = true,
  hide = { ['node_modules'] = true, ['.git'] = true, ['.cache'] = true },
  never_show = { ['.git'] = true, ['node_modules'] = true },
}

local tree = require('blink.tree.tree')

local Filesystem = {}

function Filesystem.scan_dir(parent)
  local children = {}
  if parent.is_dir == false then return children end

  -- open directory, return early if failed
  local handle = uv.fs_scandir(parent.path)
  if handle == nil then return children end

  -- scan directory and build nodes
  while true do
    local name, type = uv.fs_scandir_next(handle)
    if name == nil then break end

    local path = parent.path .. '/' .. name

    local node = tree.make_node(parent, path, type == 'directory')
    if config.never_show[node.filename] == nil then table.insert(children, node) end
  end

  -- sort by name (insensitive) and then by type (dir first)
  table.sort(children, function(a, b)
    if a.is_dir == b.is_dir then return string.lower(a.filename) < string.lower(b.filename) end
    return a.is_dir
  end)

  return children
end

function Filesystem.build_tree(root)
  if root.is_dir == false then return root end
  root.children = require('blink.tree.filesystem').scan_dir(root)

  for _, child in ipairs(root.children) do
    if child.is_dir then Filesystem.build_tree(child) end
  end

  return root
end

return Filesystem

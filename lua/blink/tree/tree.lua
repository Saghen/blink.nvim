local config = {
  hide_dotfiles = true,
  hide = { ['node_modules'] = true, ['.git'] = true, ['.cache'] = true },
  never_show = { ['.git'] = true, ['node_modules'] = true },
}

local Tree = {}

function Tree.make_root()
  local path = vim.fn.getcwd()

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
    ignored = config.hide[path] or false,
    expanded = false,

    cut = false,
    copy = false,
  }

  return node
end

return Tree

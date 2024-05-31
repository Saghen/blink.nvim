local sep = '/'
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

  return {
    path = path,
    children = {},
    filename = filename,
    is_dir = true,
    ignored = false,
    expanded = true,
  }
end

function Tree.make_node(parent, path, is_dir)
  local node = {
    parent = parent,
    children = {},

    path = path,
    filename = string.match(path, '[^' .. sep .. ']+$'),
    is_dir = is_dir,
    ignored = config.hide[path] or false,
    expanded = true,
  }

  return node
end

return Tree

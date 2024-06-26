-- todo: manage number of open files to ensure we don't go over limit
-- likely via a queue of some sort

local sep = '/'
local uv = vim.loop
local config = {
  hide_dotfiles = true,
  hide = { ['node_modules'] = true, ['.git'] = true, ['.cache'] = true },
  -- never_show = {},
  never_show = { ['.git'] = true, ['node_modules'] = true },
}

local tree = require('blink.tree.tree')

local Filesystem = {}

function Filesystem.create_path(root_dir, path)
  -- Split the path into parts
  local parts = {}
  for part in string.gmatch(path, '([^/]+)') do
    table.insert(parts, part)
  end

  -- Ensure no invalid parts
  for _, part in ipairs(parts) do
    if part == '.' or part == '..' or part == '' then error('Invalid path: contains "." or ".." or ""') end
  end

  -- Construct the full path
  local full_path = root_dir
  for i, part in ipairs(parts) do
    full_path = full_path .. '/' .. part
    print('full_path', full_path)
    local part_type = i == #parts and not vim.endswith(part, '/') and 'file' or 'directory'
    local stat = vim.loop.fs_stat(full_path)

    local exists = stat ~= nil and stat.type == part_type
    if exists then
      if part_type == 'file' then error('File already exists: ' .. full_path) end
      goto continue
    end

    -- Create the file
    if part_type == 'file' then
      local fd = vim.loop.fs_open(full_path, 'w', 438) -- 438 is 0666 in octal
      if fd then
        vim.loop.fs_close(fd)
      else
        error('Failed to create file: ' .. full_path)
      end
    -- Create the directory
    else
      local success, err = pcall(vim.loop.fs_mkdir, full_path, 493) -- 493 is 0755 in octal
      if not success then error('Failed to create directory: ' .. full_path .. ' (' .. err .. ')') end
    end

    ::continue::
  end
end

function Filesystem.rename_path(old_path, new_path)
  local success, err = pcall(vim.lsp.util.rename, old_path, new_path)
  if not success then error('Failed to rename: ' .. old_path .. ' -> ' .. new_path .. ' (' .. err .. ')') end
end

function Filesystem.copy_path(old_path, new_path)
  local success, err = pcall(vim.loop.fs_copyfile, old_path, new_path)
  if not success then error('Failed to copy: ' .. old_path .. ' -> ' .. new_path .. ' (' .. err .. ')') end
end

function Filesystem.scan_dir(parent, callback)
  local children = {}
  if parent.is_dir == false then
    -- print('Error: not a directory: ' .. parent.path)
    callback(children)
    return
  end

  -- open directory, return early if failed
  uv.fs_opendir(parent.path, function(err, handle)
    if err ~= nil or handle == nil then
      -- print('Error opening directory: ' .. parent.path .. ' ' .. (err or 'nil'))
      callback(children)
      return
    end

    uv.fs_readdir(handle, function(err, entries)
      uv.fs_closedir(handle)
      if err ~= nil or entries == nil then
        -- print('Error reading directory: ' .. parent.path .. ' ' .. (err or 'nil'))
        callback(children)
        return
      end

      -- scan directory and build nodes
      for _, entry in ipairs(entries) do
        local path = parent.path .. sep .. entry.name
        local node = tree.make_node(parent, path, entry.name, entry.type == 'directory')
        if config.never_show[node.filename] == nil then table.insert(children, node) end
      end

      -- sort by name (insensitive) and then by type (dir first)
      table.sort(children, function(a, b)
        if a.is_dir == b.is_dir then return string.lower(a.filename) < string.lower(b.filename) end
        return a.is_dir
      end)

      callback(children)
    end)
  end, 200)
end

-- loops through the nodes and treats the second argument as the source
-- of truth, adding and removing nodes as needed, but using the object reference
-- from the first list whenever possible
function Filesystem.merge_nodes(old_nodes, nodes)
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
    else
      table.insert(merged_nodes, node)
      changed = true
    end
  end

  -- didn't include all the previous nodes
  if old_node_idx < old_node_count then changed = true end

  return merged_nodes, changed
end

function Filesystem.build_tree(parent, callback)
  if parent.is_dir == false then
    callback(parent, false)
    return
  end

  Filesystem.scan_dir(parent, function(children)
    local merged_children, changed = Filesystem.merge_nodes(parent.children, children)
    parent.children = merged_children
    -- changed = true

    -- scan child directories if they're expanded
    local pending = 0
    for _, child in ipairs(merged_children) do
      if child.is_dir and child.expanded then
        pending = pending + 1

        Filesystem.build_tree(child, function(_, child_changed)
          changed = changed or child_changed
          pending = pending - 1
          if pending == 0 then callback(parent, changed) end
        end)
      end
    end

    -- no child directories
    if pending == 0 then callback(parent, changed) end
  end)
end

return Filesystem

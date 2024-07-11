-- todo: manage number of open files to ensure we don't go over limit
-- likely via a queue of some sort

local sep = '/'
local uv = vim.loop
local config = {
  hide_dotfiles = true,
  hide = { ['.cache'] = true },
  never_show = { ['.git'] = true, ['node_modules'] = true },
}

local FS = {}

function FS.create_file(root_dir, path)
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
    full_path = full_path .. sep .. part
    local part_type = i == #parts and not vim.endswith(path, sep) and 'file' or 'directory'
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

  return full_path
end

function FS.rename(old_path, new_path)
  local success, err = pcall(vim.lsp.util.rename, old_path, new_path)
  if not success then error('Failed to rename: ' .. old_path .. ' -> ' .. new_path .. ' (' .. err .. ')') end
end

function FS.copy_file(old_path, new_path)
  local success, err = pcall(vim.loop.fs_copyfile, old_path, new_path)
  if not success then error('Failed to copy: ' .. old_path .. ' -> ' .. new_path .. ' (' .. err .. ')') end
end

function FS.read_file(path)
  local fd = vim.loop.fs_open(path, 'r', 438) -- 438 is 0666 in octal
  if not fd then error('Failed to open file: ' .. path) end

  local data = vim.loop.fs_read(fd, vim.loop.fs_stat(path).size, 0)
  vim.loop.fs_close(fd)

  return data
end

function FS.read_file_async(path, callback)
  uv.fs_open(path, 'r', 438, function(open_err, fd)
    if open_err or fd == nil then return callback(open_err) end

    local callback_and_close = function(err, data)
      uv.fs_close(fd, function() end)
      callback(err, data)
    end

    uv.fs_stat(path, function(stat_err, stat)
      if stat_err or stat == nil then return callback_and_close(stat_err) end
      uv.fs_read(fd, stat.size, 0, callback_and_close)
    end)
  end)
end

function FS.scan_dir_async(path, callback)
  -- open directory, return early if failed
  -- todo: don't limit to 200 entries
  uv.fs_opendir(path, function(err, handle)
    if err ~= nil or handle == nil then
      -- print('Error opening directory: ' .. parent.path .. ' ' .. (err or 'nil'))
      callback({})
      return
    end

    uv.fs_readdir(handle, function(err, entries)
      uv.fs_closedir(handle)
      if err ~= nil or entries == nil then
        -- print('Error reading directory: ' .. parent.path .. ' ' .. (err or 'nil'))
        callback({})
        return
      end
      callback(entries)
    end)
  end, 200)
end

function FS.watch_dir(path, callback)
  local handle = uv.new_fs_event()
  if handle == nil then error('Failed to create fs event handle') end

  FS.scan_dir_async(path, function(entries)
    callback(entries)

    -- begin watching
    handle:start(path, {}, function() FS.scan_dir_async(path, callback) end)
  end)

  -- unsubscribe
  return function() handle:stop() end
end

function FS.path_starts_with(path, prefix)
  path = path[#path] == sep and path or path .. sep
  prefix = prefix[#prefix] == sep and prefix or prefix .. sep
  return vim.startswith(path, prefix)
end

return FS

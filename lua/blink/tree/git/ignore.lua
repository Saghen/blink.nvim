local uv = vim.uv
local ignore = {}

function ignore.new(path)
  local self = setmetatable({}, { __index = ignore })
  self.path = path
  self.ignore = {}

  return self
end

function ignore:read()
  local fd = uv.fs_open(self.path, 'r', 438)
  if not fd then return end

  local data = uv.fs_read(fd, uv.fs_stat(self.path).size, 0)
  uv.fs_close(fd)

  if not data then return end
  self.ignore = vim.split(data, '\n')
end

function ignore.rule_to_matcher(rule)
  local pattern = rule:gsub('\\', '/')
  if rule:sub(1, 1) == '/' then pattern = '^' .. pattern end
  if rule:sub(-1, -1) == '/' then pattern = pattern .. '$' end

  return function(path)
    path = path:gsub('\\', '/')
    return vim.startswith(path, pattern)
  end
end

function ignore:is_ignored(path)
  path = path:gsub('\\', '/')
  for _, pattern in ipairs(self.ignore) do
    if vim.startswith(path, pattern) then return true end
  end
  return false
end

return ignore

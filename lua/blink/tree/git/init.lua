local Git = {}

local function debounce(func, wait)
  local timer
  return function(...)
    local args = { ... }
    if timer and not timer:is_closing() then timer:stop() end
    timer = vim.loop.new_timer()
    timer:start(
      wait,
      0,
      vim.schedule_wrap(function()
        timer:stop()
        if not timer:is_closing() then timer:close() end
        func(unpack(args))
      end)
    )
  end
end

function Git.new(path, on_change)
  local self = setmetatable({}, { __index = Git })
  self.path = path
  self.status = {}

  local git2 = require('blink.tree.git.git2')
  git2.init()

  local err
  self.repository, err = git2.Repository.open(path, false)
  if err > 0 then
    print('Failed to open repository: ' .. err)
    return
  end

  local debounced_update_status = debounce(function() self:update_status(on_change) end, 10)

  -- watch .git for changes
  self.watch_unsubscribe = require('blink.tree.lib.fs').watch_dir(path .. '/.git', debounced_update_status)

  -- poll every 5s
  vim.loop.new_timer():start(5000, 5000, function() debounced_update_status() end)

  return self
end

function Git:update_status(callback)
  callback = callback or function() end
  self.repository:status_async(function(status, err)
    if err > 0 then
      print('Failed to get status' .. err)
      callback()
    end

    self.status = {}
    for _, item in ipairs(status) do
      local path = self.path .. '/' .. (item.new_path or item.path)
      self.status[path] = item
    end
    -- print(vim.inspect(self.status))
    if callback then callback() end
  end)
end

function Git:get_status(path) return self.status[path] end

function Git.get_hl_for_status(status)
  local git = require('blink.tree.git.git2')
  local DELTA = git.GIT_DELTA

  local index_status = status.index_status

  local staged = index_status ~= DELTA.UNMODIFIED and index_status ~= DELTA.UNTRACKED
  if staged then return 'BlinkTreeGitStaged' end

  local worktree_status = status.worktree_status

  if worktree_status == DELTA.MODIFIED then return 'BlinkTreeGitModified' end
  if worktree_status == DELTA.RENAMED then return 'BlinkTreeGitRenamed' end
  if worktree_status == DELTA.ADDED then return 'BlinkTreeGitAdded' end
  if worktree_status == DELTA.CONFLICTED then return 'BlinkTreeGitConflict' end
  if worktree_status == DELTA.UNTRACKED then return 'BlinkTreeGitUntracked' end
end

function Git:destroy() self.watch_unsubscribe() end

return Git

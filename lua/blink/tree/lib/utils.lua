local api = vim.api
local Utils = {}

function Utils.pick_or_create_non_special_window()
  local wins = api.nvim_list_wins()
  table.insert(wins, 1, api.nvim_get_current_win())

  local ignore_list = { 'blink-tree', 'terminal', 'Trouble', 'qf', 'edgy' }
  local ignore = {}
  for _, ft in ipairs(ignore_list) do
    ignore[ft] = true
  end

  -- pick the first non-special window
  for _, win in ipairs(wins) do
    local buf = api.nvim_win_get_buf(win)
    local options = vim.bo[buf]
    if not ignore[options.filetype] and not ignore[options.buftype] then return win end
  end

  -- create a new window if all are special
  return api.nvim_open_win(0, false, {
    vertical = true,
    split = 'right',
  })
end

--- Debounces a function on the trailing edge. Automatically
--- `schedule_wrap()`s.
---
--- @param fn (function) Function to debounce
--- @param timeout (number) Timeout in ms
--- @returns (function, timer) Debounced function and timer. Remember to call
--- `timer:close()` at the end or you will leak memory!
function Utils.debounce(fn, timeout)
  local timer = vim.loop.new_timer()
  local wrapped_fn

  function wrapped_fn(...)
    local argv = { ... }
    local argc = select('#', ...)

    timer:start(timeout, 0, function() pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc)) end)
  end
  return wrapped_fn, timer
end

return Utils

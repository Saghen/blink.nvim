local utils = {}

-- keybindings
-- hack: should provide examples for each package manager
-- instead of doing it through config
function utils.keymap(mode, key, callback)
  vim.api.nvim_set_keymap(mode, key, '', {
    expr = true,
    noremap = true,
    silent = true,
    callback = function()
      local autocomplete = require('blink.cmp.windows.autocomplete')
      if not autocomplete.win:is_open() then return vim.api.nvim_replace_termcodes(key, true, false, true) end
      vim.schedule(callback)
    end,
  })
end

--- Gets the text under the cursor to be used for fuzzy matching
--- @param regex string | nil
--- @return string
function utils.get_query(regex)
  if regex == nil then regex = '[%w_\\-]+$' end

  local bufnr = vim.api.nvim_get_current_buf()

  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local current_col = vim.api.nvim_win_get_cursor(0)[2] - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, current_line, current_line + 1, false)[1]

  return string.sub(line, 1, current_col + 1):match(regex) or ''
end

--- Debounces a function on the trailing edge. Automatically
--- `schedule_wrap()`s.
---
--- @param fn (function) Function to debounce
--- @param timeout (number) Timeout in ms
--- @returns (function, timer) Debounced function and timer. Remember to call
--- `timer:close()` at the end or you will leak memory!
function utils.debounce(fn, timeout)
  local timer = vim.uv.new_timer()
  local wrapped_fn

  function wrapped_fn(...)
    local argv = { ... }
    local argc = select('#', ...)

    timer:start(timeout, 0, function() pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc)) end)
  end
  return wrapped_fn, timer
end

--- Shallow copy table
--- @generic T
--- @param t T
--- @return T
function utils.shallow_copy(t)
  local t2 = {}
  for k, v in pairs(t) do
    t2[k] = v
  end
  return t2
end

return utils

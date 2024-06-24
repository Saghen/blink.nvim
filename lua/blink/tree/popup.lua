local api = vim.api

local Popup = {}

-- function Popup.new()
--   self.winnr = nil
--   self.bufnr = nil
--   return self
-- end
--
function Popup:open(opts)
  if self.winnr ~= nil then return end

  opts = opts or {}
  opts.relative = opts.relative or 'cursor'
  opts.width = opts.width or 40
  opts.height = opts.height or 20
  opts.row = opts.row or 1
  opts.col = opts.col or 1
  opts.style = opts.style or 'minimal'
  opts.border = opts.border or 'single'

  self.bufnr = api.nvim_create_buf(false, true)
  self.winnr = api.nvim_open_win(self.bufnr, true, opts)
end

function Popup.new_input(opts, callback)
  local self = setmetatable({}, { __index = Popup })

  opts = opts or {}
  opts.width = opts.width or 40
  opts.height = opts.height or 1
  self:open(opts)

  -- enter insert mode
  api.nvim_feedkeys('i', 'n', true)

  local has_run = false
  local on_submit = function()
    if has_run then return end
    has_run = true

    local line = api.nvim_get_current_line()
    self:close()
    callback(line)
  end
  local on_abort = function()
    if has_run then return end
    has_run = true

    self:close()
    callback(nil)
  end

  -- listen for close events
  api.nvim_buf_set_keymap(self.bufnr, 'i', '<CR>', '', {
    callback = on_submit,
  })
  api.nvim_buf_set_keymap(self.bufnr, 'i', '<Esc>', '', {
    callback = on_abort,
  })
  api.nvim_buf_set_keymap(self.bufnr, 'i', '<C-c>', '', {
    callback = on_abort,
  })
  api.nvim_create_autocmd('WinLeave', {
    callback = on_abort,
    once = true,
  })
end

function Popup:close()
  if api.nvim_win_is_valid(self.winnr) then
    vim.api.nvim_win_close(self.winnr, true)
    self.winnr = nil
  end
  if api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_delete(self.bufnr, { force = true })
    self.bufnr = nil
  end
end

return Popup

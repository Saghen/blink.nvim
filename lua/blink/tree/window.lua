local api = vim.api

local Window = {}

function Window.new()
  local self = setmetatable({}, { __index = Window })
  self.winnr = -1
  self.bufnr = -1
  self.tree = require('blink.tree.tree').new(vim.fn.getcwd(), function() self:render() end)

  self.augroup = api.nvim_create_augroup('BlinkTreeWindow', { clear = true })

  api.nvim_create_autocmd('WinEnter', {
    group = self.augroup,
    callback = function()
      local current_win = api.nvim_get_current_win()
      if current_win == self.winnr then
        api.nvim_feedkeys(api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
      end
    end,
  })
  -- only allow the cursor to be on the first column which will always be empty
  -- avoiding issues with cursorword plugins
  api.nvim_create_autocmd('CursorMoved', {
    group = self.augroup,
    callback = function()
      if self.winnr == api.nvim_get_current_win() then
        local cursor = api.nvim_win_get_cursor(self.winnr)
        api.nvim_win_set_cursor(self.winnr, { cursor[1], 0 })
      end
    end,
  })

  -- recreate the tree on dir change
  api.nvim_create_autocmd('DirChanged', {
    group = self.augroup,
    callback = function()
      if not self.renderer then return end

      self.tree:destroy()
      self.tree = require('blink.tree.tree').new(vim.fn.getcwd(), function() self:render() end)
    end,
  })

  -- set buffer options
  api.nvim_create_autocmd('BufEnter', {
    group = self.augroup,
    callback = function()
      if vim.bo.filetype ~= 'blink-tree' then return end

      -- set local window options
      vim.cmd('setlocal winfixwidth')
      vim.cmd('setlocal cursorline')
      vim.cmd('setlocal cursorlineopt=line')
      vim.cmd('setlocal signcolumn=no')
      vim.cmd('setlocal nowrap')
      vim.cmd('setlocal nolist nospell nonumber norelativenumber')
      vim.cmd(
        'setlocal winhighlight=Normal:BlinkTreeNormal,NormalNC:BlinkTreeNormalNC,SignColumn:BlinkTreeSignColumn,CursorLine:BlinkTreeCursorLine,FloatBorder:BlinkTreeFloatBorder,StatusLine:BlinkTreeStatusLine,StatusLineNC:BlinkTreeStatusLineNC,VertSplit:BlinkTreeVertSplit,EndOfBuffer:BlinkTreeEndOfBuffer'
      )
    end,
  })

  -- hide the cursor when window is focused
  -- todo: should use winenter and winleave instead?
  local prev_cursor
  local prev_blend
  api.nvim_create_autocmd('BufEnter', {
    group = self.augroup,
    callback = function()
      if vim.bo.filetype == 'blink-tree' and prev_cursor == nil then
        prev_cursor = api.nvim_get_option_value('guicursor', {})
        api.nvim_set_option_value('guicursor', 'n:block-Cursor', {})

        local cursor_hl = api.nvim_get_hl(0, { name = 'Cursor' })
        prev_blend = cursor_hl.blend
        api.nvim_set_hl(0, 'Cursor', vim.tbl_extend('force', cursor_hl, { blend = 100 }))
      end
    end,
  })
  api.nvim_create_autocmd('BufLeave', {
    group = self.augroup,
    callback = function()
      if prev_cursor ~= nil then
        api.nvim_set_option_value('guicursor', prev_cursor, {})
        prev_cursor = nil

        local cursor_hl = api.nvim_get_hl(0, { name = 'Cursor' })
        api.nvim_set_hl(0, 'Cursor', vim.tbl_extend('force', cursor_hl, { blend = prev_blend or 0 }))
        prev_blend = nil
      end
    end,
  })

  -- prevent buffer from being changed
  -- api.nvim_create_autocmd('BufEnter', {
  --   callback = function()
  --     -- ignore if not in tree window
  --     if self.winnr ~= api.nvim_get_current_win() or not api.nvim_win_is_valid(self.winnr) then return end
  --     if self.bufnr == api.nvim_get_current_buf() or not api.nvim_buf_is_valid(self.bufnr) then return end
  --     local bufnr = api.nvim_get_current_buf()
  --
  --     -- restore tree buffer to tree window
  --     api.nvim_win_set_buf(self.winnr, self.bufnr)
  --
  --     -- move new buffer to a non-tree window
  --     local winnr = require('blink.tree.lib.utils').pick_or_create_non_special_window()
  --     api.nvim_set_current_win(winnr)
  --     api.nvim_win_set_buf(winnr, bufnr)
  --   end,
  -- })

  return self
end

function Window:refresh()
  -- todo:
end

function Window:ensure_buffer()
  -- TODO: should check if buffer is valid and cleanup previous
  if api.nvim_buf_is_valid(self.bufnr) then return end

  self.bufnr = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = self.bufnr })
  api.nvim_set_option_value('filetype', 'blink-tree', { buf = self.bufnr })
  api.nvim_set_option_value('buflisted', false, { buf = self.bufnr })
  api.nvim_set_option_value('modifiable', false, { buf = self.bufnr })
  api.nvim_set_option_value('swapfile', false, { buf = self.bufnr })

  self.renderer = require('blink.tree.renderer').new(self.bufnr)

  require('blink.tree.binds').attach_to_instance(self)
end

function Window:render()
  vim.schedule(function()
    if
      not api.nvim_win_is_valid(self.winnr)
      or not api.nvim_buf_is_valid(self.bufnr)
      or not api.nvim_win_get_buf(self.winnr) == self.bufnr
    then
      return
    end
    self.nodes_by_line = self.renderer:render_window(self.winnr, self.tree.root)
  end)
end

function Window:open(silent)
  self:ensure_buffer()
  if self:is_open() then return end

  self.winnr = api.nvim_open_win(self.bufnr, not silent, {
    win = -1,
    vertical = true,
    split = 'left',
    width = 40,
  })
  -- HACK: why do I need to manually trigger this?
  local prev_win = vim.api.nvim_get_current_win()
  if silent then vim.api.nvim_set_current_win(self.winnr) end
  vim.cmd('do BufEnter')
  if silent then vim.api.nvim_set_current_win(prev_win) end

  self:render()
end

function Window:close()
  if not self:is_open() then return end

  -- if we're the last window, just replace the current buffer with a new buffer
  if api.nvim_tabpage_list_wins(0)[1] == self.winnr and #api.nvim_list_wins() == 1 then return vim.cmd('enew') end

  -- otherwise close the window
  api.nvim_win_close(self.winnr, true)
  self.winnr = -1
end

function Window:toggle()
  if self:is_open() then
    self:close()
  else
    self:open()
  end
end

function Window:toggle_focus()
  if not self:is_open() then return self:open() end

  local win = api.nvim_get_current_win()
  if win == self.winnr then
    vim.cmd('wincmd p')
  else
    api.nvim_set_current_win(self.winnr)
  end
end

function Window:focus()
  if not self:is_open() then return self:open() end
  api.nvim_set_current_win(self.winnr)
end

function Window:is_open()
  return api.nvim_win_is_valid(self.winnr)
    and api.nvim_win_get_buf(self.winnr) == self.bufnr
    and api.nvim_buf_is_valid(self.bufnr)
end

function Window:reveal()
  local current_buf_path = vim.fn.expand(vim.api.nvim_buf_get_name(0))
  if current_buf_path == '' then return end

  self.tree:expand_path(current_buf_path)
  self.renderer:once_after_render(function() self.renderer:select_path(current_buf_path) end)
end

return Window

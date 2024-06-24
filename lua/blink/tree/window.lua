local api = vim.api

local filesystem = require('blink.tree.filesystem')
local popup = require('blink.tree.popup')

local function pick_or_create_non_special_window()
  local wins = api.nvim_list_wins()
  table.insert(wins, 1, api.nvim_get_current_win())

  -- pick the first non-special window
  for _, win in ipairs(wins) do
    local buf = api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == '' then return win end
  end

  -- create a new window if all are special
  api.nvim_open_win(0, true, {
    win = -1,
    vertical = true,
    split = 'right',
  })

  return 0
end

local Window = {}

function Window.new()
  local self = setmetatable({}, { __index = Window })
  self.winnr = -1

  api.nvim_create_autocmd('WinEnter', {
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
    callback = function()
      if self.winnr == api.nvim_get_current_win() then
        local cursor = api.nvim_win_get_cursor(self.winnr)
        api.nvim_win_set_cursor(self.winnr, { cursor[1], 0 })
      end
    end,
  })

  -- update every 2s
  -- vim.loop.new_timer():start(
  --   2000,
  --   2000,
  --   vim.schedule_wrap(function()
  --     if self.winnr ~= nil then self:update(true) end
  --   end)
  -- )

  return self
end

function Window:ensure_buffer()
  -- TODO: should check if buffer is valid and cleanup previous
  if self.bufnr ~= nil then return end

  self.bufnr = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = self.bufnr })
  api.nvim_set_option_value('filetype', 'blink-tree', { buf = self.bufnr })
  api.nvim_set_option_value('modifiable', false, { buf = self.bufnr })

  self.renderer = require('blink.tree.renderer').new(self.bufnr)

  -- Keymaps
  local function map(mode, lhs, callback, opts)
    opts = opts or {}
    opts.callback = callback
    api.nvim_buf_set_keymap(self.bufnr, mode, lhs, '', opts)
  end

  local function activate()
    if self.nodes_by_line == nil then return end

    -- get the node for the line
    local hovered_node = self.renderer:get_hovered_node()
    if hovered_node == nil then return end

    if hovered_node.is_dir then
      -- toggle expanded and render
      hovered_node.expanded = not hovered_node.expanded
      self:update()
    else
      -- pick most recent non-special window
      local winnr = pick_or_create_non_special_window()
      api.nvim_set_current_win(winnr)

      -- open file
      vim.cmd('edit ' .. hovered_node.path)
    end
  end

  map('n', 'q', function() self:close() end)
  map('n', '<CR>', activate)
  map('n', '<2-LeftMouse>', activate)
  map('n', 'R', function() self:update() end)
  map('n', 'a', function()
    popup.new_input(
      { title = 'New File (append / for dir)', title_pos = 'center' },
      function(input) print('Input:', input) end
    )
  end)

  -- hide the cursor when window is focused
  local prev_cursor
  local prev_blend
  api.nvim_create_autocmd('BufEnter', {
    pattern = '<buffer=' .. self.bufnr .. '>',
    callback = function()
      if self.bufnr == api.nvim_get_current_buf() and prev_cursor == nil then
        prev_cursor = api.nvim_get_option_value('guicursor', {})
        print(prev_cursor)
        api.nvim_set_option_value('guicursor', 'n:block-Cursor', {})

        local cursor_hl = api.nvim_get_hl(0, { name = 'Cursor' })
        prev_blend = cursor_hl.blend
        api.nvim_set_hl(0, 'Cursor', vim.tbl_extend('force', cursor_hl, { blend = 100 }))
      end
    end,
  })
  api.nvim_create_autocmd('BufLeave', {
    pattern = '<buffer=' .. self.bufnr .. '>',
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
end

function Window:update(only_on_fs_change)
  local total_start = vim.loop.hrtime()
  -- use existing tree or create new one
  local root = self.tree or require('blink.tree.tree').make_root()

  local build_tree_start = vim.loop.hrtime()
  filesystem.build_tree(root, function(tree, changed)
    local build_tree_total = vim.loop.hrtime() - build_tree_start
    self.tree = tree

    local tree_size = 0
    local function count_nodes(node)
      tree_size = tree_size + 1
      for _, child in ipairs(node.children) do
        count_nodes(child)
      end
    end
    count_nodes(tree)

    -- nothing changed so don't render
    if not changed and only_on_fs_change then
      print('UNCHANGED | Tree Size: ' .. tree_size .. ' | Build tree: ' .. build_tree_total / 1e6 .. 'ms')
      return
    end

    vim.schedule(function()
      local render_start = vim.loop.hrtime()
      self:render()
      local render_total = vim.loop.hrtime() - render_start
      local total_time = vim.loop.hrtime() - total_start

      print(
        'CHANGED | Tree Size: '
          .. tree_size
          .. ' | Build tree: '
          .. build_tree_total / 1e6
          .. 'ms | Render: '
          .. render_total / 1e6
          .. 'ms | Total: '
          .. total_time / 1e6
          .. 'ms'
      )
    end)
  end)
end

function Window:render()
  if not api.nvim_win_is_valid(self.winnr) or self.tree == nil then return end
  self.nodes_by_line = self.renderer:render_window(self.winnr, self.tree)
end

function Window:open()
  self:ensure_buffer()
  if api.nvim_win_is_valid(self.winnr) then return end

  self.winnr = api.nvim_open_win(self.bufnr, true, {
    win = -1,
    vertical = true,
    split = 'left',
    width = 40,
  })
  api.nvim_set_option_value('signcolumn', 'no', { win = self.winnr })
  api.nvim_set_option_value('list', false, { win = self.winnr })
  api.nvim_set_option_value('wrap', false, { win = self.winnr })
  api.nvim_set_option_value('spell', false, { win = self.winnr })
  api.nvim_set_option_value('number', false, { win = self.winnr })
  api.nvim_set_option_value('relativenumber', false, { win = self.winnr })
  api.nvim_set_option_value(
    'winhighlight',
    'Normal:BlinkTreeNormal,NormalNC:BlinkTreeNormalNC,SignColumn:BlinkTreeSignColumn,CursorLine:BlinkTreeCursorLine,FloatBorder:BlinkTreeFloatBorder,StatusLine:BlinkTreeStatusLine,StatusLineNC:BlinkTreeStatusLineNC,VertSplit:BlinkTreeVertSplit,EndOfBuffer:BlinkTreeEndOfBuffer',
    { win = self.winnr }
  )

  self:update()
end

function Window:close()
  if api.nvim_win_is_valid(self.winnr) then
    api.nvim_win_close(self.winnr, true)
    self.winnr = -1
  end
end

function Window:toggle()
  if api.nvim_win_is_valid(self.winnr) then
    self:close()
  else
    self:open()
  end
end

function Window:toggle_focus()
  if not api.nvim_win_is_valid(self.winnr) then return self:open() end

  local win = api.nvim_get_current_win()
  if win == self.winnr then
    vim.cmd('wincmd p')
  else
    api.nvim_set_current_win(self.winnr)
  end
end

function Window:focus()
  if not api.nvim_win_is_valid(self.winnr) then return self:open() end
  api.nvim_set_current_win(self.winnr)
end

return Window

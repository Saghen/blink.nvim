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

  -- recreate the tree on dir change
  api.nvim_create_autocmd('DirChanged', {
    callback = function()
      self.tree = nil
      self:update()
    end,
  })

  -- poll based updating
  -- TODO: should be event based
  vim.loop.new_timer():start(
    1000,
    1000,
    vim.schedule_wrap(function()
      if self.winnr ~= nil then self:update(true) end
    end)
  )

  return self
end

function Window:ensure_buffer()
  -- TODO: should check if buffer is valid and cleanup previous
  if self.bufnr ~= nil and api.nvim_buf_is_valid(self.bufnr) then return end

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
    local node = self.renderer:get_hovered_node()
    while node ~= nil and node.is_dir == false do
      node = node.parent
    end
    if node == nil then return end

    popup.new_input({ title = 'New File (append / for dir)', title_pos = 'center' }, function(input)
      filesystem.create_path(node.path, input)
      self:update()
    end)
  end)
  map('n', 'd', function()
    local node = self.renderer:get_hovered_node()
    if node == nil then return end

    vim.loop.spawn('trash', { args = { node.path } }, function(code)
      if code ~= 0 then print('Failed to delete: ' .. node.path) end
      self:update()
    end)
  end)
  map('n', 'r', function()
    local node = self.renderer:get_hovered_node()
    if node == nil then return end

    popup.new_input({ title = 'Rename', title_pos = 'center', initial_text = node.filename }, function(input)
      -- FIXME: would break if they rename the top level dir
      filesystem.rename_path(node.path, node.parent.path .. '/' .. input)
      self:update()
    end)
  end)
  map('n', 'x', function()
    local node = self.renderer:get_hovered_node()
    if node == nil then return end

    node.cut = not node.cut
    self:update()
  end)
  map('n', 'y', function()
    local node = self.renderer:get_hovered_node()
    if node == nil then return end

    node.copy = not node.copy
    self:update()
  end)
  map('n', 'p', function()
    local node = self.renderer:get_hovered_node()
    while node ~= nil and node.is_dir == false do
      node = node.parent
    end
    if node == nil then return end

    local cut_nodes = {}
    local copied_nodes = {}
    local function traverse_cut_copied_nodes(node)
      if node.cut then
        table.insert(cut_nodes, node)
      elseif node.copy then
        table.insert(copied_nodes, node)
      end
      for _, child in ipairs(node.children) do
        traverse_cut_copied_nodes(child)
      end
    end
    traverse_cut_copied_nodes(self.tree)

    for _, cut_node in ipairs(cut_nodes) do
      filesystem.rename_path(cut_node.path, node.path .. '/' .. cut_node.filename)
      cut_node.cut = false
    end
    for _, copied_node in ipairs(copied_nodes) do
      filesystem.copy_path(copied_node.path, node.path .. '/' .. copied_node.filename)
      copied_node.copy = false
    end

    self:update()
  end)

  -- hide the cursor when window is focused
  local prev_cursor
  local prev_blend
  api.nvim_create_autocmd('BufEnter', {
    pattern = '<buffer=' .. self.bufnr .. '>',
    callback = function()
      if self.bufnr == api.nvim_get_current_buf() and prev_cursor == nil then
        prev_cursor = api.nvim_get_option_value('guicursor', {})
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
  -- use existing tree or create new one
  local root = self.tree or require('blink.tree.tree').make_root()

  filesystem.build_tree(root, function(tree, changed)
    self.tree = tree

    -- nothing changed so don't render
    if not changed and only_on_fs_change then return end
    -- otherwise render
    vim.schedule(function() self:render() end)
  end)
end

function Window:render()
  if not api.nvim_win_is_valid(self.winnr) or self.tree == nil then return end
  self.nodes_by_line = self.renderer:render_window(self.winnr, self.tree)
end

local function find_path(node, path)
  if node.path == path then return node end
  for _, child in ipairs(node.children) do
    local found = find_path(child, path)
    if found ~= nil then return found end
  end
  return nil
end

function Window:reveal()
  if not api.nvim_win_is_valid(self.winnr) or self.tree == nil then return end

  local file_path = api.nvim_buf_get_name(0)
  if file_path == '' then return end

  -- start from the top of the tree and keep expanding until we reach the file
  -- then render and put the cursor on the node
  local function expand_to_path(node, callback)
    if not vim.startswith(file_path, node.path) then return callback(self.tree) end

    node.expanded = true
    -- really jank, relies on node still being in the new tree
    filesystem.build_tree(self.tree, function(tree)
      node = find_path(tree, node.path)
      if node == nil then vim.print('Failed to find node for path: ' .. file_path) end

      for _, child in ipairs(node.children) do
        if vim.startswith(file_path, child.path) then
          expand_to_path(child, callback)
          return
        end
      end
      callback(tree)
    end)
  end
  expand_to_path(self.tree, function(tree)
    self.tree = tree
    vim.schedule(function()
      self:render()
      local node = find_path(self.tree, file_path)
      if node ~= nil then self.renderer:select_node(node) end
    end)
  end)
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

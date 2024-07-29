local window = {
  bufnr = -1,
  winnr = -1,
}

local api = vim.api
local augroup = vim.api.nvim_create_augroup('BlinkSelectWindow', { clear = true })
local config = require('blink.select.config')

local function width_clamp(desired_width)
  local max_width_columns = config.window.max_width[1]
  local max_width_percent = config.window.max_width[2]
  local max_width = math.min(max_width_columns, vim.o.columns * max_width_percent)

  local min_width_columns = config.window.min_width[1]
  local min_width_percent = config.window.min_width[2]
  local min_width = math.max(min_width_columns, vim.o.columns * min_width_percent)

  return math.max(math.min(desired_width, max_width), min_width)
end

function window.show(provider)
  window.prev_bufnr = vim.api.nvim_get_current_buf()
  window.provider = provider
  window.get_next_page = provider.get_items(#config.mapping.selection, window.prev_bufnr)
  window.pages = {}
  window.page_idx = 0

  window.open()
  window.next_page()
end

function window.get_buf()
  if window.bufnr ~= nil and api.nvim_buf_is_valid(window.bufnr) then return window.bufnr end

  window.bufnr = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = window.bufnr })
  api.nvim_set_option_value('filetype', 'blink-select', { buf = window.bufnr })
  api.nvim_set_option_value('bufhidden', 'wipe', { buf = window.bufnr })
  api.nvim_set_option_value('swapfile', false, { buf = window.bufnr })

  window.setup_mapping(window.bufnr)

  return window.bufnr
end

function window.open()
  if window.is_open() then return window.winnr end

  window.winnr = api.nvim_open_win(window.get_buf(), true, {
    relative = 'editor',
    width = 30,
    height = 10,
    row = 0,
    col = 0,
    style = 'minimal',
    border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
  })
  api.nvim_set_option_value('winhighlight', 'Normal:Pmenu,FloatBorder:Pmenu', { win = window.winnr })

  -- autocmds to hide cursor
  api.nvim_clear_autocmds({ group = augroup })

  local o = vim.o
  local opt = vim.opt
  local prev_cursor, prev_cursor_line, prev_cursor_column
  api.nvim_create_autocmd('WinEnter', {
    group = augroup,
    callback = function()
      if window.winnr == vim.api.nvim_get_current_win() then
        prev_cursor = o.guicursor
        prev_cursor_line = o.cursorline
        prev_cursor_column = o.cursorcolumn

        opt.guicursor = 'a:noCursor'
        opt.cursorline = false
        opt.cursorcolumn = false
      end
    end,
  })
  api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    callback = function()
      if window.winnr == vim.api.nvim_get_current_win() then
        opt.guicursor = prev_cursor
        opt.cursorline = prev_cursor_line
        opt.cursorcolumn = prev_cursor_column
      end
    end,
  })

  return window.winnr
end

function window.is_open() return window.winnr ~= nil and api.nvim_win_is_valid(window.winnr) end

function window.setup_mapping(bufnr)
  local mapping = config.mapping
  local map = function(lhs, rhs)
    api.nvim_buf_set_keymap(bufnr, 'n', lhs, '', {
      callback = rhs,
      nowait = true,
    })
  end
  for idx, key in ipairs(mapping.selection) do
    if key:upper() == key then error('Selection keys must be lowercase') end
    map(key, function() window.select(idx) end)
    map(key:upper(), function() window.alt_select(idx) end)
  end
  for _, key in ipairs(mapping.quit) do
    map(key, window.close)
  end
  for _, key in ipairs(mapping.next_page) do
    map(key, window.next_page)
  end
  for _, key in ipairs(mapping.prev_page) do
    map(key, window.prev_page)
  end
end

function window.render(items)
  local bufnr = window.get_buf()
  api.nvim_buf_set_lines(bufnr, 0, -1, false, {})

  for line_number, item in ipairs(items) do
    -- add the key to the fragments to render
    local key = config.mapping.selection[line_number]
    local fragments = { { ' ' .. key .. ' ', highlight = 'Primary' } }
    for _, fragment in ipairs(item.fragments) do
      table.insert(fragments, fragment)
    end

    -- render text
    local texts = {}
    for _, fragment in ipairs(fragments) do
      table.insert(texts, type(fragment) == 'string' and fragment or fragment[1])
    end
    api.nvim_buf_set_lines(bufnr, line_number - 1, line_number, false, { table.concat(texts) })

    -- render highlights
    local char = 0
    for fragment_idx, fragment in ipairs(fragments) do
      if fragment.highlight ~= nil then
        api.nvim_buf_add_highlight(bufnr, 0, fragment.highlight, line_number - 1, char, char + #texts[fragment_idx])
      end
      char = char + #texts[fragment_idx]
    end
  end

  -- set window width to fit longest line
  local max_width = 0
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    max_width = math.max(max_width, #line)
  end
  api.nvim_win_set_width(window.winnr, width_clamp(max_width))
  api.nvim_win_set_height(window.winnr, #items)

  -- center window on screen
  local win_info = api.nvim_win_get_config(window.winnr)
  local win_width = api.nvim_win_get_width(window.winnr)
  local win_height = api.nvim_win_get_height(window.winnr)
  local screen_width = vim.opt.columns:get()
  local screen_height = vim.opt.lines:get() - vim.opt.cmdheight:get()
  local row = math.floor((screen_height - win_height) / 2 - win_info.row)
  local col = math.floor((screen_width - win_width) / 2 - win_info.col)
  api.nvim_win_set_config(window.winnr, { relative = 'editor', row = row, col = col })
end

function window.close()
  api.nvim_clear_autocmds({ group = augroup })
  api.nvim_win_close(0, true)
end

function window.select(idx)
  window.close()
  window.provider.select(window.pages[window.page_idx][idx])
end

function window.alt_select(idx)
  window.close()
  local select_func = window.provider.alt_select or window.provider.select
  select_func(window.pages[window.page_idx][idx])
end

function window.next_page()
  if window.page_idx + 1 > #window.pages then
    local next_page = window.get_next_page()

    -- no data, close if we're on the first page and notify user
    if #next_page == 0 then
      if window.page_idx == 0 then
        vim.notify('No data from provider', vim.log.levels.INFO)
        window.close()
      end
      return
    end

    table.insert(window.pages, next_page)
  end

  window.page_idx = window.page_idx + 1
  window.render(window.pages[window.page_idx])
end

function window.prev_page()
  if window.page_idx - 1 < 1 then return end

  window.page_idx = window.page_idx - 1
  window.render(window.pages[window.page_idx])
end

return window

local window = {
  bufnr = -1,
  winnr = -1,
}

local api = vim.api
local augroup = vim.api.nvim_create_augroup('BlinkSelectWindow', { clear = true })
local config = require('blink.select.config')

local function center_text(text, width)
  local padding = math.floor(width / 2 - vim.fn.strdisplaywidth(text) / 2)
  return string.rep(' ', padding) .. text
end

-- hide the cursor when window is focused
local prev_cursor
local prev_blend
api.nvim_create_autocmd('BufEnter', {
  group = augroup,
  callback = function()
    if vim.bo.filetype == 'blink-select' and prev_cursor == nil then
      prev_cursor = api.nvim_get_option_value('guicursor', {})
      api.nvim_set_option_value('guicursor', 'a:Cursor/lCursor', {})

      local cursor_hl = api.nvim_get_hl(0, { name = 'Cursor' })
      prev_blend = cursor_hl.blend
      api.nvim_set_hl(0, 'Cursor', vim.tbl_extend('force', cursor_hl, { blend = 100 }))
    end
  end,
})
api.nvim_create_autocmd('BufLeave', {
  group = augroup,
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

local function width_clamp(desired_width)
  local max_width_columns = config.window.max_width[1]
  local max_width_percent = config.window.max_width[2]
  local max_width = math.floor(math.min(max_width_columns, vim.o.columns * max_width_percent))

  local min_width_columns = config.window.min_width[1]
  local min_width_percent = config.window.min_width[2]
  local min_width = math.ceil(math.max(min_width_columns, vim.o.columns * min_width_percent))

  return math.max(math.min(desired_width, max_width), min_width)
end

function window.show(provider)
  window.prev_bufnr = vim.api.nvim_get_current_buf()
  window.provider = provider

  provider.get_items({
    page_size = #config.mapping.selection,
    bufnr = window.prev_bufnr,
    alternate_bufnr = vim.fn.bufnr('#'),
  }, function(result)
    window.provider_next_page = result.next_page
    window.page_count = result.page_count
    window.pages = {}
    window.page_idx = 0

    vim.schedule(function()
      window.open()
      window.next_page()
    end)
  end)
end

function window.get_buf()
  if window.bufnr ~= nil and api.nvim_buf_is_valid(window.bufnr) then return window.bufnr end

  window.bufnr = api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = window.bufnr })
  api.nvim_set_option_value('filetype', 'blink-select', { buf = window.bufnr })
  api.nvim_set_option_value('swapfile', false, { buf = window.bufnr })
  api.nvim_set_option_value('modifiable', false, { buf = window.bufnr })

  window.setup_mapping(window.bufnr)

  return window.bufnr
end

function window.open()
  if window.is_open() then return window.winnr end

  -- open window
  window.winnr = api.nvim_open_win(window.get_buf(), true, {
    relative = 'editor',
    width = 30,
    height = 10,
    row = 0,
    col = 0,
    style = 'minimal',
    -- border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
    border = 'single',
    title = ' ' .. window.provider.name .. ' ',
    title_pos = 'center',
  })
  api.nvim_set_option_value(
    'winhighlight',
    'Normal:Normal,FloatBorder:Normal,FloatTitle:Normal',
    { win = window.winnr }
  )
  api.nvim_set_option_value('wrap', config.window.wrap, { win = window.winnr })

  api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    callback = function()
      if window.winnr == vim.api.nvim_get_current_win() then window.close() end
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
  api.nvim_set_option_value('modifiable', true, { buf = window.bufnr })

  local bufnr = window.get_buf()
  api.nvim_buf_set_lines(bufnr, 0, -1, false, { '' })

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
    api.nvim_buf_set_lines(bufnr, line_number, line_number + 1, false, { table.concat(texts) })

    -- render highlights
    local char = 0
    for fragment_idx, fragment in ipairs(fragments) do
      if fragment.highlight ~= nil then
        api.nvim_buf_add_highlight(bufnr, 0, fragment.highlight, line_number, char, char + #texts[fragment_idx])
      end
      char = char + #texts[fragment_idx]
    end
  end

  -- set window width to fit longest line
  local max_width = 0
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    max_width = math.max(max_width, #line)
  end
  local width = width_clamp(max_width)
  api.nvim_win_set_width(window.winnr, width)

  -- add the group separators
  for i = 1, math.floor(#items / config.window.group_size) - (math.fmod(#items, config.window.group_size) == 0 and 1 or 0) do
    local line = center_text(string.rep('─', math.fmod(width, 2) == 1 and 5 or 4), width)
    local line_number = i * config.window.group_size + i
    api.nvim_buf_set_lines(bufnr, line_number, line_number, false, { line })
  end

  -- add the bottom line with next/prev page mapping, current page, page count
  local page_info = center_text(string.format('Page %d/%d', window.page_idx, window.page_count), width)
  api.nvim_buf_set_lines(bufnr, -1, -1, false, { '', page_info })

  -- set window height to fit number of lines
  api.nvim_win_set_height(window.winnr, vim.api.nvim_buf_line_count(bufnr))

  -- center window on screen
  local win_width = api.nvim_win_get_width(window.winnr)
  local win_height = api.nvim_win_get_height(window.winnr)
  local screen_width = vim.o.columns
  local screen_height = vim.o.lines - vim.o.cmdheight
  local row = math.floor((screen_height - win_height) / 2)
  local col = math.floor((screen_width - win_width) / 2)
  api.nvim_win_set_config(window.winnr, { relative = 'editor', row = row, col = col })

  api.nvim_set_option_value('modifiable', false, { buf = window.bufnr })
end

function window.close() api.nvim_win_close(0, false) end

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
    return window.provider_next_page(function(next_page)
      -- no data, close if we're on the first page and notify user
      if #next_page == 0 then
        if window.page_idx == 0 then
          vim.notify('No data from provider', vim.log.levels.INFO)
          window.close()
        end
        return
      end

      table.insert(window.pages, next_page)

      window.page_idx = window.page_idx + 1
      window.render(window.pages[window.page_idx])
    end)
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

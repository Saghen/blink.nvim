local win = {}

--- @class blink.cmp.WindowOptions
--- @field min_width number
--- @field max_width number
--- @field max_height number
--- @field cursorline boolean
--- @field wrap boolean
--- @field filetype string
--- @field winhighlight string
--- @field padding boolean
--- @field scrolloff number

--- @class blink.cmp.Window
--- @field id number | nil
--- @field config blink.cmp.WindowOptions
---
--- @param config blink.cmp.WindowOptions
function win.new(config)
  local self = setmetatable({}, { __index = win })

  self.id = nil
  self.config = {
    min_width = config.min_width or 30,
    max_width = config.max_width or 60,
    max_height = config.max_height or 10,
    cursorline = config.cursorline or false,
    wrap = config.wrap or false,
    filetype = config.filetype or 'cmp_menu',
    winhighlight = config.winhighlight or 'Normal:NormalFloat,FloatBorder:NormalFloat',
    padding = config.padding,
    scrolloff = config.scrolloff or 0,
  }

  return self
end

--- @return number
function win:get_buf()
  -- create buffer if it doesn't exist
  if self.buf == nil or not vim.api.nvim_buf_is_valid(self.buf) then
    self.buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('tabstop', 1, { buf = self.buf }) -- prevents tab widths from being unpredictable
    vim.api.nvim_set_option_value('filetype', self.config.filetype, { buf = self.buf })
  end
  return self.buf
end

--- @return number
function win:get_win()
  if self.id ~= nil and not vim.api.nvim_win_is_valid(self.id) then self.id = nil end
  return self.id
end

--- @return boolean
function win:is_open() return self.id ~= nil and vim.api.nvim_win_is_valid(self.id) end

function win:open()
  -- window already exists
  if self.id ~= nil and vim.api.nvim_win_is_valid(self.id) then return end

  -- create window
  self.id = vim.api.nvim_open_win(self:get_buf(), false, {
    relative = 'cursor',
    style = 'minimal',
    width = self.config.min_width,
    height = self.config.max_height,
    row = 1,
    col = 1,
    focusable = false,
    zindex = 1001,
    border = self.config.padding and { ' ', '', '', '', '', '', ' ', ' ' } or { '', '', '', '', '', '', '', '' },
  })
  vim.api.nvim_set_option_value('winhighlight', self.config.winhighlight, { win = self.id })
  vim.api.nvim_set_option_value('wrap', self.config.wrap, { win = self.id })
  vim.api.nvim_set_option_value('foldenable', false, { win = self.id })
  vim.api.nvim_set_option_value('conceallevel', 2, { win = self.id })
  vim.api.nvim_set_option_value('concealcursor', 'n', { win = self.id })
  vim.api.nvim_set_option_value('cursorlineopt', 'line', { win = self.id })
  vim.api.nvim_set_option_value('cursorline', self.config.cursorline, { win = self.id })
  vim.api.nvim_set_option_value('scrolloff', self.config.scrolloff, { win = self.id })
end

function win:close()
  if self.id ~= nil then
    vim.api.nvim_win_close(self.id, true)
    self.id = nil
  end
end

function win:update_size()
  if not self:is_open() then return end
  local winnr = self:get_win()
  local config = self.config

  -- todo: never go above the screen width and height

  -- set width to current content width, bounded by min and max
  local width = math.max(math.min(self:get_content_width(), config.max_width), config.min_width)
  vim.api.nvim_win_set_width(winnr, width)

  -- set height to current line count, bounded by max
  local height = math.min(self:get_content_height(), config.max_height)
  vim.api.nvim_win_set_height(winnr, height)
end

-- todo: fix nvim_win_text_height
function win:get_content_height()
  if not self:is_open() then return 0 end
  return vim.api.nvim_win_text_height(self:get_win(), {}).all
end

function win:get_content_width()
  if not self:is_open() then return 0 end
  local max_width = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(self.buf, 0, -1, false)) do
    max_width = math.max(max_width, vim.api.nvim_strwidth(line))
  end
  return max_width
end

function win.get_screen_scroll_range()
  local bufnr = vim.api.nvim_win_get_buf(0)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  -- Get the scrolled range (start and end line)
  local start_line = math.max(1, vim.fn.line('w0') - 1)
  local end_line = math.max(start_line, math.min(line_count, vim.fn.line('w$') + 1))

  local horizontal_offset = vim.fn.winsaveview().leftcol

  return { bufnr = bufnr, start_line = start_line, end_line = end_line, horizontal_offset = horizontal_offset }
end

return win

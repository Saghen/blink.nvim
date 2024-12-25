local api = vim.api
local config = require('blink.select.config')
local renderer = {}

function renderer.new(bufnr)
  local self = setmetatable({}, { __index = renderer })
  self.bufnr = bufnr
  return self
end

--- @param fragments RenderFragment[]
function renderer:draw_line(fragments, line_number)
  -- render text
  local texts = {}
  for _, fragment in ipairs(fragments) do
    table.insert(texts, type(fragment) == 'string' and fragment or fragment[1])
  end
  api.nvim_buf_set_lines(self.bufnr, line_number, line_number + 1, false, { table.concat(texts) })

  -- render highlights
  local char = 0
  for fragment_idx, fragment in ipairs(fragments) do
    if fragment.highlight ~= nil then
      api.nvim_buf_add_highlight(self.bufnr, 0, fragment.highlight, line_number, char, char + #texts[fragment_idx])
    end
    char = char + #texts[fragment_idx]
  end
end

function renderer.draw(self, items) end


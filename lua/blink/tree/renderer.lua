local api = vim.api

local ns = api.nvim_create_namespace('blink_tree')

local Renderer = {}

function Renderer:render_node(line_number, node, indent)
  local prefix = ' ' .. string.rep('  ', indent)
  local icon, highlight = self:get_icon(node)
  local name = node.filename

  -- keep track of which node is associated with which line
  local nodes_by_lines = {}
  nodes_by_lines[line_number] = node

  local icon_spaces = '   '
  local line = prefix .. icon_spaces .. name
  local line_index = line_number - 1
  api.nvim_buf_set_lines(self.bufnr, line_index, line_index + 1, false, { line })

  -- update render state for decorations
  -- todo: calculate this on demand instead of storing it
  node.render_state = {
    icon = { hl = highlight, idx = #prefix, icon = icon },
  }

  if node.expanded then
    for _, child in ipairs(node.children) do
      local child_nodes_by_lines, new_line_number = self:render_node(line_number + 1, child, indent + 1)
      line_number = new_line_number
      for child_line_number, child_node in pairs(child_nodes_by_lines) do
        nodes_by_lines[child_line_number] = child_node
      end
    end
  end

  return nodes_by_lines, line_number
end

function Renderer.new(bufnr)
  local self = setmetatable({}, { __index = Renderer })
  self.nodes_by_lines = nil
  self.bufnr = bufnr

  api.nvim_set_decoration_provider(ns, {
    on_win = function(_, curr_winid, currr_bufnr) return curr_winid == self.winnr and currr_bufnr == self.bufnr end,
    on_line = function(_, _, _, line_number)
      if self.nodes_by_lines == nil then return end

      local node = self.nodes_by_lines[line_number + 1]
      if node == nil then return end

      local render_state = node.render_state
      if render_state == nil then return end

      api.nvim_buf_set_extmark(bufnr, ns, line_number, render_state.icon.idx, {
        virt_text = { { render_state.icon.icon, render_state.icon.hl } },
        virt_text_win_col = render_state.icon.idx,
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
        ephemeral = true,
      })
    end,
  })

  return self
end

function Renderer:render_window(winnr, parent)
  self.winnr = winnr

  api.nvim_set_option_value('modifiable', true, { buf = self.bufnr })

  -- render
  local nodes_by_lines, last_line_number = self:render_node(1, parent, 0)
  self.nodes_by_lines = nodes_by_lines

  -- clear any extra lines from the last render
  api.nvim_buf_set_lines(self.bufnr, last_line_number, api.nvim_buf_line_count(self.bufnr), false, {})

  -- reset modifiable and clear last line
  api.nvim_set_option_value('modifiable', false, { buf = self.bufnr })

  return nodes_by_lines
end

function Renderer:get_icon(node)
  if node.is_dir then
    return node.expanded and '' or '', 'Blue'
  else
    local devicons = require('nvim-web-devicons')
    local icon, color = devicons.get_icon(node.filename, vim.fn.fnamemodify(node.path, ':e'), { default = true })
    return icon, color
  end
end

function Renderer:get_hovered_node()
  if self.nodes_by_lines == nil then return end

  local cursor = api.nvim_win_get_cursor(self.winnr)
  return self.nodes_by_lines[cursor[1]]
end

return Renderer

local api = vim.api
local lib_tree = require('blink.tree.lib.tree')

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
    length = #line,
    indent = indent,
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
  self.once_after_render_callbacks = {}
  self.nodes_by_lines = nil
  self.bufnr = bufnr
  -- hack: the once_after_render callback depends on this for some behavior like reveal
  -- since without a debounce, there would be multiple renders before the node is visible
  self.render_window = require('blink.tree.lib.utils').debounce(self.render_window, 4)

  local modified = {}

  local render_time = 0
  -- Draws the indent and icon
  api.nvim_set_decoration_provider(ns, {
    on_win = function(_, curr_winid, currr_bufnr)
      if render_time > 0 then
        -- vim.print('Last render time ' .. render_time .. 'ms')
        render_time = 0
      end

      local should_render = curr_winid == self.winnr and currr_bufnr == self.bufnr
      if not should_render then return false end

      modified = self.get_modified_buffers()

      return curr_winid == self.winnr and currr_bufnr == self.bufnr
    end,
    on_line = function(_, _, _, line_number)
      if self.nodes_by_lines == nil then return end

      local start = vim.loop.hrtime()

      local node = self.nodes_by_lines[line_number + 1]
      local next_node = self.nodes_by_lines[line_number + 2]
      if node == nil then return end

      local render_state = node.render_state
      if render_state == nil then return end

      -- Indents and Icon
      local indent = render_state.indent
      local indent_str = ''
      while indent > 0 do
        if indent == render_state.indent then
          indent_str = indent_str .. '  '
        elseif (next_node == nil or next_node.render_state.indent < render_state.indent) and indent == 1 then
          indent_str = indent_str .. '└ '
        else
          indent_str = indent_str .. '│ '
        end
        indent = indent - 1
      end

      api.nvim_buf_set_extmark(bufnr, ns, line_number, render_state.icon.idx, {
        virt_text = { { indent_str, 'BlinkTreeIndent' }, { render_state.icon.icon, render_state.icon.hl } },
        virt_text_win_col = 1,
        virt_text_pos = 'overlay',
        hl_mode = 'combine',
        ephemeral = true,
      })

      -- Buffer modified
      if modified[node.path] then
        api.nvim_buf_set_extmark(bufnr, ns, line_number, 2, {
          virt_text = { { ' ● ', 'BlinkTreeModified' } },
          virt_text_pos = 'right_align',
          hl_mode = 'combine',
          priority = 1,
          ephemeral = true,
        })
      end

      -- Git Status
      local repo = lib_tree.get_repo(node)
      if repo ~= nil then
        local status = repo:get_status(node.path)
        if status ~= nil then
          local hl = repo.get_hl_for_status(status)
          if hl ~= nil then
            api.nvim_buf_set_extmark(bufnr, ns, line_number, 0, {
              end_col = render_state.length,
              hl_group = hl,
              hl_eol = true,
              ephemeral = true,
            })
          end
        end
      end

      -- Cut / Copy
      if node.flags.cut then
        api.nvim_buf_set_extmark(bufnr, ns, line_number, 0, {
          virt_text = { { '[cut]', 'BlinkTreeFlagCut' } },
          hl_mode = 'combine',
          priority = 1,
          ephemeral = true,
        })
      elseif node.flags.copy then
        api.nvim_buf_set_extmark(bufnr, ns, line_number, 0, {
          virt_text = { { '[copy]', 'BlinkTreeFlagCopy' } },
          hl_mode = 'combine',
          priority = 1,
          ephemeral = true,
        })
      end
      render_time = render_time + (vim.loop.hrtime() - start) / 1000000
    end,
  })

  return self
end

function Renderer.get_modified_buffers()
  local modified = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_buf_get_option(bufnr, 'modified') then
      local path = vim.api.nvim_buf_get_name(bufnr)
      modified[path] = true
    end
  end
  return modified
end

function Renderer:render_window(winnr, root)
  self.winnr = winnr

  api.nvim_set_option_value('modifiable', true, { buf = self.bufnr })

  -- render
  local nodes_by_lines, last_line_number = self:render_node(1, root, 0)
  self.nodes_by_lines = nodes_by_lines

  -- clear any extra lines from the last render
  api.nvim_buf_set_lines(self.bufnr, last_line_number, api.nvim_buf_line_count(self.bufnr), false, {})

  api.nvim_set_option_value('modifiable', false, { buf = self.bufnr })

  -- run once after render callbacks
  for _, callback in ipairs(self.once_after_render_callbacks) do
    callback()
  end
  self.once_after_render_callbacks = {}

  return nodes_by_lines
end

-- redraw the entire window with the decoration provider
function Renderer:redraw() api.nvim__redraw({ win = self.winnr, valid = false }) end

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

function Renderer:select_node(node)
  if self.nodes_by_lines == nil then return end

  for line_number, n in pairs(self.nodes_by_lines) do
    if n == node then
      api.nvim_win_set_cursor(self.winnr, { line_number, 0 })
      return
    end
  end
end

function Renderer:select_path(path)
  if self.nodes_by_lines == nil then return end

  for line_number, n in pairs(self.nodes_by_lines) do
    if n.path == path then
      api.nvim_win_set_cursor(self.winnr, { line_number, 0 })
      return
    end
  end
end

function Renderer:once_after_render(callback) table.insert(self.once_after_render_callbacks, callback) end

return Renderer

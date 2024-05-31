local api = vim.api

local Renderer = {}

function Renderer.render_node(node, indent)
  local lines = {}
  local prefix = '  '
  local icon = Renderer.get_icon(node)
  local name = node.filename

  table.insert(lines, ' ' .. string.rep(prefix, indent) .. icon .. '  ' .. name)

  if node.expanded then
    for _, child in ipairs(node.children) do
      local child_lines = Renderer.render_node(child, indent + 1)
      for _, line in ipairs(child_lines) do
        table.insert(lines, line)
      end
    end
  end

  return lines
end

function Renderer.render_tree(parent)
  return Renderer.render_node(parent, 0)
  -- api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function Renderer.get_icon(node)
  if node.is_dir then
    return node.expanded and '' or ''
  else
    return ''
  end
end

return Renderer

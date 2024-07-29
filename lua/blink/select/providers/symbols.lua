--- @class SelectProvider
local symbols = {}

local function get_node_text(node, bufnr)
  local start_row, start_col, _, end_col = node:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
  return string.sub(line, start_col + 1, end_col)
end

function symbols.get_items(page_size, bufnr)
  return function()
    local items = {}
    local lang = vim.bo[bufnr].filetype

    if not lang then return {} end

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
    if not ok then return {} end

    local root = parser:parse()[1]:root()

    local query = vim.treesitter.query.get(lang, 'highlights')
    if not query then return {} end

    local function add_item(node, type)
      if #items >= page_size then return end

      local row, col, _ = node:start()
      local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
      local indent = string.match(line, '^%s*')

      local icon, icon_hl
      if type == 'function' then
        icon, icon_hl = '󰊕', 'Function'
      elseif type == 'method' then
        icon, icon_hl = '', 'Method'
      elseif type == 'class' then
        icon, icon_hl = '', 'Type'
      else
        icon, icon_hl = '󰠱', 'Identifier'
      end

      local node_text = vim.split(get_node_text(node, bufnr), '\n')[1]
      table.insert(items, {
        data = { bufnr = bufnr, row = row, col = col },
        fragments = {
          { string.rep(' ', #indent), highlight = 'Comment' },
          { icon .. ' ', highlight = icon_hl },
          { node_text, highlight = 'Normal' },
          { ' :' .. row, highlight = 'LineNr' },
        },
      })
    end

    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
      local name = query.captures[id]
      if name:match('function') or name:match('method') then
        add_item(node:parent(), 'function')
      elseif name:match('class') then
        add_item(node:parent(), 'class')
      end
    end

    return items
  end
end

function symbols.select(item)
  vim.api.nvim_set_current_buf(item.data.bufnr)
  vim.api.nvim_win_set_cursor(0, { item.data.row + 1, item.data.col })
end

return symbols

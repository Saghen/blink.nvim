--- @class SelectProvider
local code_actions = {}

function code_actions.get_items(page_size)
  local idx = 1
  local actions = {}

  -- Get available code actions
  vim.lsp.buf_request_sync(0, 'textDocument/codeAction', vim.lsp.util.make_range_params(), 1000)
  local result =
    vim.lsp.buf_get_clients()[1].request_sync('textDocument/codeAction', vim.lsp.util.make_range_params(), 1000, 0)
  if result and result.result then actions = result.result end

  return function()
    local items = {}
    while idx <= #actions and #items < page_size do
      local action = actions[idx]

      -- Action title
      local title_component = { action.title, highlight = 'Function' }

      -- Action kind (if available)
      local kind_component = ''
      if action.kind then kind_component = { ' [' .. action.kind .. ']', highlight = 'Comment' } end

      -- Action source (if available)
      local source_component = ''
      if action.source then source_component = { ' from ' .. action.source, highlight = 'Comment' } end

      table.insert(items, {
        data = action,
        fragments = {
          '  ',
          title_component,
          kind_component,
          source_component,
        },
      })

      idx = idx + 1
    end

    return items
  end
end

function code_actions.select(item)
  local action = item.data
  if action.edit or type(action.command) == 'table' then
    if action.edit then vim.lsp.util.apply_workspace_edit(action.edit, 'UTF-8') end
    if type(action.command) == 'table' then vim.lsp.buf.execute_command(action.command) end
  else
    vim.lsp.buf.execute_command(action)
  end
end

return code_actions

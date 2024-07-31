--- @class SelectProvider
local code_actions = {
  name = 'Code Actions',
}

function code_actions.get_items(opts, cb)
  local idx = 1
  local actions = {}

  -- Get available code actions
  local results = vim.lsp.buf_request_sync(0, 'textDocument/codeAction', vim.lsp.util.make_range_params(), 1000)
  for _, result in pairs(results or {}) do
    if result and result.result then vim.tbl_extend('force', actions, result.result) end
  end

  cb({
    page_count = math.ceil(#actions / opts.page_size),
    next_page = function(page_cb)
      --- @type RenderFragment[]
      local items = {}
      while idx <= #actions and #items < opts.page_size do
        local action = actions[idx]

        -- Action title
        local title_component = { action.title, highlight = 'Function' }

        -- Action kind (if available)
        --- @type string | RenderFragment
        local kind_component = ''
        if action.kind then kind_component = { ' [' .. action.kind .. ']', highlight = 'Comment' } end

        -- Action source (if available)
        --- @type string | RenderFragment
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

      page_cb(items)
    end,
  })
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

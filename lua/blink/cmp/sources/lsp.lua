--- @class Source
local lsp = {}

---@param capability string|table|nil Server capability (possibly nested
---   supplied via table) to check.
---
---@return boolean Whether at least one LSP client supports `capability`.
---@private
function lsp.has_capability(capability)
  for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
    local has_capability = client.server_capabilities[capability]
    if has_capability then return true end
  end
  return false
end

function lsp.get_trigger_characters()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local trigger_characters = {}

  for _, client in pairs(clients) do
    local completion_provider = client.server_capabilities.completionProvider
    if completion_provider and completion_provider.triggerCharacters then
      for _, trigger_character in pairs(completion_provider.triggerCharacters) do
        table.insert(trigger_characters, trigger_character)
      end
    end
  end

  return trigger_characters
end

function lsp.get_clients_with_capability(capability, filter)
  local clients = {}
  for _, client in pairs(vim.lsp.get_clients(filter)) do
    local capabilities = client.server_capabilities or {}
    if capabilities[capability] then table.insert(clients, client) end
  end
  return clients
end

function lsp.completions(context, callback)
  -- no providers with completion support
  if not lsp.has_capability('completionProvider') then return callback({ isIncomplete = false, items = {} }) end

  -- completion context with additional info about how it was triggered
  local params = vim.lsp.util.make_position_params()
  params.context = {
    triggerKind = context.trigger.kind,
  }
  if context.trigger.kind == vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter then
    params.context.triggerCharacter = context.trigger.character
  end

  -- request from each of the clients
  -- todo: refactor
  lsp.cancel_completions_func = vim.lsp.buf_request_all(0, 'textDocument/completion', params, function(result)
    local responses = {}
    for client_id, response in pairs(result) do
      -- todo: pass error upstream
      if response.error or response.result == nil then
        responses[client_id] = { isIncomplete = false, items = {} }
        -- as per the spec, we assume it's complete if we get CompletionItem[]
      elseif response.result.items == nil then
        responses[client_id] = {
          isIncomplete = false,
          items = response.result,
        }
      else
        responses[client_id] = response.result
      end
    end

    -- add client_id to the items
    for client_id, response in pairs(responses) do
      for _, item in ipairs(response.items) do
        -- todo: terraform lsp doesn't return a .kind in situations like `toset`, is there a default value we need to grab?
        item.kind = item.kind or vim.lsp.protocol.CompletionItemKind.Text
        item.client_id = client_id

        if item.deprecated or (item.tags and vim.tbl_contains(item.tags, 1)) then
          item.score_offset = (item.score_for_deprecated or -2)
        end
      end
    end

    -- combine responses
    -- todo: would be nice to pass multiple responses to the sources
    -- so that we can do fine-grained isIncomplete
    local combined_response = { isIncomplete = false, items = {} }
    for _, response in pairs(responses) do
      combined_response.isIncomplete = response.isIncomplete or response.isIncomplete
      vim.list_extend(combined_response.items, response.items)
    end
    callback(combined_response)
  end)
end

function lsp.cancel_completions()
  if lsp.cancel_completions_func then
    -- fails if the LSP no longer exists so we wrap it
    pcall(lsp.cancel_completions_func)
    lsp.cancel_completions_func = nil
  end
end

function lsp.resolve(item, callback)
  local client = vim.lsp.get_client_by_id(item.client_id)
  if client == nil then
    callback(item)
    return
  end

  local _, request_id = client.request('completionItem/resolve', item, function(error, result)
    if error or result == nil then callback(item) end
    callback(result)
  end)
  if request_id ~= nil then return function() client.cancel_request(request_id) end end
end

return lsp

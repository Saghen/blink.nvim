--- @class SelectProvider
local diagnostics = {
  name = 'Diagnostics',
}

function diagnostics.get_items(opts, cb)
  local idx = 1
  local items = {}
  local all_diagnostics = vim.diagnostic.get(opts.bufnr, { severity = { min = vim.diagnostic.severity.HINT } })
  -- sort by line number
  table.sort(all_diagnostics, function(a, b) return a.lnum < b.lnum end)

  cb({
    page_count = math.ceil(#all_diagnostics / opts.page_size),
    next_page = function(page_cb)
      while idx <= #all_diagnostics and #items < opts.page_size do
        local diag = all_diagnostics[idx]
        local bufnr = diag.bufnr
        if bufnr == nil then break end

        -- Get the diagnostic symbol
        local symbol = '●'
        if diag.severity == vim.diagnostic.severity.ERROR then
          symbol = ' '
        elseif diag.severity == vim.diagnostic.severity.WARN then
          symbol = ' '
        elseif diag.severity == vim.diagnostic.severity.INFO then
          symbol = ' '
        elseif diag.severity == vim.diagnostic.severity.HINT then
          symbol = ' '
        end

        -- Get the diagnostic highlight
        local highlight = 'DiagnosticHint'
        if diag.severity == vim.diagnostic.severity.ERROR then
          highlight = 'DiagnosticError'
        elseif diag.severity == vim.diagnostic.severity.WARN then
          highlight = 'DiagnosticWarn'
        elseif diag.severity == vim.diagnostic.severity.INFO then
          highlight = 'DiagnosticInfo'
        end

        -- Truncate the message if it's too long
        local short_message = vim.split(diag.message, '\n')[1]
        if #short_message > 80 then short_message = short_message:sub(1, 77) .. '...' end

        table.insert(items, {
          data = { bufnr = bufnr, lnum = diag.lnum, col = diag.col },
          fragments = {
            { symbol .. ' ', highlight = highlight },
            { tostring(diag.lnum) .. ':', highlight = 'Comment' },
            { tostring(diag.col) .. ' ', highlight = 'Comment' },
            { short_message, highlight = highlight },
          },
        })

        idx = idx + 1
      end

      page_cb(items)
    end,
  })
end

function diagnostics.select(item)
  vim.api.nvim_set_current_buf(item.data.bufnr)
  vim.api.nvim_win_set_cursor(0, { item.data.lnum + 1, item.data.col })
  vim.diagnostic.open_float()
end

return diagnostics

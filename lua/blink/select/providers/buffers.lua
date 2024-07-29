--- @class SelectProvider
local buffers = {}

function buffers.get_items(page_size)
  local idx = 1
  local bufs = vim.api.nvim_list_bufs()
  local devicons = require('nvim-web-devicons')

  return function()
    local items = {}
    while idx <= #bufs and #items < page_size do
      local bufnr = bufs[idx]
      if vim.api.nvim_get_option_value('buflisted', { buf = bufnr }) then
        local buf_path = vim.api.nvim_buf_get_name(bufnr)
        local dirname = vim.fn.fnamemodify(buf_path, ':~:.:h')
        local dirname_component = { dirname, highlight = 'Comment' }

        local filename = vim.fn.fnamemodify(buf_path, ':t')
        if filename == '' then filename = '[No Name]' end
        local diagnostic_level = nil
        for _, diagnostic in ipairs(vim.diagnostic.get(bufnr)) do
          diagnostic_level = math.min(diagnostic_level or 999, diagnostic.severity)
        end
        local filename_hl = diagnostic_level == vim.diagnostic.severity.HINT and 'DiagnosticHint'
          or diagnostic_level == vim.diagnostic.severity.INFO and 'DiagnosticInfo'
          or diagnostic_level == vim.diagnostic.severity.WARN and 'DiagnosticWarn'
          or diagnostic_level == vim.diagnostic.severity.ERROR and 'DiagnosticError'
          or 'Normal'
        local filename_component = { filename, highlight = filename_hl }

        -- Modified icon
        local modified = vim.bo[bufnr].modified
        local modified_component = modified and { ' ● ', highlight = 'BufferCurrentMod' } or ''

        local icon, icon_hl = devicons.get_icon(filename)
        local icon_component = icon and { ' ' .. icon .. ' ', highlight = icon_hl } or ''

        table.insert(items, {
          data = { bufnr = bufnr },
          fragments = {
            modified_component,
            icon_component,
            ' ',
            filename_component,
            ' ',
            dirname_component,
            ' ',
          },
        })
      end

      idx = idx + 1
    end

    return items
  end
end

function buffers.select(item) vim.api.nvim_set_current_buf(item.data.bufnr) end

return buffers

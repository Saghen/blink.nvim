-- TODO: injected languages for markdown
-- TODO: many many more language definitions

local delimiters = {}

--- @param user_config blink.delimiters.Config
function delimiters.setup(user_config)
  local config = require('blink.delimiters.config')
  config.merge_with(user_config)

  local Parser = require('blink.delimiters.parser')
  local parsers = {}

  vim.api.nvim_set_decoration_provider(config.ns, {
    on_win = function(_, _, bufnr)
      -- only enable for files we support
      local filetype = vim.bo[bufnr].filetype
      local ok, definition = pcall(require, 'blink.delimiters.langs.' .. filetype)
      if not ok then return false end

      if parsers[filetype] == nil then parsers[filetype] = Parser.new(definition) end
      local parser = parsers[filetype]

      parser:attach_to_buffer(bufnr)

      return true
    end,
    on_line = function(_, _, bufnr, line_number)
      local parser = parsers[vim.bo[bufnr].filetype]
      if not parser or not parser.buffer_highlights[bufnr] then return false end

      local matches = parser.buffer_highlights[bufnr][line_number + 1]
      if not matches then return false end

      for _, match in ipairs(matches) do
        vim.api.nvim_buf_set_extmark(bufnr, config.ns, line_number, match.col - 1, {
          end_col = match.col,
          hl_group = match.highlight,
          hl_mode = 'combine',
          priority = config.priority,
          ephemeral = true,
        })
      end
    end,
  })
end

return delimiters

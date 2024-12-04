-- TODO: injected languages for markdown
-- TODO: many many more language definitions

local delimiters = {}

--- @param user_config blink.delimiters.Config
function delimiters.setup(user_config)
  local config = require('blink.delimiters.config')
  config.merge_with(user_config)

  local Parser = require('blink.delimiters.parser')
  local parsers = {}

  -- TODO: clear the matches_per_buffer periodically, probably dont need to do advanced tracking
  -- since the parsing is so fast
  local matches_per_buffer = {}
  local changedtick_per_buffer = {}
  vim.api.nvim_set_decoration_provider(config.ns, {
    on_win = function(_, _, bufnr)
      -- only enable for files we support
      local filetype = vim.bo[bufnr].filetype
      local ok, definition = pcall(require, 'blink.delimiters.langs.' .. filetype)
      if not ok then return false end

      if parsers[filetype] == nil then parsers[filetype] = Parser.new(definition) end
      local parser = parsers[filetype]

      -- parse the whole buffer
      -- TODO: ideally we only re-parse the lines that have changed but this might not be necessary
      -- since it already only takes 0.4ms on a 1MB json file
      local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
      if changedtick_per_buffer[bufnr] ~= changedtick then
        local start_time = vim.loop.hrtime()
        matches_per_buffer[bufnr] = parser:parse_buffer(bufnr)
        matches_per_buffer[bufnr] = parser:asign_highlights(matches_per_buffer[bufnr], config.highlights)
        if config.debug then
          vim.print(matches_per_buffer[bufnr])
          vim.print('parsing time: ' .. (vim.loop.hrtime() - start_time) / 1e9 .. ' ms')
        end
        changedtick_per_buffer[bufnr] = changedtick
      end

      return true
    end,
    on_line = function(_, _, bufnr, line_number)
      if not matches_per_buffer[bufnr] then return false end

      local matches = matches_per_buffer[bufnr][line_number + 1]
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

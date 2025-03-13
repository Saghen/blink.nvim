-- TODO: injected languages for markdown
-- TODO: many many more language definitions

local delimiters = {}

--- @param user_config blink.delimiters.Config
function delimiters.setup(user_config)
  local config = require('blink.delimiters.config')
  config.merge_with(user_config)

  local buffer_changed_ticks = {}

  vim.api.nvim_set_decoration_provider(config.ns, {
    on_win = function(_, _, bufnr)
      if vim.b[bufnr].changedtick == buffer_changed_ticks[bufnr] then return end
      buffer_changed_ticks[bufnr] = vim.b[bufnr].changedtick

      local start_time = vim.loop.hrtime()
      local did_parse = require('blink_delimiters').parse_buffer(bufnr)
      if did_parse and config.debug then
        vim.print('parsing time: ' .. (vim.loop.hrtime() - start_time) / 1e6 .. ' ms')
      end

      return did_parse
    end,
    on_line = function(_, _, bufnr, line_number)
      for _, match in ipairs(require('blink_delimiters').get_parsed_line(bufnr, line_number)) do
        vim.api.nvim_buf_set_extmark(bufnr, config.ns, line_number, match.col, {
          end_col = match.col + 1,
          hl_group = config.highlights[match.stack_height % #config.highlights + 1],
          hl_mode = 'combine',
          priority = config.priority,
          ephemeral = true,
        })
      end
    end,
  })
end

return delimiters

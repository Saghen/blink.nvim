-- TODO: injected languages for markdown
-- TODO: many many more language definitions

local delimiters = {}

--- @param user_config blink.delimiters.Config
function delimiters.setup(user_config)
  local config = require('blink.delimiters.config')
  config.merge_with(user_config)

  -- local Parser = require('blink.delimiters.parser')
  -- local parsers = {}

  local buffer_changed_ticks = {}

  vim.api.nvim_set_decoration_provider(config.ns, {
    on_win = function(_, _, bufnr)
      if vim.b[bufnr].changedtick == buffer_changed_ticks[bufnr] then return end
      buffer_changed_ticks[bufnr] = vim.b[bufnr].changedtick

      local start_time = vim.loop.hrtime()
      local did_parse = require('blink_delimiters').parse_buffer(bufnr)
      if did_parse then vim.print('parsing time: ' .. (vim.loop.hrtime() - start_time) / 1e6 .. ' ms') end
      -- -- only enable for files we support
      -- local filetype = vim.bo[bufnr].filetype
      -- local ok, definition = pcall(require, 'blink.delimiters.langs.' .. filetype)
      -- if not ok then return false end
      --
      -- -- get a parser, or create one if it doesn't exist
      -- if parsers[filetype] == nil then parsers[filetype] = Parser.new(definition) end
      -- local parser = parsers[filetype]
      --
      -- -- attach
      -- parser:attach_to_buffer(bufnr)
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

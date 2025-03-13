local watcher = {
  --- @type table<number, { changedtick: number }>
  watched_bufnrs = {},
}

--- @param bufnr number
--- @param start_line? number
--- @param old_end_line? number
--- @param new_end_line? number
--- @return boolean Whether the buffer is parseable
local function parse_buffer(bufnr, start_line, old_end_line, new_end_line)
  local start_time = vim.uv.hrtime()

  local did_parse = require('blink.delimiters.rust').parse_buffer(bufnr, start_line, old_end_line, new_end_line)

  if did_parse and require('blink.delimiters.config').debug then
    vim.print('parsing time: ' .. (vim.uv.hrtime() - start_time) / 1e6 .. ' ms')
  end

  return did_parse
end

-- nvim_buf_attach doesn't seem to fire if the buffer was updated while it was offscreen
-- so we check the changedtick and update it if it's changed
vim.api.nvim_create_autocmd('BufEnter', {
  callback = function(event)
    local watched_buf = watcher.watched_bufnrs[event.buf]
    if watched_buf == nil then return end
    if watched_buf.changedtick == vim.b[event.buf].changedtick then return end

    watched_buf.changedtick = vim.b[event.buf].changedtick
    require('blink_delimiters').parse_buffer(event.buf)
  end,
})

--- @param bufnr number
--- @return boolean Whether the buffer is parseable and attached
function watcher.attach(bufnr)
  if watcher.watched_bufnrs[bufnr] ~= nil then return true end
  watcher.watched_bufnrs[bufnr] = { changedtick = vim.b[bufnr].changedtick }

  local did_parse = parse_buffer(bufnr)
  if not did_parse then return false end

  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, _, changedtick, start, old_end, new_end)
      local did_incremental_parse = parse_buffer(bufnr, start, old_end, new_end)

      -- no longer parseable, detach
      if not did_incremental_parse then
        watcher.watched_bufnrs[bufnr] = nil
        return true
      end

      watcher.watched_bufnrs[bufnr].changedtick = changedtick
    end,
  })

  return true
end

return watcher

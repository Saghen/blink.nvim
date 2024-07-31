local DbClient = require('telescope._extensions.smart_open.dbclient')
local config = require('smart-open').config
local get_buffer_list = require('telescope._extensions.smart_open.buffers')
local weights = require('telescope._extensions.smart_open.weights')
local get_finder = require('telescope._extensions.smart_open.finder.finder')
local format_filepath = require('telescope._extensions.smart_open.display.format_filepath')

--- @class SelectProvider
local smart_open = {
  name = 'Smart Open',
  db = DbClient:new({ path = config.db_filename }),
  history = require('telescope._extensions.smart_open.history'),
}

function smart_open.get_items(opts, callback)
  local context = {
    cwd = vim.fn.getcwd(),
    current_buffer = vim.api.nvim_buf_get_name(opts.bufnr),
    -- might be wrong if the select buffer is already open
    alternate_buffer = opts.alternate_bufnr > 0 and vim.api.nvim_buf_get_name(opts.alternate_bufnr) or '',
    open_buffers = get_buffer_list(),
    weights = smart_open.db:get_weights(weights.default_weights),
    path_display = true,
  }
  local finder_opts = {
    cwd = context.cwd,
    cwd_only = config.cwd_only,
    ignore_patterns = config.ignore_patterns,
    show_scores = config.show_scores,
    match_algorithm = config.match_algorithm,
    filename_first = true,
  }
  local finder = get_finder(smart_open.history, finder_opts, context)

  local seen_paths = {}
  local items = {}
  finder('', function(entry)
    if seen_paths[entry.path] then return end
    seen_paths[entry.path] = true

    local symbol = entry.scores.alt > 0 and config.open_buffer_indicators.previous
      or entry.buf and config.open_buffer_indicators.others
      or ' '
    local icon, icon_hl = require('nvim-web-devicons').get_icon(entry.path, nil, { default = true })
    local result, hl_group = format_filepath(entry.path, entry.virtual_name, finder_opts, 60)
    local filename = result:sub(1, hl_group[1][1])
    local directory = result:sub(hl_group[1][1] + 1)
    table.insert(items, {
      data = entry,
      fragments = {
        { symbol .. ' ' },
        { icon .. '  ', highlight = icon_hl },
        { filename },
        { directory, highlight = 'Directory' },
      },
    })
  end, function()
    local page_count = math.ceil(#items / opts.page_size)
    local page = 0
    callback({
      next_page = function(cb)
        -- no more pages
        if page >= page_count then return cb({}) end

        local start_idx = (page * opts.page_size + 1)
        local end_idx = (page + 1) * opts.page_size
        local page_items = vim.list_slice(items, start_idx, end_idx)
        page = page + 1
        cb(page_items)
      end,
      page_count = page_count,
    })
  end)
end

function smart_open.select(item)
  if item.data.bufnr ~= nil and vim.api.nvim_buf_is_valid(item.data.bufnr) then
    vim.api.nvim_set_current_buf(item.data.bufnr)
  else
    vim.cmd('edit ' .. item.data.path)
  end
  vim.defer_fn(function() smart_open.history:record_usage(item.data.path, false) end, 10)
end

return smart_open

--- @class SelectProvider
local recent_searches = {
  name = 'Recent Searches',
}

local function reverse(tab)
  for i = 1, math.floor(#tab / 2), 1 do
    tab[i], tab[#tab - i + 1] = tab[#tab - i + 1], tab[i]
  end
  return tab
end

function recent_searches.get_items(opts, cb)
  local idx = 1
  local search_history = vim.fn.searchcount().total > 0 and vim.fn.execute('history search') or ''
  local searches = vim.split(search_history, '\n')

  -- Remove the header line
  table.remove(searches, 1)
  table.remove(searches, 1)
  reverse(searches)

  cb({
    page_count = math.ceil(#searches / opts.page_size),
    next_page = function(page_cb)
      local items = {}
      while idx <= #searches and #items < opts.page_size do
        local search = searches[idx]
        if search ~= '' then
          local search_text = search:match('%s+%d+%s+(.+)$')
          if search_text then
            table.insert(items, {
              data = { search = search_text },
              fragments = {
                { ' ', highlight = 'Normal' },
                { search_text, highlight = 'String' },
              },
            })
          end
        end
        idx = idx + 1
      end
      page_cb(items)
    end,
  })
end

function recent_searches.select(item)
  vim.fn.setreg('/', item.data.search)
  vim.cmd('normal! n')
end

return recent_searches

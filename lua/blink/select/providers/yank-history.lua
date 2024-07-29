--- @class SelectProvider
local yank_history = {}

-- Initialize yank history table
local history = {}
local max_history = 50 -- Maximum number of items to keep in history

-- Function to add item to yank history
local function add_to_history(text)
  -- Remove duplicate if exists
  for i, item in ipairs(history) do
    if item.text == text then
      table.remove(history, i)
      break
    end
  end

  -- Add new item to the beginning
  table.insert(history, 1, { text = text, timestamp = os.time() })

  -- Trim history if it exceeds max_history
  if #history > max_history then table.remove(history) end
end

-- Set up autocmd to track yanks
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    local text = vim.fn.getreg('"')
    add_to_history(text)
  end,
})

function yank_history.get_items(page_size)
  local idx = 1

  return function()
    local items = {}
    while idx <= #history and #items < page_size do
      local item = history[idx]
      local text = item.text:gsub('[\n\r]', ' ') -- Replace newlines with spaces
      local truncated_text = #text > 50 and text:sub(1, 47) .. '...' or text

      local time_diff = os.difftime(os.time(), item.timestamp)
      local time_str = time_diff < 60 and 'just now'
        or time_diff < 3600 and string.format('%d min ago', math.floor(time_diff / 60))
        or time_diff < 86400 and string.format('%d hours ago', math.floor(time_diff / 3600))
        or string.format('%d days ago', math.floor(time_diff / 86400))

      table.insert(items, {
        data = { text = item.text },
        fragments = {
          { truncated_text, highlight = 'Normal' },
          ' ',
          { time_str, highlight = 'Comment' },
        },
      })

      idx = idx + 1
    end

    return items
  end
end

function yank_history.select(item)
  vim.fn.setreg('"', item.data.text)
  vim.api.nvim_put({ item.data.text }, '', false, true)
end

function yank_history.alt_select(item) vim.fn.setreg('"', item.data.text) end

return yank_history

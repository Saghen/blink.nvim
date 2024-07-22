local api = vim.api
local Dashboard = {}

local function create_buf()
  local bufnr = api.nvim_create_buf(false, true)

  local opts = {
    ['bufhidden'] = 'wipe',
    ['colorcolumn'] = '',
    ['foldcolumn'] = '0',
    ['matchpairs'] = '',
    ['buflisted'] = false,
    ['cursorcolumn'] = false,
    ['cursorline'] = false,
    ['list'] = false,
    ['number'] = false,
    ['relativenumber'] = false,
    ['spell'] = false,
    ['swapfile'] = false,
    ['readonly'] = false,
    ['filetype'] = 'dashboard',
    ['wrap'] = false,
    ['signcolumn'] = 'no',
    ['winbar'] = '',
    ['stc'] = '',
  }
  for opt, val in pairs(opts) do
    api.nvim_set_option_value(opt, val, { buf = bufnr })
  end

  return bufnr
end

function Dashboard.setup()
  -- should we show the dashboard?
  if vim.fn.argc() == 0 and api.nvim_buf_get_name(0) == '' and vim.g.read_from_stdin == nil then return end

  local bufnr = create_buf()
  local winid = api.nvim_get_current_win()
  api.nvim_win_set_buf(winid, bufnr)

  local center_line = function(line)
    local width = api.nvim_win_get_width(0)
    local line_width = string.len(line)
    local padding = math.floor((width - line_width) / 2)
    return string.rep(' ', padding) .. line
  end

  local lines = {
    '',
    center_line('Welcome to Tuque'),
  }

  local centered_lines = {}
  for _, line in ipairs(lines) do
    table.insert(centered_lines, center_line(line))
  end

  api.nvim_buf_set_lines(bufnr, 0, -1, false, centered_lines)
end

return Dashboard

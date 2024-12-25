local symbols = {}

local function symbols.get_items(opts)
  local symbols = {}
  local params = vim.lsp.util.make_position_params(opts.winnr)

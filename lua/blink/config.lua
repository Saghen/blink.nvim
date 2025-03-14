local M = {}

M.default = {
  chartoggle = {
    enabled = false,
    delimiters = { ',', ';' },
  },
  clue = {
    enabled = false,
  },
  indent = {
    enabled = false,
  },
  select = {
    enabled = false,
  },
  tree = {
    enabled = false,
  },
}

function M.setup(opts) M.config = vim.tbl_deep_extend('force', M.default, opts or {}) end

return setmetatable(M, { __index = function(_, k) return M.config[k] end })

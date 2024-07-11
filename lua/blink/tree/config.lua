local M = {}

M.default = {}

function M.setup(opts)
  opts = vim.tbl_deep_extend('force', M.default, opts or {})
  M.config = opts
end

return setmetatable(M, { __index = function(_, k) return M.config[k] end })

local M = {}

M.default = {
	hidden_by_default = true,
	hide_dotfiles = false,
	hide = {
		'.github',
		'.direnv',
		'.devenv'
	},
	never_show = {
		'.git',
		'.cache',
		'node_modules'
	},
}

function M.setup(opts)
  opts = vim.tbl_deep_extend('force', M.default, opts or {})
  M.config = opts
end

return setmetatable(M, { __index = function(_, k) return M.config[k] end })

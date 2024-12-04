--- @class blink.delimiters.Config
--- @field highlights string[]
--- @field priority number
--- @field ns integer
--- @field debug boolean

--- @type blink.delimiters.Config
local config = {
  highlights = {
    'RainbowOrange',
    'RainbowPurple',
    'RainbowBlue',
  },
  priority = 200,
  ns = vim.api.nvim_create_namespace('blink.delimiters'),
  debug = false,
}

--- @type blink.delimiters.Config
local M = {}

--- @param user_config blink.delimiters.Config
function M.merge_with(user_config) config = vim.tbl_deep_extend('force', config, user_config) end

return setmetatable(M, { __index = function(_, k) return config[k] end })

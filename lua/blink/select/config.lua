--- @class SelectMapping
--- @field selection string[]
--- @field quit string[]
--- @field next_page string[]
--- @field prev_page string[]
---
--- @class SelectWindowConfig
--- @field min_width number[]
--- @field max_width number[]
--- @field border 'single' | 'double' | 'rounded' | string[]
--- @field wrap boolean

--- @class SelectConfig
--- @field mapping SelectMapping
--- @field window SelectWindowConfig
local config = {
  mapping = {
    selection = { 'h', 'j', 'k', 'l', 'a', 's', 'd', 'f' },
    -- remember selection also uses the capital variants so dont interfere
    prev_page = { '<C-h>' },
    next_page = { '<C-l>' },
    quit = { 'q', '<Esc>' },
  },
  window = {
    min_width = { 20, 0.2 }, -- greater of 20 columns and 20% of current window width
    max_width = { 120, 0.8 }, -- lesser of 120 columns and 80% of current window width
    border = 'rounded',
    wrap = false,
    group_size = 4,
  },
}

function config.setup(opts) config = vim.tbl_deep_extend('force', config, opts or {}) end

return setmetatable({}, { __index = function(_, k) return config[k] end })

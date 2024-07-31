--- @class BlockedConfig
--- @field buftypes string[]
--- @field filetypes string[]
---
--- @class StaticConfig
--- @field char string
--- @field priority number
--- @field highlights string[]
---
--- @class ScopeConfig
--- @field char string
--- @field priority number
--- @field highlights string[]
--- @field underline ScopeUnderlineConfig
---
--- @class ScopeUnderlineConfig
--- @field enabled boolean
--- @field highlights string[]
---
--- @class IndentConfig
--- @field blocked BlockedConfig
--- @field static StaticConfig
--- @field scope ScopeConfig
--- @field default IndentConfig
local config = {
  default = {
    blocked = {
      buftypes = { 'terminal', 'quickfix', 'nofile', 'prompt' },
      filetypes = {
        'lspinfo',
        'packer',
        'checkhealth',
        'help',
        'man',
        'gitcommit',
        'TelescopePrompt',
        'TelescopeResults',
        'dashboard',
        '',
      },
    },
    static = {
      char = '▎',
      priority = 1,
      highlights = { 'BlinkIndent' },
    },
    scope = {
      char = '▎',
      priority = 1024,
      highlights = {
        'BlinkIndentRed',
        'BlinkIndentYellow',
        'BlinkIndentBlue',
        'BlinkIndentOrange',
        'BlinkIndentGreen',
        'BlinkIndentViolet',
        'BlinkIndentCyan',
      },
      underline = {
        enabled = false,
        highlights = {
          'BlinkIndentRedUnderline',
          'BlinkIndentYellowUnderline',
          'BlinkIndentBlueUnderline',
          'BlinkIndentOrangeUnderline',
          'BlinkIndentGreenUnderline',
          'BlinkIndentVioletUnderline',
          'BlinkIndentCyanUnderline',
        },
      },
    },
  },
}

function config.setup(opts) config = vim.tbl_deep_extend('force', config.default, opts or {}) end

return setmetatable(config, { __index = function(_, k) return config[k] end })

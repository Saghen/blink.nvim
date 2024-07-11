local M = {}

function M.setup(opts)
  local config = require('blink.config')
  config.setup(opts)

  if config.chartoggle.enabled then require('blink.chartoggle').setup(config.chartoggle) end
  if config.clue.enabled then require('blink.clue').setup(config.clue) end
  if config.cmp.enabled then require('blink.cmp').setup(config.cmp) end
  if config.indent.enabled then require('blink.indent').setup(config.indent) end
  if config.tree.enabled then require('blink.tree').setup(config.tree) end

  -- todo: tepmorary
  local clue = require('blink.clue')
  clue.setup({
    triggers = {
      -- Leader triggers
      { mode = 'n', keys = '<Leader>' },
      { mode = 'x', keys = '<Leader>' },

      -- Built-in completion
      { mode = 'i', keys = '<C-x>' },

      -- `g` key
      { mode = 'n', keys = 'g' },
      { mode = 'x', keys = 'g' },

      -- Marks
      { mode = 'n', keys = "'" },
      { mode = 'n', keys = '`' },
      { mode = 'x', keys = "'" },
      { mode = 'x', keys = '`' },

      -- Registers
      { mode = 'n', keys = '"' },
      { mode = 'x', keys = '"' },
      { mode = 'i', keys = '<C-r>' },
      { mode = 'c', keys = '<C-r>' },

      -- Window commands
      { mode = 'n', keys = '<C-w>' },

      -- `z` key
      { mode = 'n', keys = 'z' },
      { mode = 'x', keys = 'z' },
    },

    clues = {
      -- Enhance this by adding descriptions for <Leader> mapping groups
      clue.gen_clues.builtin_completion(),
      clue.gen_clues.g(),
      clue.gen_clues.marks(),
      clue.gen_clues.registers(),
      clue.gen_clues.windows(),
      clue.gen_clues.z(),
    },

    window = {
      delay = 200,
      config = { border = 'single', width = 40 },
    },
  })
end

return M

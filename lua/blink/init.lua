local M = {}

function M.setup()
  require('blink.cmp').setup()
  require('blink.indent').setup()
  require('blink.tree').setup()

  -- todo: tepmorary
  -- local clue = require('blink.clue')
  -- clue.setup({
  --   triggers = {
  --     -- Leader triggers
  --     { mode = 'n', keys = '<Leader>' },
  --     { mode = 'x', keys = '<Leader>' },
  --
  --     -- Built-in completion
  --     { mode = 'i', keys = '<C-x>' },
  --
  --     -- `g` key
  --     { mode = 'n', keys = 'g' },
  --     { mode = 'x', keys = 'g' },
  --
  --     -- Marks
  --     { mode = 'n', keys = "'" },
  --     { mode = 'n', keys = '`' },
  --     { mode = 'x', keys = "'" },
  --     { mode = 'x', keys = '`' },
  --
  --     -- Registers
  --     { mode = 'n', keys = '"' },
  --     { mode = 'x', keys = '"' },
  --     { mode = 'i', keys = '<C-r>' },
  --     { mode = 'c', keys = '<C-r>' },
  --
  --     -- Window commands
  --     { mode = 'n', keys = '<C-w>' },
  --
  --     -- `z` key
  --     { mode = 'n', keys = 'z' },
  --     { mode = 'x', keys = 'z' },
  --   },
  --
  --   clues = {
  --     -- Enhance this by adding descriptions for <Leader> mapping groups
  --     clue.gen_clues.builtin_completion(),
  --     clue.gen_clues.g(),
  --     clue.gen_clues.marks(),
  --     clue.gen_clues.registers(),
  --     clue.gen_clues.windows(),
  --     clue.gen_clues.z(),
  --   },
  --
  --   window = {
  --     delay = 200,
  --     config = { border = 'single', width = 40 },
  --   },
  -- })
end

return M

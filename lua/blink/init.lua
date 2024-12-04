local M = {}

function M.setup(opts)
  local config = require('blink.config')
  config.setup(opts)

  if config.chartoggle.enabled then require('blink.chartoggle').setup(config.chartoggle) end
  if config.clue.enabled then require('blink.clue').setup(config.clue) end
  if config.delimiters.enabled then require('blink.delimiters').setup(config.delimiters) end
  if config.indent.enabled then require('blink.indent').setup(config.indent) end
  if config.select.enabled then require('blink.select').setup(config.select) end
  if config.tree.enabled then require('blink.tree').setup(config.tree) end
end

return M

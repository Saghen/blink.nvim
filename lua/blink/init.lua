local M = {}

function M.setup(opts)
  local config = require('blink.config')
  config.setup(opts)

  if config.chartoggle.enabled then require('blink.chartoggle').setup(config.chartoggle) end
  if config.clue.enabled then require('blink.clue').setup(config.clue) end
  if config.indent and config.indent.enabled then
    vim.notify(
      'blink.nvim: indent.enabled has been replaced by a separate blink.indent repo. See https://github.com/saghen/blink.indent',
      vim.log.levels.WARN
    )
  end
  if config.select.enabled then require('blink.select').setup(config.select) end
  if config.tree.enabled then require('blink.tree').setup(config.tree) end
end

return M

local select = {}

--- @param opts SelectConfig
function select.setup(opts)
  require('blink.select.config').setup(opts)
  require('blink.select.providers.yank-history') -- requires autocmds setup early
end

function select.show(provider) require('blink.select.window').show(require('blink.select.providers.' .. provider)) end

return select

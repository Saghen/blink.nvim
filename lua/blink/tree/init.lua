-- todo: symlinks
local api = vim.api

local M = {}

function M.show()
  local filesystem = require('blink.tree.filesystem')
  local renderer = require('blink.tree.renderer')
  local tree = require('blink.tree.tree')

  local buf = vim.api.nvim_create_buf(false, true)
  api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  api.nvim_set_option_value('filetype', 'neo-tree', { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    win = -1,
    vertical = true,
    split = 'left',
    width = 40,
  })

  local start_time = vim.loop.hrtime()

  local root = filesystem.build_tree(tree.make_root())
  local lines = renderer.render_tree(root)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local total_time = vim.loop.hrtime() - start_time
  print('Time taken: ' .. total_time / 1e6 .. 'ms')

  local total_node_count = 0
  local function count_nodes(node)
    total_node_count = total_node_count + 1
    for _, child in ipairs(node.children) do
      count_nodes(child)
    end
  end
  count_nodes(root)
  -- print('Total nodes: ' .. total_node_count)
end

function M.setup()
  api.nvim_create_user_command('BlinkTree', 'lua require("blink.tree").show()', {
    nargs = 0,
  })
end

return M

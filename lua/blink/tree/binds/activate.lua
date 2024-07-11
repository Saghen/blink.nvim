local api = vim.api

local function activate(hovered_node, inst)
  if hovered_node == nil then return end

  -- todo: use existing buffer if available

  -- dir: toggled expanded
  if hovered_node.is_dir then
    if hovered_node.expanded then
      inst.tree:collapse(hovered_node)
    else
      inst.tree:expand(hovered_node)
    end
  -- file: open
  else
    local winnr = require('blink.tree.lib.utils').pick_or_create_non_special_window()
    api.nvim_set_current_win(winnr)
    local bufnr = vim.fn.bufnr(hovered_node.path)
    if bufnr ~= -1 then
      api.nvim_set_current_buf(bufnr)
    else
      vim.cmd('edit ' .. hovered_node.path)
    end
  end
end

return activate

local function expand(hovered_node, inst)
  if hovered_node == nil then return end

  if hovered_node.is_dir then
    if hovered_node.expanded then
      inst.tree:collapse(hovered_node)
    else
      inst.tree:expand(hovered_node)
    end
  else
    return
  end
end

return expand

local utils = {}

--- Maps a list and accumulates the result
--- @generic T
--- @generic State
--- @generic V
--- @param list T[]
--- @param initial_state State
--- @param fn fun(state: State, value: T, idx: number): V, State?
--- @return V[], State[]
function utils.map_accum(list, initial_state, fn)
  local all_states = {}
  local state = initial_state
  local mapped = {}
  local value
  for i, v in ipairs(list) do
    value, state = fn(state, v, i)
    if state == nil then state = value end
    table.insert(mapped, value)
    table.insert(all_states, state)
  end
  return mapped, all_states
end

--- Splices elements in a list between two indices and optionally replaces them
--- @param list table The list to splice
--- @param start_index integer Starting index to begin splicing
--- @param end_index integer Ending index to stop splicing
--- @param replacement? table|any Optional replacement value or table of values
--- @return table list The modified list
function utils.splice(list, start_index, end_index, replacement)
  -- Ensure indices are within bounds
  start_index = math.max(1, math.min(start_index, #list + 1))
  end_index = math.max(1, math.min(end_index, #list))

  -- Remove elements in range
  for _ = start_index, end_index do
    table.remove(list, start_index)
  end

  -- Insert replacement
  if replacement then
    if type(replacement) == 'table' then
      for i = #replacement, 1, -1 do
        table.insert(list, start_index, replacement[i])
      end
    else
      table.insert(list, start_index, replacement)
    end
  end

  return list
end

--- Slices a list between two indices
--- @param list table The list to slice
--- @param start_index integer Starting index to begin slicing
--- @param end_index integer Ending index to stop slicing
--- @return table list The sliced list
function utils.slice(list, start_index, end_index)
  -- Fast path for slicing the entire list
  if start_index == 1 and end_index == #list then return list end

  -- Ensure indices are within bounds
  start_index = math.max(1, math.min(start_index, #list + 1))
  end_index = math.max(1, math.min(end_index, #list))

  -- Slice the list
  local sliced = {}
  for i = start_index, end_index do
    table.insert(sliced, list[i])
  end
  return sliced
end

--- Shallow copies a table
--- @generic T
--- @param t T
--- @return T
function utils.shallow_copy(t)
  local t2 = {}
  for k, v in pairs(t) do
    t2[k] = v
  end
  return t2
end

--- Shallowly compares two arrays
--- @generic T
--- @param a T[]
--- @param b T[]
--- @return boolean
function utils.shallow_array_equal(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

return utils

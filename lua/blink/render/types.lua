--- 0-1 is interpretted as percentage of parent and whole numbers are the number of columns.
--- When an array, the minimum will be taken in all cases except max_width and max_height.
--- @alias Length number | number[]
---
--- @class Component
--- @field align? 'left' | 'center' | 'right'
--- Number of spaces or string of characters to pad between components
--- @field gap? number | string
--- @field space? 'between' | 'around' | 'evenly'
--- @field direction? 'horizontal' | 'vertical'
--- @field size? 'expand' | 'shrink'
--- @field overflow? 'ellipsis'
--- @field max_width? Length
--- @field min_width? Length
--- @field max_height? Length
--- @field min_height? Length
--- @field width? Length
--- @field height? Length
--- @field padding? Length
--- @field margin? Length
--- @field children Component[]

--- @param comp Component
function get(comp) local yo = comp.width end

return Component

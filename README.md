<div align="center">

# blink.nvim

Experimental library of neovim plugins inspired by [mini.nvim](https://github.com/echasnovski/mini.nvim) with a focus on performance and simplicity, targeting neovim 0.10.

</div>

## Modules

| status | module                                                  | description                                                                                                   |
|--------|---------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| stable | [blink.chartoggle](/readmes/blink.chartoggle/README.md) | Toggles a character at the end of the current line                                                                       |
| beta   | [blink.cmp](/readmes/blink.cmp/README.md)               | Performant autocompletion plugin, inspired by [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)                 |
| stable | [blink.indent](/readmes/blink.indent/README.md)         | Indent guides with scope on every keystroke                                                                   |
| alpha  | [blink.select](/readmes/blink.select/README.md)         | Generic Harpoon-like selection UI with built-in providers                                                     |
| alpha  | [blink.tree](/readmes/blink.tree/README.md)             | Tree plugin with async io and FFI git, inspired by [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) |

## Installation

`lazy.nvim`

```lua
{
  'saghen/blink.nvim',
  -- all modules handle lazy loading internally
  lazy = false,
  opts = {
    chartoggle = { enabled = true },
    cmp = { enabled = true },
    indent = { enabled = true },
    select = { enabled = true },
    tree = { enabled = true },
  }
}

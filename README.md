<div align="center">

# blink.nvim

Experimental library of neovim plugins with a focus on performance and simplicity

</div>

## Modules

| status | module                                                  | description                                                                                                   |
|--------|---------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| stable | [blink.chartoggle](/readmes/chartoggle/README.md) | Toggles a character at the end of the current line                                                                       |
| beta   | [blink.cmp](/readmes/cmp/README.md)               | Performant autocompletion plugin, inspired by [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)                 |
| stable | [blink.indent](/readmes/indent/README.md)         | Indent guides with scope on every keystroke                                                                   |
| WIP    | [blink.select](/readmes/select/README.md)         | Generic selection UI with built-in providers                                                     |
| WIP    | [blink.tree](/readmes/tree/README.md)             | Tree plugin with async io and FFI git, inspired by [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) |

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
  }
}

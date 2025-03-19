<div align="center">

# blink.nvim

Experimental library of neovim plugins with a focus on performance and simplicity

</div>

## Modules

| status | module                                                  | description                                                                                                                                                     |
|--------|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| stable | [blink.chartoggle](/readmes/chartoggle/README.md)       | Toggles a character at the end of the current line                                                                                                              |
| beta   | [blink.cmp](https://github.com/saghen/blink.cmp)        | Performant autocompletion plugin, inspired by [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)                                                                   |
| alpha  | [blink.pairs](https://github.com/saghen/blink.pairs)       | Rainbow highlighting and intelligent auto-pairs                                                                                         |
| stable | [blink.indent](/readmes/indent/README.md)               | Indent guides with scope on every keystroke                                                                                                                     |
| WIP    | [blink.select](/readmes/select/README.md)               | Generic selection UI with built-in providers                                                                                                                    |
| alpha  | [blink.tree](/readmes/tree/README.md)                   | Tree plugin with async io and FFI git, similar to [neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) but eventually to be rewritten to be like oil.nvim |

## Installation

`lazy.nvim`

```lua
{
  'saghen/blink.nvim',
  build = 'cargo build --release', -- for delimiters
  keys = {
	-- chartoggle
	{
	  ';',
	  function()
	  	require('blink.chartoggle').toggle_char_eol(';')
	  end,
	  mode = { 'n', 'v' },
	  desc = 'Toggle ; at eol',
	},
	{
	  ',',
	  function()
	  	require('blink.chartoggle').toggle_char_eol(',')
	  end,
	  mode = { 'n', 'v' },
	  desc = 'Toggle , at eol',
	},

	-- tree
	{ '<C-e>', '<cmd>BlinkTree reveal<cr>', desc = 'Reveal current file in tree' },
	{ '<leader>E', '<cmd>BlinkTree toggle<cr>', desc = 'Reveal current file in tree' },
	{ '<leader>e', '<cmd>BlinkTree toggle-focus<cr>', desc = 'Toggle file tree focus' },
  }
  -- all modules handle lazy loading internally
  lazy = false,
  opts = {
    chartoggle = { enabled = true },
    indent = { enabled = true },
    tree = { enabled = true }
  }
}

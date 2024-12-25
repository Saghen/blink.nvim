# Blink Delimiters (blink.delimiters)

**blink.delimiters** uses a line-wise state machine parser to draw rainbow delimiters in 0.1-0.5ms (1-10ms on initial load) per render, including on massive files, without Treesitter. The parser should work in all valid code and compute quicker than via Treesitter. If you want something more accurate, consider using [rainbow-delimiters.nvim](https://github.com/hiphish/rainbow-delimiters.nvim) instead.

## Install

`lazy.nvim`

```lua
{
  'saghen/blink.nvim',
  -- all modules handle lazy loading internally
  lazy = false,
  opts = {
    delimiters = {
      enabled = true,
      highlights = {
        'RainbowOrange',
        'RainbowPurple',
        'RainbowBlue',
      },
      priority = 200,
      ns = vim.api.nvim_create_namespace('blink.delimiters'),
      debug = false,
    }
  },
}
```

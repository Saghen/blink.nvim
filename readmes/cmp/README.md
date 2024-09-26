# Blink Completion (blink.cmp)

**blink.cmp** provides a completion plugin with support for LSPs and external sources while updating on every keystroke with minimal overhead (0.5-4ms async). It achieves this by writing the fuzzy searching in SIMD to easily handle >20k items. It provides extensibility via hooks into the trigger, sources and rendering pipeline. Plenty of work has been put into making each stage of the pipeline as intelligent as possible, such as frecency and proximity bonus on fuzzy matching, and this work is on-going. 

TODO: `nvim-cmp` sources are supported out of the box but migration to the `blink.cmp` style source is highly encouraged.

## Features

- Works out of the box with no additional configuration
- Simple hackable codebase
- Updates on every keystroke (0.5-4ms non-blocking, single core)
- Typo resistant fuzzy with frecency and proximity bonus
- Extensive LSP support ([tracker](./LSP_TRACKER.md))
- Snippet support (including `friendly-snippets`)
- TODO: Cmdline support
- External sources support (TODO: including `nvim-cmp` compatibility layer)
- [Comparison with nvim-cmp](#compared-to-nvim-cmp)

## Installation

`lazy.nvim`

```lua
{
  'saghen/blink.nvim',
  -- note: requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  build = 'cargo build --release',
  event = 'InsertEnter',
  dependencies = {
    {
      'garymjr/nvim-snippets',
      dependencies = { 'rafamadriz/friendly-snippets' },
      opts = { create_cmp_source = false, friendly_snippets = true },
    },
  },
  opts = {
    cmp = {
      enabled = true,
      highlight = {
        -- defaults to nvim-cmp's highlight groups for now
        -- will be removed in a future release, assuming themes add support
        use_nvim_cmp_as_default = true,
      }
  }
}
```

<details>
<summary>Default configuration</summary>

<!-- config:start -->

```lua
{
  -- for keymap, all values may be string | string[]
  -- use an empty table to disable a keymap
  keymap = {
    show = '<C-space>',
    hide = '<C-e>',
    accept = '<Tab>',
    select_prev = { '<Up>', '<C-j>' },
    select_next = { '<Down>', '<C-k>' },

    show_documentation = {},
    hide_documentation = {},
    scroll_documentation_up = '<C-b>',
    scroll_documentation_down = '<C-f>',

    snippet_forward = '<Tab>',
    snippet_backward = '<S-Tab>',
  },
  trigger = {
    -- regex used to get the text when fuzzy matching
    context_regex = '[%w_\\-]',
    -- LSPs can indicate when to show the completion window via trigger characters
    -- however, some LSPs (*cough* tsserver *cough*) return characters that would essentially
    -- always show the window. We block these by default
    blocked_trigger_characters = { ' ', '\n', '\t' },
  },
  fuzzy = {
    -- frencency tracks the most recently/frequently used items and boosts the score of the item
    use_frecency = true,
    -- proximity bonus boosts the score of items with a value in the buffer
    use_proximity = true,
    max_items = 200,
    -- controls which sorts to use and in which order, these three are currently the only allowed options
    sorts = { 'label', 'kind', 'score' },
  },
  sources = {
    providers = {
      { module = 'blink.cmp.sources.lsp' },
      { module = 'blink.cmp.sources.buffer' },
      { module = 'blink.cmp.sources.snippets', fallback_for = { 'blink.cmp.sources.lsp' } },
    },
  },
  windows = {
    autocomplete = {
      min_width = 30,
      max_width = 60,
      max_height = 10,
      order = 'top_down',
      -- which directions to show the window,
      -- falling back to the next direction when there's not enough space
      direction_priority = { 'n', 's' },
      -- whether to preselect the first item in the window
      preselect = true,
    },
    documentation = {
      min_width = 10,
      max_width = 60,
      max_height = 20,
      -- which directions to show the documentation window,
      -- for each of the possible autocomplete window directions,
      -- falling back to the next direction when there's not enough space
      direction_priority = {
        autocomplete_north = { 'e', 'w', 'n', 's' },
        autocomplete_south = { 'e', 'w', 's', 'n' },
      },
      auto_show = true,
      delay_ms = 0,
      debounce_ms = 100,
    },
  },

  highlight = {
    ns = vim.api.nvim_create_namespace('blink_cmp'),
    use_nvim_cmp_as_default = false,
  },
  kind_icons = {
    Text = '󰉿',
    Method = '󰊕',
    Function = '󰊕',
    Constructor = '󰒓',

    Field = '󰜢',
    Variable = '󰆦',
    Property = '󰖷',

    Class = '󱡠',
    Interface = '󱡠',
    Struct = '󱡠',
    Module = '󰅩',

    Unit = '󰪚',
    Value = '󰦨',
    Enum = '󰦨',
    EnumMember = '󰦨',

    Keyword = '󰻾',
    Constant = '󰏿',

    Snippet = '󱄽',
    Color = '󰏘',
    File = '󰈔',
    Reference = '󰬲',
    Folder = '󰉋',
    Event = '󱐋',
    Operator = '󰪚',
    TypeParameter = '󰬛',
  },
}
```

<!-- config:end -->

</details>

## How it works

The plugin use a 4 stage pipeline: trigger -> sources -> fuzzy -> render

**Trigger:** Controls when to request completion items from the sources and provides a context downstream with the current query (i.e. `hello.wo|`, the query would be `wo`) and the treesitter object under the cursor (i.e. for intelligently enabling/disabling sources). It respects trigger characters passed by the LSP (or any other source) and includes it in the context for sending to the LSP.

**Sources:** Provides a common interface for and merges the results of completion, trigger character, resolution of additional information and cancellation. It also provides a compatibility layer to `nvim-cmp`'s sources. Many sources are builtin: `LSP`, `buffer`, `treesitter`, `path`, `snippets`

**Fuzzy:** Rust <-> Lua FFI which performs both filtering and sorting of the items

&nbsp;&nbsp;&nbsp;&nbsp;**Filtering:** The fuzzy matching uses smith-waterman, same as FZF, but implemented in SIMD for ~6x the performance of FZF (todo: add benchmarks). Due to the SIMD's performance, the prefiltering phase on FZF was dropped to allow for typos. Similar to fzy/fzf, additional points are given to prefix matches, characters with capitals (to promote camelCase/PascalCase first char matching) and matches after delimiters (to promote snake_case first char matching)

&nbsp;&nbsp;&nbsp;&nbsp;**Sorting:** Combines fuzzy matching score with frecency and proximity bonus. Each completion item may also include a `score_offset` which will be added to this score to demote certain sources. The `buffer` and `snippets` sources take advantage of this to avoid taking presedence over the LSP source. The paramaters here still need to be tuned and have been exposed, so please let me know if you find some magical parameters!

**Render:** Responsible for placing the autocomplete, documentation and function parameters windows. All of the rendering can be overriden following a syntax similar to incline.nvim. It uses the neovim window decoration provider to provide next to no overhead from highlighting. 

## Compared to nvim-cmp

### Advantages

- Avoids the complexity of nvim-cmp's configuration by providing sensible defaults
- Updates on every keystroke, versus nvim-cmp's default debounce of 60ms
    - Setting nvim-cmp's debounce to 0ms leads to visible stuttering. If you'd like to stick with nvim-cmp, try [yioneko's fork](https://github.com/yioneko/nvim-cmp)
- Boosts completion item score via frecency *and* proximity bonus. nvim-cmp only boosts score via proximity bonus
- Typo-resistant fuzzy matching unlike nvim-cmp's fzf-style fuzzy matching
- Core sources (buffer, snippets, lsp) are built-in versus nvim-cmp's exclusively external sources
- Uses native snippets versus nvim-cmp's required snippet engine

### Disadvantages

All of the following are planned, but not yet implemented.

- Less customizable across the board wrt trigger, sources, sorting, filtering, and rendering
- Significantly less testing and documentation
- No support for cmdline completions
- No support for dynamic sources (i.e. per-filetype)

## Special Thanks

@garymjr nvim-snippets implementation used for snippets source

@redxtech Help with design and testing

@aadityasahay Help with rust, testing and design

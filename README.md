# tuck.nvim

Automatically fold function bodies so you can actually see your code structure.

## Requirements

- Neovim 0.10+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) with parsers installed for your languages:

```vim
:TSInstall ruby python lua javascript rust
```

Inspired by [this article](https://matklad.github.io/2024/10/14/missing-ide-feature.html) from matklad - the idea is simple: function signatures are way more useful than function bodies when you're reading code. So let's fold the bodies by default.

## What it does

- Folds top-level function/method bodies on file open
- Unfolds at cursor when you move your cursor to a fold or use LSP navigation (go to definition, references, etc.)
- Uses Tree-sitter, so it actually understands your code

## Supported languages

- Lua
- Ruby  
- Python
- JavaScript
- Rust
- PHP

PRs welcome for more languages - the queries are pretty simple.

## Installation

lazy.nvim:
```lua
{
  'nuvic/tuck.nvim',
  config = function()
    require('tuck').setup()
  end,
}
```

packer:
```lua
use {
  'nuvic/tuck.nvim',
  config = function()
    require('tuck').setup()
  end,
}
```

## Configuration

```lua
require('tuck').setup({
  enabled = true,
  manage_folds = true, -- set to false when another plugin, such as nvim-ufo, owns fold state
  auto_unfold = true, -- set to false if you want to disable auto unfold on cursor movement
  navigation_unfold = true, -- unfold after LSP/fzf navigation lands on a folded body
  unfold_delay = 50,
  exclude_filetypes = { 'markdown', 'text' },
  exclude_paths = { 'vendor/*', 'node_modules/*' },
  integrations = {
    fzf_lua = false,
  },
})
```

## Commands

| Command | What it does |
|---------|--------------|
| `:Tuck enable` | Turn it on |
| `:Tuck disable` | Turn it off |
| `:Tuck toggle` | Toggle |
| `:Tuck fold` | Re-fold everything in current buffer |

## How it works

tuck uses Tree-sitter queries to find function bodies, then sets up `foldexpr` to fold them. The queries live in `queries/tuck/` if you want to poke around or add new languages.

When you navigate via LSP (go to definition, references, etc.), tuck automatically unfolds the function body at the cursor position. This works with:

- Native LSP navigation (`vim.lsp.buf.definition()`, etc.)
- fzf-lua LSP pickers (with the integration enabled)

Set `manage_folds = false` when you want tuck to find body fold ranges and handle unfold behavior, but you do not want it to set `foldmethod`, `foldexpr`, `foldlevel`, or close folds itself.

## Integrations

### nvim-ufo

To use tuck as a body-fold provider for [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo), disable tuck's fold management and wire its provider into ufo:

```lua
require('tuck').setup({
  manage_folds = false,
})

require('ufo').setup({
  provider_selector = function()
    return require('tuck').ufo_provider
  end,
  close_fold_kinds_for_ft = {
    default = { 'body' },
  },
})
```

In this setup, ufo creates and renders folds. tuck only decides which ranges are body folds and keeps the navigation-aware unfolding behavior.

### fzf-lua

If you use [fzf-lua](https://github.com/ibhagwan/fzf-lua), enable the integration to automatically unfold when jumping via fzf-lua pickers:

```lua
require('tuck').setup({
  integrations = {
    fzf_lua = true,
  },
})
```

This patches fzf-lua's file actions (`file_edit`, `file_split`, `file_vsplit`, etc.) and LSP jump functions to unfold at cursor after jumping. Works with all fzf-lua pickers - `files`, `grep`, `lsp_definitions`, you name it.

Your existing fzf-lua keybinds and config are preserved.

## Troubleshooting

If it doesn't seem to work, run `:Tuck debug` to see what's happening.

## License

MIT

<!-- insert
---
title: "minimal-format.nvim"
date: 2023-09-13T10:02:37
description: "Smart formatting for neovim"
repo_url: "https://github.com/cljoly/minimal-format.nvim"
tags:
- NeoVim
- Lua
- Plugin
---
{{< github_badge >}}

{{< rawhtml >}}
<div class="badges">
{{< /rawhtml >}}
end_insert -->
<!-- remove -->
# Minimal Formatting for neovim
<!-- end_remove -->

![Neovim version](https://img.shields.io/badge/Neovim-0.9-57A143?style=flat&logo=neovim) [![](https://img.shields.io/badge/powered%20by-riss-lightgrey)](https://cj.rs/riss) ![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/cljoly/minimal-format.nvim?color=darkgreen&sort=semver)

<!-- insert
{{< rawhtml >}}
</div>
{{< /rawhtml >}}
end_insert -->

A simple powerful that extends neovim just a little bit to automatically format your code.

* Integrates with neovim constructs: use `formatprg`, the setting used by the `gq` mapping in default vim.
* Asynchronous: neovim won’t hang while the formatting command is running
* Applies the minimum difference required to the buffer. This means that the whole buffer won’t be changed and marks and external marks (used e.g. for diagnostics) will be preserved. This makes formatting less disruptive to your workflow
* Can be configured to trigger automatically on write, per buffer
* No startup cost: call the functions you need when you need them, no need to set up anything at startup.

## Getting started

Install this package with your favorite package manager.

Then, you can configure some mappings or user commands to the following functions:
* `require("minimal-format").format_with_formatprg(bufnr)`: format the buffer number `bufnr`
* `require("minimal-format").toggle_autocmd`: toggle automatic formatting on write

### Setting a Formatter per Language

Just configure `formatprg` like you normally would to use `gq`. For instance, it might look like this for C:
```vim
if executable('clang-format')
  setlocal formatprg=clang-format\ --assume-filename=a.c
  let b:undo_ftplugin .= ' fp<'
endif
```
Paste the above snippet in `.config/nvim/ftplugin/c.vim`.
Then when you call `require("minimal-format").format_with_formatprg(0)`, the current buffer will be asynchronously formatted with this command.

Example for Rust, in `.config/nvim/ftplugin/rust.lua`:
```lua
if vim.fn.executable "rustfmt" then
  vim.opt_local.formatprg = "rustfmt -q --emit=stdout"
  local edition = require("cj.rust").find_rust_edition()
  if edition then
    vim.opt_local.formatprg:append(" --edition " .. edition)
  end
  vim.b.undo_ftplugin = vim.b.undo_ftplugin .. "|setl fp<"

  require("minimal-format").enable_autocmd(0)
end
```
This sets the `formatprg` setting and enable automatic formatting before writing. Also, dynamically detects the current rust edition and adds `formatprg` to `undo_ftplugin`.

## Formatters per Language

| Language | `formatprg`                        |
|----------|------------------------------------|
| C        | clang-format --assume-filename=a.c |
| Lua      | stylua -                           |
| Rust     | rustfmt --quiet --emit=stdout      |

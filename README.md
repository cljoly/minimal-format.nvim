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

A simple & powerful formatting plugin that extends neovim just a little bit to automatically format your code.

* Native: uses the `formatprg` setting, the setting used by the `gq` mapping in default vim.
* Safe:
    * Doesn’t replace your code with garbage if the formatting command fails (unlike `gq`)
    * Applies the minimum difference required to the buffer. This means that the whole buffer won’t be changed and marks and external marks (used e.g. for diagnostics) will be preserved. This makes formatting less disruptive to your workflow
* Asynchronous: neovim won’t hang while the formatting command is running
* Can be configured to trigger automatically on write, per buffer
* No startup cost: call the functions you need when you need them, no need to load anything during startup.

## Getting started

Install this package with your favorite package manager.

Then, you can configure some mappings or user commands to the following functions:
* `require("minimal-format").format_with_formatprg(bufnr)`: format the buffer number `bufnr`
* `require("minimal-format").toggle_autocmd`: toggle automatic formatting on write

### Setting Up a Mapping to Format the Current File

Add the following to your `init.lua`:
```lua
vim.keymap.set("n", "<space>f", function()
  require("minimal-format").format_with_formatprg(0, false)
end, { desc = "Format current buffer, using formatprg when possible" })

```

### Setting a Formatter per File Type

Configure `formatprg` like you normally would to use `gq`. For instance, it might look like this for C:
```vim
if executable('clang-format')
  setlocal formatprg=clang-format\ --assume-filename=a.c
  let b:undo_ftplugin .= ' fp<'
endif
```
Paste the above snippet in `.config/nvim/ftplugin/c.vim`.
Then when you call `require("minimal-format").format_with_formatprg(0)`, the current buffer will be asynchronously formatted with this command.

### Per Buffer Settings

Example for Rust, in `.config/nvim/ftplugin/rust.lua`, where we automatically detect the rust edition:
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
where `find_rust_edition` is defined like this:
```lua
function M.find_rust_edition()
  local manifests = find_cargotoml()
  for _, manifest in ipairs(manifests) do
    local grep_output =
      vim.fn.system { "grep", "-E", "--only-matching", [[edition *= *"(\d+)"]], manifest }
    local year = vim.fn.substitute(grep_output or "", [[^.*"\(\d\+\)".*$]], [[\1]], "")
    if year ~= "" then
      return tonumber(year)
    end
  end
  return nil
end
```

### Automatic formatting on save

The last option is to enable automatic formatting before writing a buffer.

#### Lua

```lua
if vim.fn.executable "stylua" then
  vim.opt_local.formatprg = "stylua -"
  vim.b.undo_ftplugin = vim.b.undo_ftplugin .. " fp<"

  require("minimal-format").enable_autocmd(0)
end
```

#### Vimscript

```vim
if executable('stylua')
  setlocal formatprg=stylua\ -
  let b:undo_ftplugin .= ' fp<'

  call v:lua.require'minimal-format'.enable_autocmd(0)
endif
```

## Example Formatters per Language

| Language | `formatprg`                        |
|----------|------------------------------------|
| C        | clang-format --assume-filename=a.c |
| Gawk     | gawk --pretty-print=- -f -         |
| Go       | goimports                          |
| Lua      | stylua -                           |
| Python   | black -t py36 -q -                 |
| Rust     | rustfmt --quiet --emit=stdout      |
| Toml     | taplo fmt -                        |

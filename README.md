# nvim-lite

A small, self-contained Neovim profile managed by Neovim's built-in package
manager.

## Requirements

- Neovim 0.12 or newer
- `rg` and `fd` for repository search
- `lazygit` for the Git UI
- `codex` for the config-scoped Codex terminal

Language servers are optional and enabled when their executables are present.

## Install

```sh
git clone git@github.com:moukayz/nvim-lite.git ~/.config/nvim-lite
NVIM_APPNAME=nvim-lite nvim
```

Plugins are installed from `init.lua`; `nvim-pack-lock.json` pins their
resolved revisions.

## Maintenance

- Reload the configuration with `:source $MYVIMRC`.
- Review and update plugins with `:PackUpdate`.
- Restart Neovim with `Space r r`.

The leader key is `Space`. Use which-key inside Neovim to discover the other
mappings.

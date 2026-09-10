# workspace.nvim

A bundled, local Neovim plugin for an explicit global set of directory roots.
No installation framework, cwd changes, persistence, or default keymaps.

Add this directory to `runtimepath`, then configure the core:

```lua
require("workspace").setup({
  blocked = function() return false end, -- disable activation in a context
  excluded = function(tab) return false end, -- retain ordinary browsing in a tab
})
```

`:WorkspaceAdd ~/A ~/B`, `:WorkspaceRemove`, `:WorkspaceInfo`, and
`:WorkspaceClear` manage roots globally, including from excluded tabs.
Directories are canonicalized; duplicate roots are ignored and nested roots
rejected. Roots survive module reload, but not Neovim restart.

## Optional adapters

- `workspace.fzf`: `find_files()` streams fd results into fzf-lua immediately;
  `live_grep()` searches the explicit roots with fzf-lua/rg.
- `workspace.neotree`: add this module name to Neo-tree's `sources`, then call
  `toggle_tree()`. Expansions scan immediate children only and cache them until
  `R` or root changes. Browse/open only. An open tree follows normal file buffers
  in the current tab, expanding only their ancestor directories without moving
  focus. Opening the tree reveals the current file too. Files outside the roots
  and entries excluded by fd ignore rules are not revealed. Existing expanded
  branches are left open; closed trees stay closed.

Each action returns false when inactive, allowing the caller's normal fallback.
The core loads without either UI plugin. Adapters need their respective plugin;
file scanning needs fd (or fdfind), and grep needs rg.

## Structure and reload

`init.lua` owns roots, commands, context policy callbacks, snapshots and the
`User WorkspaceChanged` event. `scan.lua` owns buffered asynchronous directory
listings; `fzf.lua` owns streaming picker lifecycle; `neotree.lua` owns tree state.

The host config clears `workspace` and `workspace.*` from `package.loaded` on
reload, calls core setup again, and reconfigures Neo-tree. Global roots and their
revision survive; the generation check invalidates old async results. Context
policy and keymaps belong to the host, not this plugin.

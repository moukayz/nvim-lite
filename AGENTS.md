# nvim-lite contributor guide

## Purpose

This repository is a small, native-first Neovim 0.12 profile. Keep startup
predictable, configuration reloadable, and tool integrations lightweight.
Do not turn it into a general-purpose distribution or introduce a plugin
framework without an explicit request.

## Configuration architecture

`init.lua` is only the entrypoint. It clears cached `config.*` modules so
`<Space>rs` performs a real reload, then loads modules in dependency order:

```text
init.lua
├── options       global defaults and terminal-local UI defaults
├── keymaps       general editing, tabs, reload, terminal, and tmux navigation
├── diagnostics   diagnostic presentation and navigation
├── codex        Codex config-workspace layout and terminal lifecycle
├── lazygit      Lazygit singleton floating-terminal lifecycle
├── plugins       vim.pack declarations and shared plugin configuration
├── treesitter    parsers, highlighting, and structural text objects
├── ui            colorscheme, Diffview visuals, statusline, and tabline
├── explorer      Neo-tree configuration and Git-root resolution
├── picker        fzf-lua pickers; consumes explorer.git_root_at_cursor()
├── lsp           native Neovim LSP configuration and LspAttach mappings
└── startup       directory bootstrap page with project-local recent files
```

Dependency direction must stay one-way. A later module may consume a public
function from an earlier module, as `picker.lua` consumes `explorer.lua`, but
earlier modules must not require later modules.

The `config` namespace is intentionally profile-local. `NVIM_APPNAME=nvim-lite`
gives this checkout its own runtime path, so a separate main Neovim profile may
also use `lua/config/` without sharing or colliding with these modules.

## File organization

- `init.lua`: module-cache reset and ordered `require()` calls only.
- `lua/config/options.lua`: global/window options and option-related
  autocmds.
- `lua/config/keymaps.lua`: mappings that do not belong to a plugin or
  singleton tool.
- `lua/config/diagnostics.lua`: `vim.diagnostic` configuration and maps.
- `lua/config/codex.lua`: Codex config-workspace layout, singleton launch,
  resume, and exit behavior.
- `lua/config/lazygit.lua`: Lazygit singleton floating-terminal launch, hide,
  restore, and exit behavior.
- `lua/config/plugins.lua`: the complete `vim.pack` source list, built-in
  optional packages, Gitsigns, Diffview commands, and which-key.
- `lua/config/treesitter.lua`: parser installation, highlighting, and text
  objects.
- `lua/config/ui.lua`: theme, separators, Diffview rendering, lualine, and
  tab labels.
- `lua/config/explorer.lua`: Neo-tree and reusable repository-root logic.
- `lua/config/picker.lua`: fzf-lua configuration and picker actions.
- `lua/config/lsp.lua`: language-server discovery, configuration, and
  buffer-local LSP mappings.
- `lua/config/startup.lua`: native directory-startup page and project-local
  recent-file navigation.
- `tests/smoke.lua`: reload and invariant checks for core options, mappings,
  commands, and autocmd cardinality.
- `tests/codex_workspace.lua`: Codex workspace layout, reload, singleton,
  process-exit cleanup, and reopen checks with a stubbed terminal job.
- `tests/lazygit.lua`: Lazygit singleton float hide, reload, restore, and
  process-exit cleanup checks with a stubbed terminal job.
- `tests/startup.lua`: directory bootstrap rendering, MRU filtering, and
  recent-file opening checks.
- `tests/window_zoom.lua`: tab-local window zoom, reload, and exact size
  restoration checks.
- `nvim-pack-lock.json`: revisions managed by `vim.pack`; do not edit by hand.

Create a new module only when behavior has a distinct responsibility that does
not fit an existing file. Keep module names under the profile-local `config`
namespace.

## Modification rules

1. Preserve established behavior unless the request explicitly changes it.
   Do not disable existing plugins or mappings as a side effect.
2. Prefer Neovim 0.12 APIs and bundled packages over new dependencies. Add all
   external plugins only in `plugins.lua` and let `:PackUpdate` update the lock.
3. Keep `<Space>rs` safe. Named augroups must use `{ clear = true }`; avoid
   accumulating autocmds, commands, or state on repeated module execution.
4. Put plugin-specific and tool-specific mappings with their owner. Mappings
   that should override a global terminal mapping must be buffer-local.
5. Terminal tools must clean up both their window/tab and buffer on process
   exit. Use buffer/tab variables as identity markers. Do not assign a fixed
   terminal buffer name: hidden named buffers can cause `E95` on reopen.
6. Preserve singleton semantics:
   - Lazygit uses one terminal buffer in a centered float. Buffer-local
     `<C-g>` hides it; `<Space>gg` restores the same process; `q` exits it.
   - Codex uses one dedicated `nvim-lite` tab with a tab-local config working
     directory, a left terminal, and `init.lua` on the right. It starts with
     `codex resume --last`; when the process exits, remove only its terminal
     window and buffer so the editable config workspace remains open.
7. Preserve the tmux navigation fast path. Use `vim.system()` to call tmux
   directly; do not start a shell for every pane movement.
8. Keep repository-aware behavior explicit. General fzf searches use Neovim's
   current working directory; Neo-tree and worktree review use
   `explorer.git_root_at_cursor()`.
9. Keep edits scoped and preserve unrelated working-tree changes. Review
   `git status --short` and `git diff` before committing.
10. Make focused commits. Do not combine plugin installation, behavioral
    changes, and broad refactoring unless the user requests that grouping.

## Validation

After every configuration change, run:

```sh
git diff --check
NVIM_APPNAME=nvim-lite nvim --headless -i NONE -u init.lua -l tests/smoke.lua
```

In a restricted sandbox that blocks fzf-lua's local RPC socket, run the smoke
test with `serverstart()` stubbed while loading the same profile:

```sh
env NVIM_APPNAME=nvim-lite nvim --headless -i NONE -u NONE \
  +'lua vim.fn.serverstart = function() return "test-server" end; vim.env.MYVIMRC = vim.fn.getcwd() .. "/init.lua"; dofile("init.lua"); dofile("tests/smoke.lua")'
```

Add targeted checks for changed behavior. In particular, terminal-tool changes
must exercise hide/reopen and process-exit cleanup, and reload-related changes
must source the config more than once. Treat sandbox-only log-file warnings as
environmental only when the command exits successfully and all assertions pass.

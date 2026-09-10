# nvim-lite contributor guide

## Purpose

This repository is a small, native-first Neovim 0.12 profile. Keep startup
predictable, configuration reloadable, and tool integrations lightweight.
Do not turn it into a general-purpose distribution or introduce a plugin
framework without an explicit request.

## Configuration architecture

`init.lua` is only the entrypoint. It clears cached `config.*` and `workspace*` modules so
`<Space>rs` performs a real reload, then loads modules in dependency order:

```text
init.lua
├── options       global defaults and terminal-local UI defaults
├── config_update config repository update command and shared reload helper
├── keymaps       general editing, tabs, reload, terminal, and tmux navigation
├── diagnostics   diagnostic presentation and navigation
├── codex        Codex config-workspace layout and terminal lifecycle
├── plugins       vim.pack declarations and shared plugin configuration
├── treesitter    parsers, highlighting, and structural text objects
├── ui            colorscheme, Diffview visuals, statusline, and tabline
├── yadm          context-specific handlers injected by init.lua
├── workspace     bundled local plugin; global multi-root commands and adapters
├── explorer      Neo-tree configuration and Git-root resolution
├── lazygit       per-repository floating-terminal lifecycle
├── picker        fzf-lua pickers; consumes explorer.git_root_at_cursor()
├── lsp           native Neovim LSP configuration and LspAttach mappings
└── startup       directory bootstrap page with project-local recent files
```

Dependency direction must stay one-way. A later module may consume a public
function from an earlier module, as `picker.lua` consumes `explorer.lua`, but
earlier modules must not require later modules.
The entrypoint loads yadm first, then sets up the three tools in the
order above. Tools never import the integration. Each keymap has one owner in
its tool module; integrations contain no keymap definitions.

The `config` namespace is intentionally profile-local. `NVIM_APPNAME=nvim-lite`
gives this checkout its own runtime path, so a separate main Neovim profile may
also use `lua/config/` without sharing or colliding with these modules.

## File organization

- `init.lua`: module-cache reset, ordered module loading, and explicit `setup()`
  wiring. Keep feature logic and keymap definitions in their owning modules.
- `lua/config/options.lua`: global/window options and option-related
  autocmds.
- `lua/config/keymaps.lua`: mappings that do not belong to a plugin or
  singleton tool.
- `lua/config/config_update.lua`: asynchronous config pull command and reload helper;
  loaded before keymaps, which owns the reload shortcut.
- `lua/config/diagnostics.lua`: `vim.diagnostic` configuration and maps.
- `lua/config/codex.lua`: Codex config-workspace layout, singleton launch,
  resume, and exit behavior.
- `lua/config/lazygit.lua`: Lazygit per-repository floating-terminal launch, hide,
     restore, and exit behavior.
- `lua/config/plugins.lua`: the complete `vim.pack` source list, built-in
  optional packages, Gitsigns, Diffview commands, and which-key.
- `lua/config/treesitter.lua`: parser installation, highlighting, and text
  objects.
- `lua/config/ui.lua`: theme, separators, Diffview rendering, lualine, and
  tab labels.
- `lua/config/worktree_status.lua`: ui.lua helper for asynchronous, cached
  buffer-directory worktree labels; never run Git during statusline rendering.
- `lua/config/explorer.lua`: Neo-tree and reusable repository-root logic.
- `lua/config/picker.lua`: fzf-lua configuration and picker actions.
- `lua/config/yadm.lua`: yadm context, async dotfiles picker, tree selection and
  Lazygit argument policy. The source adapter below consumes its context API.
- `lua/config/yadm_tree.lua`: Neo-tree tracked-dotfiles source; builds parent
  directories from `yadm ls-files` without scanning home. Browse/open/refresh only.
- `plugins/workspace.nvim/lua/workspace/init.lua`: UI-independent global roots,
  commands, context callbacks, and change events. No cwd changes.
- `plugins/workspace.nvim/lua/workspace/scan.lua`: asynchronous fd directory listings.
- `plugins/workspace.nvim/lua/workspace/fzf.lua`: streaming files and combined grep adapter.
- `plugins/workspace.nvim/lua/workspace/neotree.lua`: browse-only Neo-tree source,
  lazy expansion and cached nodes. Never scans the roots' common parent.
  The plugin never imports `config.*`; init.lua injects Codex/yadm policy and
  tool modules retain keymap ownership. plugins.lua adds its runtime path once.
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
- `tests/lazygit_repos.lua`: real Git identity and tab-local cwd resolution,
  cross-tab reuse, per-repository isolation, reload, and exit/reopen checks.
- `tests/startup.lua`: directory bootstrap rendering, MRU filtering, and
  recent-file opening checks.
- `tests/window_zoom.lua`: tab-local window zoom, reload, and exact size
  restoration checks.
- `tests/picker.lua`: yadm-context file picker and ordinary-project fallback.
- `tests/yadm_tree.lua`: real Neo-tree rendering, opening, toggle and reload checks.
- `tests/integrations.lua`: generic setup defaults, injection, and single mapping ownership.
- `tests/treesitter.lua`: CLI bootstrap success/failure, installer selection and reload guards.
- `tests/workspace.lua`: real fd/rg and Neo-tree checks for multi-root scope,
  commands, shared roots, config-tab exclusion, reload persistence, and stale-result rejection.
- `tests/workspace_tree_lazy.lua`: shallow scan boundaries, cached expansions,
  refresh, cancellation, and a large hidden-descendant fixture.
- `tests/workspace_stream.lua`: immediate picker opening, incremental file results,
  NUL chunk boundaries, literal filenames, and scan cancellation.
- `tests/workspace_plugin.lua`: standalone core loading and adapter dependency boundaries.
- `tests/workspace_follow.lua`: current-file reveal, ancestor-only scans, focus,
  closed-tree behavior, reload, and stale-follow rejection.
- `nvim-pack-lock.json`: revisions managed by `vim.pack`; do not edit by hand.

Create a new module only when behavior has a distinct responsibility that does
not fit an existing file. Keep configuration under `config`; the bundled local
workspace plugin owns the independent `workspace` namespace. Keep its core free
of fzf-lua/Neo-tree dependencies; adapters may depend on the core, not vice versa.

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
   - Lazygit uses one terminal buffer per Git directory in a centered float. Buffer-local
     `<C-g>` hides it; `<Space>gg` restores the same process; `q` exits it.
     In inherited yadm context, explicitly pass the user Lazygit config from
     `$XDG_CONFIG_HOME/lazygit/config.yml` (default `~/.config/lazygit/config.yml`).
     Ordinary projects retain automatic config discovery.
     Reuse is keyed by canonical Git directory, not a global singleton or cwd
     string. Worktrees and submodules have distinct instances. Launch in the
     selected file's repo, falling back to effective tab/window cwd for terminals.
     Restore floats in the invoking tab without restarting their processes.
   - Codex uses one dedicated `nvim-lite` tab with a tab-local config working
     directory, a left terminal, and `init.lua` on the right. It starts with
     `codex resume --last`; when the process exits, remove only its terminal
     window and buffer so the editable config workspace remains open.
7. Preserve the tmux navigation fast path. Use `vim.system()` to call tmux
   directly; do not start a shell for every pane movement.
8. Keep repository-aware behavior explicit. General fzf searches use Neovim's
   current working directory; Neo-tree and worktree review use
   `explorer.git_root_at_cursor()`.
   Exception: `<Space>f` in an inherited yadm Git context lists only yadm-tracked
   files, rooted at `GIT_WORK_TREE`. Detect it by canonical `GIT_DIR` matching
   `yadm introspect repo`; browsing home alone must not activate this behavior.
   `<Space>ee` uses the same detection to toggle the yadm source; normal sessions
   retain the filesystem source. `R` refreshes tracked entries after yadm add/remove.
   Cache successful yadm context checks until cwd/environment changes or config
   reload. Tree listings use asynchronous Git with explicit repository/worktree;
   late results must not reopen closed windows or overwrite newer refreshes.
   The yadm file picker also lists via asynchronous Git, preserving exact NUL-
   delimited paths; ignore stale results after reload, repeat invocation or a
   window/buffer/context change.
9. Keep edits scoped and preserve unrelated working-tree changes. Review
   `git status --short` and `git diff` before committing.
10. Make focused commits. Do not combine plugin installation, behavioral
    changes, and broad refactoring unless the user requests that grouping.
11. Missing Tree-sitter CLI is installed asynchronously before missing parsers:
    Homebrew, otherwise profile-local npm/Cargo. Never sudo from Neovim; attempt
    once per process, preserve the guard across reloads, and report failures.
12. Tool setup APIs are explicit, not a registry: `picker.setup({find_files, live_grep})`
    and `explorer.setup({sources, toggle_tree, focus_tree})` accept handlers returning true
    when handled and false/nil for normal fallback. Lazygit accepts
    `setup({launch_args, cwd})`: launch_args returning nil uses defaults, an argv
    list appends arguments, false cancels a new launch. Resolve launch_args only
    for new jobs. The cwd resolver runs on invocation before repository lookup;
    init.lua injects yadm/root policy after explorer has loaded.
    Repeated setup replaces handlers; Neo-tree is configured once per reload.
    Explorer owns `<Space>ef` in normal/terminal mode: exit terminal input and
    focus/open the context-appropriate tree, without toggling it closed.
13. The multi-root workspace is opt-in and global across ordinary tabs. `:WorkspaceAdd ~/A ~/B`
    adds canonical directories (duplicates ignored, nested roots rejected).
    `:WorkspaceAdd` prompts; `:WorkspaceRemove` selects a root to remove;
    `:WorkspaceInfo` lists roots; `:WorkspaceClear` restores ordinary browsing.
    Roots survive config reload but are not persisted across Neovim restarts.
    The Codex config tab (codex_config_tab marker) is excluded and keeps its
    normal config-directory browsing. Inject that exclusion from init.lua;
    workspace commands manage the global list even from an excluded tab.
    Root changes refresh or close workspace trees in all tabs without stealing focus.
    The workspace file picker opens immediately and streams fd results; never
    wait for a complete recursive listing or sort it before opening fzf.
    Space f and Space / combine only those roots; Space ee uses a browse-only
    tree. Ignore files still apply, .git is excluded, and directory symlinks
    are not traversed. Git actions still resolve the selected file's repository.
    No file mutation commands in the workspace tree. Explicit workspaces are
    disabled in yadm sessions; inject that policy from init.lua.
    Tree expansion must scan only immediate children (fd --max-depth 1), not
    recursively reuse the file picker's listing. Cache loaded nodes across
    close/reopen; only R or workspace-root changes invalidate listings. Refresh
    only expanded branches and discard cancelled or stale directory results.
    Open workspace trees follow normal file buffers in the current tab without
    stealing focus; reveal loads only the target's ancestors. Never reopen a
    closed tree on buffer changes. Ignore outside-root files and special buffers;
    retain manually expanded branches and cancel superseded follow targets.

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

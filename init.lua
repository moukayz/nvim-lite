vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Small, practical defaults.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.undofile = true
vim.opt.termguicolors = true
vim.opt.fillchars:append({
  horiz = "━",
  horizdown = "┳",
  horizup = "┻",
  vert = "┃",
  verthoriz = "╋",
  vertleft = "┫",
  vertright = "┣",
})
vim.opt.autocomplete = true
vim.opt.autocompletedelay = 120
vim.opt.complete = { "o^20", ".^10", "w^5", "b^5", "u^5" }
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy", "nearest" }

vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true, silent = true, desc = "Next completion item or tab" })

vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true, silent = true, desc = "Previous completion item or shift-tab" })

-- Built-in repository search remains available even without fzf-lua.
vim.opt.grepprg = "rg --vimgrep --smart-case --hidden --glob=!.git"
vim.opt.grepformat = "%f:%l:%c:%m"

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
vim.keymap.set("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
vim.keymap.set("n", "[q", "<cmd>cprevious<cr>", { desc = "Previous quickfix item" })
vim.keymap.set("n", "<leader>q", "<cmd>copen<cr>", { desc = "Open quickfix list" })
vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<cr>", { desc = "Close other tabs" })
vim.keymap.set("n", "<A-h>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<A-l>", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("t", "<A-h>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set("t", "<A-l>", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>rr", "<cmd>restart<cr>", { desc = "Restart Neovim" })
vim.keymap.set("n", "<leader>rs", "<cmd>source $MYVIMRC<cr>", { desc = "Source Neovim config" })
vim.keymap.set("n", "<A-t>", function()
  vim.cmd("belowright split")
  vim.cmd("terminal")
  vim.cmd("startinsert")
end, { desc = "Open terminal below" })
vim.keymap.set("t", "<C-g>", [[<C-\><C-n>]], { desc = "Leave terminal mode" })

-- Navigate Neovim windows first, then cross a Neovim edge into tmux without
-- starting 'shell'. This keeps pane switches fast even when the user's shell
-- has expensive startup configuration.
local tmux_socket = vim.env.TMUX and vim.env.TMUX:match("^([^,]+)")
local tmux_pane = vim.env.TMUX_PANE
local last_navigation_used_tmux = false

local function select_tmux_pane(direction)
  if not tmux_socket or not tmux_pane then
    return false
  end

  vim.system({
    "tmux",
    "-S",
    tmux_socket,
    "select-pane",
    "-t",
    tmux_pane,
    "-" .. direction,
  }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        local message = vim.trim(result.stderr or "")
        vim.notify(message ~= "" and message or "tmux pane navigation failed", vim.log.levels.ERROR)
      end)
    end
  end)
  return true
end

local pane_directions = {
  ["<C-h>"] = { window = "h", tmux = "L", name = "left", byte = 8 },
  ["<C-j>"] = { window = "j", tmux = "D", name = "down", byte = 10 },
  ["<C-k>"] = { window = "k", tmux = "U", name = "up", byte = 11 },
  ["<C-l>"] = { window = "l", tmux = "R", name = "right", byte = 12 },
}

local function navigate_pane(direction)
  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. direction.window)
  if vim.api.nvim_get_current_win() ~= previous_window then
    last_navigation_used_tmux = false
    return
  end

  last_navigation_used_tmux = select_tmux_pane(direction.tmux)
end

for lhs, direction in pairs(pane_directions) do
  vim.keymap.set("n", lhs, function()
    navigate_pane(direction)
  end, { silent = true, desc = "Navigate " .. direction.name .. " across panes" })

  vim.keymap.set("t", lhs, function()
    if vim.bo.filetype == "fzf" then
      vim.api.nvim_chan_send(vim.b.terminal_job_id, string.char(direction.byte))
      return
    end
    vim.cmd.stopinsert()
    navigate_pane(direction)
  end, { silent = true, desc = "Navigate " .. direction.name .. " across panes" })
end

vim.keymap.set("n", "<C-\\>", function()
  if last_navigation_used_tmux then
    select_tmux_pane("l")
    return
  end

  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p")
  if vim.api.nvim_get_current_win() == previous_window then
    last_navigation_used_tmux = select_tmux_pane("l")
  end
end, { silent = true, desc = "Navigate to previous pane" })

local tmux_navigation_group = vim.api.nvim_create_augroup("tmux_navigation", { clear = true })
vim.api.nvim_create_autocmd("WinEnter", {
  group = tmux_navigation_group,
  callback = function()
    last_navigation_used_tmux = false
  end,
  desc = "Reset previous tmux pane navigation",
})

-- Make diagnostics recognizable at a glance and easy to inspect.
vim.diagnostic.config({
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "󰌵",
    },
  },
  virtual_text = {
    current_line = true,
    source = "if_many",
    spacing = 2,
    prefix = "●",
  },
  float = {
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
  },
})

vim.keymap.set("n", "gl", function()
  vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Show line diagnostics" })

local function map_diagnostic_navigation(lhs, count, severity, description)
  vim.keymap.set("n", lhs, function()
    vim.diagnostic.jump({ count = count, severity = severity })
  end, { desc = description })
end

map_diagnostic_navigation("]w", 1, vim.diagnostic.severity.WARN, "Next warning")
map_diagnostic_navigation("[w", -1, vim.diagnostic.severity.WARN, "Previous warning")
map_diagnostic_navigation("]e", 1, vim.diagnostic.severity.ERROR, "Next error")
map_diagnostic_navigation("[e", -1, vim.diagnostic.severity.ERROR, "Previous error")
map_diagnostic_navigation("]i", 1, vim.diagnostic.severity.INFO, "Next info diagnostic")
map_diagnostic_navigation("[i", -1, vim.diagnostic.severity.INFO, "Previous info diagnostic")

-- Locate a singleton tool tab and its terminal window.
local function find_exclusive_tab(tab_marker, buffer_marker)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_ok, is_tool_tab = pcall(vim.api.nvim_tabpage_get_var, tab, tab_marker)
    if tab_ok and is_tool_tab then
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buf_ok, is_tool_buffer = pcall(vim.api.nvim_buf_get_var, buf, buffer_marker)
        if buf_ok and is_tool_buffer then
          return tab, win
        end
      end
    end
  end
end

-- Full Git UI, using one dedicated tab and one lazygit process.
vim.keymap.set("n", "<leader>gg", function()
  local tab, win = find_exclusive_tab("lazygit_tab", "lazygit_buffer")
  if tab then
    vim.api.nvim_set_current_tabpage(tab)
    vim.api.nvim_set_current_win(win)
    vim.cmd("startinsert")
    return
  end

  vim.cmd("tabnew")
  vim.cmd("terminal lazygit")
  vim.api.nvim_tabpage_set_var(0, "lazygit_tab", true)
  vim.api.nvim_buf_set_var(0, "lazygit_buffer", true)
  vim.cmd("startinsert")
end, { desc = "Lazygit" })

-- Open Codex against this Neovim profile (for example ~/.config/nvim-lite).
vim.keymap.set("n", "<leader>cc", function()
  local tab, win = find_exclusive_tab("codex_config_tab", "codex_config_buffer")
  if tab then
    vim.api.nvim_set_current_tabpage(tab)
    vim.api.nvim_set_current_win(win)
    vim.cmd("startinsert")
    return
  end

  vim.cmd("tabnew")
  local job = vim.fn.jobstart({ "codex" }, {
    term = true,
    cwd = vim.fn.stdpath("config"),
  })
  if job <= 0 then
    vim.notify("Could not start Codex CLI", vim.log.levels.ERROR)
    return
  end
  vim.api.nvim_buf_set_name(0, "Codex: nvim-lite")
  vim.api.nvim_tabpage_set_var(0, "codex_config_tab", true)
  vim.api.nvim_buf_set_var(0, "codex_config_buffer", true)
  vim.cmd("startinsert")
end, { desc = "Codex in Neovim config" })

-- Neovim 0.12 manages this profile's small plugin set itself.
local managed_plugins = {
  { src = "https://github.com/ibhagwan/fzf-lua", version = "main" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/sindrets/diffview.nvim" },
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = vim.version.range("3") },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
  { src = "https://github.com/folke/which-key.nvim" },
}

if vim.v.vim_did_enter == 0 then
  vim.pack.add(managed_plugins)
else
  -- vim.pack caches its lockfile for the lifetime of the process. When another
  -- Neovim process installs a new plugin, re-sourcing this config would
  -- otherwise try to clone it again into the existing directory.
  local plugin_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")
  for _, plugin in ipairs(managed_plugins) do
    local name = vim.fs.basename(plugin.src):gsub("%.git$", "")
    if vim.uv.fs_stat(vim.fs.joinpath(plugin_dir, name)) then
      vim.cmd.packadd({ name, magic = { file = false } })
    else
      vim.pack.add({ plugin })
    end
  end
end

require("gitsigns").setup({
  on_attach = function(bufnr)
    local gitsigns = require("gitsigns")
    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        gitsigns.nav_hunk("next")
      end
    end, "Next Git hunk")
    map("n", "[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        gitsigns.nav_hunk("prev")
      end
    end, "Previous Git hunk")

    map("n", "<leader>hp", gitsigns.preview_hunk_inline, "Preview Git hunk")
    map("n", "<leader>hs", gitsigns.stage_hunk, "Stage Git hunk")
    map("n", "<leader>hr", gitsigns.reset_hunk, "Reset Git hunk")
  end,
})

vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Review and update managed plugins" })

-- Small opt-in plugins bundled with Neovim itself; no download required.
vim.cmd.packadd("nvim.undotree")
vim.cmd.packadd("nvim.difftool")
vim.keymap.set("n", "<leader>u", "<cmd>Undotree<cr>", { desc = "Toggle undo tree" })

require("which-key").setup({
  preset = "modern",
  delay = 300,
  win = {
    border = "rounded",
  },
})

-- Tree-sitter provides structural highlighting and language-independent text
-- objects. Install only missing parsers so normal startup does no background
-- package work and the installed queries are immediately available.
local treesitter_parsers = {
  "c",
  "cpp",
  "javascript",
  "python",
  "tsx",
  "typescript",
}
local missing_treesitter_parsers = require("nvim-treesitter.config").norm_languages(
  treesitter_parsers,
  { installed = true }
)
if #missing_treesitter_parsers > 0 then
  require("nvim-treesitter").install(missing_treesitter_parsers)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "c",
    "cpp",
    "javascript",
    "javascriptreact",
    "python",
    "typescript",
    "typescriptreact",
  },
  callback = function(event)
    pcall(vim.treesitter.start, event.buf)
  end,
  desc = "Enable Tree-sitter highlighting",
})

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v",
      ["@function.outer"] = "V",
      ["@class.outer"] = "V",
    },
    include_surrounding_whitespace = false,
  },
})

local ts_select = require("nvim-treesitter-textobjects.select")
local function map_textobject(lhs, capture, description)
  vim.keymap.set({ "x", "o" }, lhs, function()
    ts_select.select_textobject(capture, "textobjects")
  end, { desc = description })
end

map_textobject("af", "@function.outer", "Around function")
map_textobject("if", "@function.inner", "Inside function")
map_textobject("ac", "@class.outer", "Around class")
map_textobject("ic", "@class.inner", "Inside class")
map_textobject("aa", "@parameter.outer", "Around argument")
map_textobject("ia", "@parameter.inner", "Inside argument")

require("tokyonight").setup({
  style = "moon",
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
  },
  on_highlights = function(highlights, colors)
    highlights.WinSeparator = { fg = colors.blue, bold = true }
  end,
})
vim.cmd.colorscheme("tokyonight")

vim.opt.laststatus = 3
local statusline_colors = require("tokyonight.colors").setup({ style = "moon" })
require("lualine").setup({
  options = {
    theme = "tokyonight",
    icons_enabled = false,
    globalstatus = true,
    always_show_tabline = false,
    component_separators = { left = "│", right = "│" },
    section_separators = { left = "", right = "" },
  },
  sections = {
    lualine_a = {
      {
        "mode",
        color = function()
          if vim.bo.modified and vim.api.nvim_get_mode().mode:match("^n") then
            return { bg = statusline_colors.yellow, fg = statusline_colors.black }
          end
        end,
      },
    },
    lualine_b = { "branch" },
    lualine_c = {
      { "filename", path = 1, shorting_target = 40 },
    },
    lualine_x = { "diagnostics", "lsp_status" },
    lualine_y = { "filetype", "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      { "filename", path = 1 },
    },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {
    lualine_a = {
      {
        "tabs",
        mode = 2,
        path = 0,
        tab_max_length = 28,
        max_length = function()
          return vim.o.columns
        end,
        use_mode_colors = false,
        tabs_color = {
          active = {
            fg = statusline_colors.blue,
            bg = statusline_colors.bg_highlight,
            gui = "bold",
          },
          inactive = {
            fg = statusline_colors.comment,
            bg = statusline_colors.bg_statusline,
          },
        },
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        show_modified_status = true,
        symbols = { modified = " ●" },
      },
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  extensions = { "quickfix", "neo-tree" },
})

local function copy_neo_tree_path(state, relative)
  local node = state.tree:get_node()
  if not node.path then
    vim.notify("This node has no filesystem path", vim.log.levels.WARN)
    return
  end

  local path = relative and vim.fn.fnamemodify(node.path, ":.") or node.path
  vim.fn.setreg("+", path)
  vim.notify(relative and "Copied relative path" or "Copied absolute path")
end

require("neo-tree").setup({
  close_if_last_window = true,
  popup_border_style = "rounded",
  default_component_configs = {
    indent = {
      with_expanders = true,
      expander_collapsed = "",
      expander_expanded = "",
    },
    modified = {
      symbol = "*",
    },
    git_status = {
      symbols = {
        added = "+",
        modified = "~",
        deleted = "x",
        renamed = "r",
        untracked = "?",
        ignored = "!",
        unstaged = "!",
        staged = "+",
        conflict = "!",
      },
    },
  },
  window = {
    position = "left",
    width = 32,
    mappings = {
      ["l"] = "open",
      ["h"] = "close_node",
      ["Y"] = {
        function(state)
          copy_neo_tree_path(state, false)
        end,
        desc = "Copy absolute path",
      },
      ["gy"] = {
        function(state)
          copy_neo_tree_path(state, true)
        end,
        desc = "Copy relative path",
      },
    },
  },
  filesystem = {
    hijack_netrw_behavior = "open_default",
    follow_current_file = {
      enabled = true,
      leave_dirs_open = false,
    },
    filtered_items = {
      visible = false,
      hide_dotfiles = true,
      hide_gitignored = true,
    },
  },
})

local function git_root_at_cursor()
  local candidate
  local state = require("neo-tree.sources.manager").get_state_for_window()
  if state and state.tree then
    local node = state.tree:get_node()
    candidate = node and node.path or nil
  end

  if not candidate and vim.bo.buftype == "" then
    candidate = vim.api.nvim_buf_get_name(0)
  end
  if not candidate or candidate == "" then
    candidate = vim.fn.getcwd(-1, -1)
  end

  local stat = vim.uv.fs_stat(candidate)
  if not stat or stat.type ~= "directory" then
    candidate = vim.fs.dirname(candidate)
  end

  local git_root = require("neo-tree.git").find_worktree_info(candidate)
  return git_root or candidate
end

vim.keymap.set("n", "<leader>ee", "<cmd>Neotree filesystem toggle reveal left<cr>", { desc = "Toggle file tree" })
vim.keymap.set("n", "<leader>eg", function()
  require("neo-tree.command").execute({
    action = "focus",
    source = "git_status",
    position = "left",
    dir = git_root_at_cursor(),
  })
end, { desc = "Open Git tree at cursor" })

local ok, fzf = pcall(require, "fzf-lua")
if ok then
  fzf.setup({
    fzf_opts = { ["--layout"] = "reverse-list" },
    files = {
      fd_opts = "--color=never --type f --hidden --follow --exclude .git",
    },
    grep = {
      rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!.git'",
    },
  })

  vim.keymap.set("n", "<leader>f", fzf.files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>/", fzf.live_grep, { desc = "Search repository" })
  vim.keymap.set("n", "<leader>b", fzf.buffers, { desc = "Switch buffers" })
  vim.keymap.set("n", "<leader>sw", fzf.grep_cword, { desc = "Search word under cursor" })
  vim.keymap.set("n", "<leader>gs", fzf.git_status, { desc = "Git status" })
  vim.keymap.set("n", "<leader>gc", fzf.git_commits, { desc = "Git commits" })
  vim.keymap.set("n", "<leader>gb", fzf.git_branches, { desc = "Git branches" })
end

-- Native Neovim 0.12 LSP: no LSP framework plugin required.
if vim.fn.executable("clangd") == 1 then
  vim.lsp.config("clangd", {
    cmd = { "clangd" },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
    root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt", ".git" },
  })
  vim.lsp.enable("clangd")
end

local ts_lsp = vim.fn.stdpath("data")
  .. "/lsp/typescript/node_modules/.bin/typescript-language-server"
local tsserver_path = vim.fn.stdpath("data")
  .. "/lsp/typescript/node_modules/typescript/lib/tsserver.js"
local ts_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
}
local ts_root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" }

local function find_typescript_installation(start_dir)
  local dir = start_dir
  while dir and dir ~= "" do
    local package_path = dir .. "/node_modules/typescript/package.json"
    local tsc_path = dir .. "/node_modules/.bin/tsc"
    if vim.fn.filereadable(package_path) == 1 and vim.fn.executable(tsc_path) == 1 then
      local ok, package = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_path), "\n"))
      local major = ok and package.version and tonumber(package.version:match("^(%d+)"))
      if major then
        return { major = major, tsc = tsc_path }
      end
    end

    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
end

local function typescript_workspace(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local start_dir = filename ~= "" and vim.fs.dirname(filename) or vim.uv.cwd()
  return {
    root = vim.fs.root(start_dir, ts_root_markers),
    installation = find_typescript_installation(start_dir),
  }
end

if vim.fn.executable(ts_lsp) ~= 1 then
  ts_lsp = "typescript-language-server"
end

-- TypeScript 7 ships a native LSP. Activate it only for workspaces that have
-- the native compiler installed, and launch that exact project-local version.
vim.lsp.config("tsgo", {
  cmd = function(dispatchers, config)
    local installation = find_typescript_installation(config.root_dir)
    assert(installation and installation.major >= 7, "TypeScript 7 installation disappeared")
    return vim.lsp.rpc.start(
      { installation.tsc, "--lsp", "--stdio" },
      dispatchers,
      { cwd = config.root_dir }
    )
  end,
  filetypes = ts_filetypes,
  root_dir = function(bufnr, on_dir)
    local workspace = typescript_workspace(bufnr)
    if workspace.root and workspace.installation and workspace.installation.major >= 7 then
      on_dir(workspace.root)
    end
  end,
  workspace_required = true,
})
vim.lsp.enable("tsgo")

if vim.fn.executable(ts_lsp) == 1 then
  vim.lsp.config("ts_ls", {
    cmd = { ts_lsp, "--stdio" },
    filetypes = ts_filetypes,
    root_dir = function(bufnr, on_dir)
      local workspace = typescript_workspace(bufnr)
      if not workspace.installation or workspace.installation.major < 7 then
        on_dir(workspace.root)
      end
    end,
    workspace_required = false,
    init_options = {
      hostInfo = "neovim",
      tsserver = {
        fallbackPath = tsserver_path,
        useSyntaxServer = "never",
      },
    },
  })
  vim.lsp.enable("ts_ls")
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf)
    end

    -- Keep the familiar definition mapping. Neovim supplies grr/gri/grn/gra,
    -- grt/grx, gO, K, and insert-mode Ctrl-S as native LSP defaults.
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
      buffer = event.buf,
      desc = "Go to definition",
    })

    vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get, {
      buffer = event.buf,
      desc = "Trigger LSP completion",
    })
  end,
})

vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

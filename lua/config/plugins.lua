-- Bundled local plugin; no download or package-manager entry required.
local profile = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2))))
local workspace_path = vim.fs.joinpath(profile, "plugins", "workspace.nvim")
if not vim.tbl_contains(vim.opt.runtimepath:get(), workspace_path) then
  vim.opt.runtimepath:prepend(workspace_path)
end

local managed_plugins = {
  { src = "https://github.com/ibhagwan/fzf-lua", version = "main" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  { src = "https://github.com/sindrets/diffview.nvim" },
  { src = "https://github.com/folke/tokyonight.nvim" },
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  { src = "https://github.com/rose-pine/neovim", name = "rose-pine" },
  { src = "https://github.com/sainnhe/gruvbox-material" },
  { src = "https://github.com/projekt0n/github-nvim-theme" },
  { src = "https://github.com/nvim-lualine/lualine.nvim" },
  { src = "https://github.com/nvim-neo-tree/neo-tree.nvim", version = vim.version.range("3") },
  { src = "https://github.com/nvim-lua/plenary.nvim" },
  { src = "https://github.com/MunifTanjim/nui.nvim" },
  { src = "https://github.com/nvim-tree/nvim-web-devicons" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
  { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim" },
  { src = "https://github.com/folke/which-key.nvim" },
}

if vim.v.vim_did_enter == 0 then
  vim.pack.add(managed_plugins)
else
  -- vim.pack caches its lockfile for the lifetime of the process. When another
  -- Neovim process installs a plugin, load it directly if already on disk.
  local plugin_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")
  for _, plugin in ipairs(managed_plugins) do
    local name = plugin.name or vim.fs.basename(plugin.src):gsub("%.git$", "")
    if vim.uv.fs_stat(vim.fs.joinpath(plugin_dir, name)) then
      vim.cmd.packadd({ name, magic = { file = false } })
    else
      vim.pack.add({ plugin })
    end
  end
end

require("render-markdown").setup({})

require("gitsigns").setup({
  current_line_blame = true,
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
    map("n", "<leader>hb", function()
      gitsigns.blame()
    end, "Blame file")
    map("n", "<leader>hs", gitsigns.stage_hunk, "Stage Git hunk")
    map("n", "<leader>hr", gitsigns.reset_hunk, "Reset Git hunk")
  end,
})

vim.keymap.set("n", "<leader>dd", "<cmd>DiffviewOpen<cr>", { desc = "Open local changes" })
vim.keymap.set("n", "<leader>dc", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" })
vim.keymap.set("n", "<leader>df", "<cmd>DiffviewFileHistory %<cr>", { desc = "Current file history" })
vim.keymap.set("n", "<leader>dh", "<cmd>DiffviewFileHistory<cr>", { desc = "Repository history" })
vim.keymap.set("n", "<leader>dl", "<cmd>DiffviewOpen HEAD^!<cr>", { desc = "Latest commit changes" })

vim.api.nvim_create_user_command("PackUpdate", function()
  vim.pack.update()
end, { desc = "Review and update managed plugins" })

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

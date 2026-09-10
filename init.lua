-- Re-source all configuration modules when this entrypoint is sourced again.
local config_modules = {}
for module_name in pairs(package.loaded) do
  if vim.startswith(module_name, "config.") or module_name == "workspace"
      or vim.startswith(module_name, "workspace.") then
    config_modules[#config_modules + 1] = module_name
  end
end
for _, module_name in ipairs(config_modules) do
  package.loaded[module_name] = nil
end

require("config.options")
require("config.config_update")
require("config.keymaps")
require("config.diagnostics")
require("config.config_workspace")
require("config.plugins")
require("config.treesitter")
require("config.ui")
-- Tools own their keymaps; the entrypoint injects context-specific behavior.
local yadm = require("config.yadm")
local workspace = require("workspace")
local workspace_picker = require("workspace.fzf")
local workspace_tree = require("workspace.neotree")
workspace.setup({
  blocked = yadm.work_tree,
  excluded = function(tab) return vim.t[tab].config_workspace_tab == true end,
})
require("config.explorer").setup({
  sources = { "config.yadm_tree", "workspace.neotree" },
  toggle_tree = function() return workspace_tree.toggle_tree() or yadm.toggle_tree() end,
  focus_tree = function() return workspace_tree.focus_tree() or yadm.focus_tree() end,
})
require("config.lazygit").setup({
  launch_args = yadm.lazygit_args,
  cwd = function() return yadm.work_tree() or require("config.explorer").git_root_at_cursor() end,
})
require("config.picker").setup({
  find_files = function() return workspace_picker.find_files() or yadm.find_files() end,
  live_grep = workspace_picker.live_grep,
})
require("config.lsp")
require("config.startup")

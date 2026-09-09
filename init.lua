-- Re-source all configuration modules when this entrypoint is sourced again.
local config_modules = {}
for module_name in pairs(package.loaded) do
  if vim.startswith(module_name, "config.") then
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
require("config.codex")
require("config.plugins")
require("config.treesitter")
require("config.ui")
-- Tools own their keymaps; the entrypoint injects context-specific behavior.
local yadm = require("config.yadm")
require("config.explorer").setup({ sources = { "config.yadm_tree" }, toggle_tree = yadm.toggle_tree })
require("config.lazygit").setup({
  launch_args = yadm.lazygit_args,
  cwd = function() return yadm.work_tree() or require("config.explorer").git_root_at_cursor() end,
})
require("config.picker").setup({ find_files = yadm.find_files })
require("config.lsp")
require("config.startup")

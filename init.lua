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
require("config.keymaps")
require("config.diagnostics")
require("config.codex")
require("config.lazygit")
require("config.plugins")
require("config.treesitter")
require("config.ui")
require("config.explorer")
require("config.picker")
require("config.lsp")
require("config.startup")

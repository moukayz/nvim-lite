-- Re-source all configuration modules when this entrypoint is sourced again.
local config_modules = {}
for module_name in pairs(package.loaded) do
  if vim.startswith(module_name, "nvim_lite.") then
    config_modules[#config_modules + 1] = module_name
  end
end
for _, module_name in ipairs(config_modules) do
  package.loaded[module_name] = nil
end

require("nvim_lite.options")
require("nvim_lite.keymaps")
require("nvim_lite.diagnostics")
require("nvim_lite.tools")
require("nvim_lite.plugins")
require("nvim_lite.treesitter")
require("nvim_lite.ui")
require("nvim_lite.explorer")
require("nvim_lite.picker")
require("nvim_lite.lsp")

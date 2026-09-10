-- Standalone core: no profile or UI dependency should be needed.
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. "/plugins/workspace.nvim")
local core = require("workspace")
core.setup()
assert(not package.loaded["fzf-lua"] and not package.loaded["neo-tree"])
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
assert(core.add({ root }))
local roots, valid = core.snapshot()
assert(valid() and #roots == 1)
core.setup()
assert(valid(), "repeat setup should retain roots and snapshots")
package.loaded.workspace = nil
core = require("workspace")
core.setup()
assert(not valid(), "reload must invalidate old snapshots")
assert(vim.deep_equal(core.roots(), roots), "reload must preserve roots")
assert(not package.loaded["fzf-lua"] and not package.loaded["neo-tree"])
for _, name in ipairs({ "init", "scan", "fzf", "neotree" }) do
  local source = table.concat(vim.fn.readfile("plugins/workspace.nvim/lua/workspace/" .. name .. ".lua"), "\n")
  assert(not source:find("config%.") and not source:find("yadm") and not source:find("codex"),
    "plugin must not depend on host policy: " .. name)
end
vim.cmd("WorkspaceClear")
assert(#core.roots() == 0)
print("standalone workspace plugin tests passed")
vim.cmd("qa!")

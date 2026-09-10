-- Real fd and Neo-tree; thousands of descendants must not enter the initial tree.
vim.o.swapfile = false
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/large/deep", "p")
root = vim.uv.fs_realpath(root)
for i = 1, 2000 do
  vim.fn.writefile({ "fixture" }, string.format("%s/large/deep/%04d.txt", root, i))
end
vim.fn.writefile({ "visible" }, root .. "/large/file.txt")
local workspace = require("workspace")
local source = require("workspace.neotree")
local renderer = require("neo-tree.ui.renderer")
local list, calls = require("workspace.scan").list, {}
require("workspace.scan").list = function(roots, dirs, callback, depth)
  assert(depth == 1 and dirs and #roots == 1, "tree requested a recursive scan")
  calls[#calls + 1] = roots[1]
  return list(roots, dirs, callback, depth)
end
assert(workspace.add({ root }))
local start = vim.uv.hrtime()
require("workspace.neotree").toggle_tree()
local state = require("neo-tree.sources.manager").get_state("workspace")
assert(#calls == 0, "opening tree scanned descendants")
assert(#state.tree:get_nodes() == 1)
local function toggle(path)
  renderer.focus_node(state, path)
  source.commands.open(state)
end
toggle(root)
assert(vim.wait(3000, function() return state.tree:get_node(root .. "/large") ~= nil end))
assert(not state.tree:get_node(root .. "/large/deep"))
toggle(root .. "/large")
assert(vim.wait(3000, function() return state.tree:get_node(root .. "/large/file.txt") ~= nil end))
assert(not state.tree:get_node(root .. "/large/deep/0001.txt"))
assert(#calls == 2 and calls[2] == root .. "/large")
print(string.format("lazy tree: 2000 hidden descendants, 2 shallow scans, %.1f ms", (vim.uv.hrtime() - start) / 1e6))
toggle(root .. "/large")
toggle(root .. "/large")
assert(#calls == 2, "cached expansion scanned again")
renderer.focus_node(state, root .. "/large/file.txt")
for _ = 1, 2 do
  require("workspace.neotree").toggle_tree()
  require("workspace.neotree").toggle_tree()
  assert(#calls == 2, "reopen rescanned cached tree")
  assert(state.tree:get_node(root .. "/large/file.txt"))
  assert(state.tree:get_node(root .. "/large"):is_expanded())
  assert(state.tree:get_node():get_id() == root .. "/large/file.txt", "reopen lost cursor")
end
source.commands.refresh(state)
assert(vim.wait(3000, function() return state.tree:get_node(root .. "/large/file.txt") ~= nil end))
assert(#calls == 4 and not state.tree:get_node(root .. "/large/deep/0001.txt"))

local pending
require("workspace.scan").list = function(_, _, callback, depth) assert(depth == 1); pending = callback end
toggle(root .. "/large/deep")
assert(pending)
source.commands.close_node(state)
pending({ { path = root .. "/large/deep/stale", relative = "stale", type = "file" } })
assert(not state.tree:get_node(root .. "/large/deep/stale"), "cancelled expansion rendered")
toggle(root .. "/large/deep")
require("workspace.neotree").toggle_tree()
pending({})
assert(not state.winid or not vim.api.nvim_win_is_valid(state.winid), "closed tree reopened")
print("lazy workspace tree tests passed")
vim.cmd("qa!")

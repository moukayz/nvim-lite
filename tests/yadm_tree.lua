-- Load the full profile first. Stub only context/listing, not Neo-tree itself.
local root = vim.fn.getcwd()
-- Simulate repeated stage-1/2/3 paths from an unresolved Git index.
local tracked = { "init.lua", "init.lua", "init.lua", "lua/config/picker.lua",
  "lua/config/picker.lua", "lua/config/yadm.lua" }
local built = require("config.yadm_tree").build_nodes(root, tracked)
local seen, leaves = {}, 0
local function check_unique(nodes)
  for _, node in ipairs(nodes) do
    assert(not seen[node.id], "duplicate node ID: " .. node.id)
    seen[node.id] = true
    if node.type == "file" then leaves = leaves + 1 end
    check_unique(node.children or {})
  end
end
check_unique(built)
assert(leaves == 3, "expected one leaf per unique tracked path")
local function install_fixture()
  require("config.yadm").work_tree = function() return root end
end
local original_system = vim.system
local pending = {}
local defer = false
vim.env.GIT_DIR = root .. "/.git"
vim.system = function(argv, opts, callback)
  if argv[1] == "git" and argv[2] == "--git-dir=" .. vim.env.GIT_DIR then
    assert(type(callback) == "function", "listing must be asynchronous")
    local finish = function() callback({ code = 0, stdout = table.concat(tracked, "\0") .. "\0", stderr = "" }) end
    if defer then pending[#pending + 1] = finish else vim.schedule(finish) end
    return {}
  end
  return original_system(argv, opts, callback)
end
for _ = 1, 2 do
  install_fixture()
  vim.fn.maparg("<leader>ee", "n", false, true).callback()
  local manager = require("neo-tree.sources.manager")
  local state = manager.get_state("yadm")
  assert(vim.wait(1000, function() return state.tree and state.tree:get_node(root .. "/init.lua") ~= nil end))
  assert(state.tree:get_node(root .. "/lua/config/picker.lua"), "tracked nested file missing")
  assert(not state.tree:get_node(root .. "/AGENTS.md"), "unlisted file leaked into tree")
  require("neo-tree.ui.renderer").focus_node(state, root .. "/init.lua")
  require("config.yadm_tree").commands.open(state)
  assert(vim.api.nvim_buf_get_name(0) == root .. "/init.lua", "open resolved wrong file")
  vim.fn.maparg("<leader>ee", "n", false, true).callback()
  assert(not state.winid or not vim.api.nvim_win_is_valid(state.winid), "toggle did not close")
  vim.cmd.source(vim.env.MYVIMRC)
end
install_fixture()
defer = true
vim.fn.maparg("<leader>ee", "n", false, true).callback()
local state = require("neo-tree.sources.manager").get_state("yadm")
vim.fn.maparg("<leader>ee", "n", false, true).callback()
pending[1]()
vim.wait(20, function() return false end)
assert(not state.winid or not vim.api.nvim_win_is_valid(state.winid), "late result reopened a closed tree")
-- Normal context retains the original command and does not route to yadm.
require("config.yadm").work_tree = function() return nil end
local command
local original_cmd = vim.cmd
vim.cmd = function(cmd) command = cmd end
vim.fn.maparg("<leader>ee", "n", false, true).callback()
vim.cmd = original_cmd
assert(command == "Neotree filesystem toggle reveal left")
vim.system = original_system
print("nvim-lite yadm tree: ok")
vim.cmd("qa!")

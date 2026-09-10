local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.cmd("enew")
local editor = vim.api.nvim_get_current_win()
local command = require("neo-tree.command")
local original, calls = command.execute, {}
command.execute = function(opts)
  calls[#calls + 1] = opts
  return original(opts)
end
local function focus(mode, source)
  local count = #calls
  local map = vim.fn.maparg("<leader>ef", mode, false, true)
  assert(map.callback and map.desc == "Focus file tree")
  map.callback()
  assert(vim.wait(2000, function() return #calls > count end))
  local opts = calls[#calls]
  assert(opts.source == source and opts.action == "focus" and not opts.toggle)
  local state = require("neo-tree.sources.manager").get_state(source)
  assert(state.winid == vim.api.nvim_get_current_win(), "tree not focused")
  return state.winid
end
local win = focus("n", "filesystem")
assert(focus("n", "filesystem") == win, "focus closed/replaced tree")
require("neo-tree.sources.common.commands").close_window(require("neo-tree.sources.manager").get_state("filesystem"))
assert(require("workspace").add({ root }))
win = focus("n", "workspace")
assert(focus("n", "workspace") == win)
vim.api.nvim_set_current_win(editor)
vim.cmd.source(vim.env.MYVIMRC)
assert(focus("n", "workspace") == win, "reload broke focus")
-- Exercise terminal input with a real terminal buffer, not a running shell.
vim.api.nvim_set_current_win(editor)
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_open_term(buf, {})
vim.cmd("startinsert")
assert(focus("t", "workspace") == win)
-- Inject only context detection; avoid external Git access for this routing check.
require("workspace").setup({ blocked = function() return true end })
require("config.yadm").work_tree = function() return root end
command.execute = function(opts) calls[#calls + 1] = opts end
local count = #calls
vim.fn.maparg("<leader>ef", "n", false, true).callback()
assert(vim.wait(1000, function() return #calls > count end))
assert(calls[#calls].source == "yadm" and not calls[#calls].toggle)
print("explorer focus tests passed")
vim.cmd("qa!")

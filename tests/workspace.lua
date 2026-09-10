-- Run after loading the full profile. Real fd, files, and Neo-tree; stub picker UI only.
vim.o.swapfile = false
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, "p")
fixture = vim.uv.fs_realpath(fixture)
local a, b, c = fixture .. "/A space", fixture .. "/B", fixture .. "/C"
for _, root in ipairs({ a, b, c }) do vim.fn.mkdir(root .. "/empty", "p") end
vim.fn.writefile({ "alpha match" }, a .. "/one.txt")
vim.fn.writefile({ "beta match" }, b .. "/two.txt")
vim.fn.writefile({ "outside match" }, c .. "/outside.txt")
vim.fn.writefile({ "literal" }, b .. '/quote"tab\t.txt')
vim.fn.mkdir(a .. "/.git", "p")
vim.fn.writefile({ "private" }, a .. "/.git/config")
assert(vim.uv.fs_symlink(c, a .. "/outside-link"))
local workspace = require("workspace")
local cwd = vim.fn.getcwd()
vim.cmd("WorkspaceAdd " .. vim.fn.fnameescape(a) .. " " .. vim.fn.fnameescape(b))
assert(vim.deep_equal(workspace.roots(), { a, b }))
assert(vim.fn.getcwd() == cwd)
assert(workspace.add({ a }))
assert(#workspace.roots() == 2, "duplicate root")
local ok = workspace.add({ a .. "/empty" })
assert(not ok and #workspace.roots() == 2, "nested root")
ok = workspace.add({ c, fixture .. "/missing" })
assert(not ok and #workspace.roots() == 2, "add must be atomic")
local done, items
require("workspace.scan").list(workspace.roots(), true, function(result, err)
  assert(result, err)
  items, done = result, true
end)
assert(vim.wait(3000, function() return done end))
local paths = {}
for _, item in ipairs(items) do paths[item.path] = item end
assert(paths[a .. "/one.txt"] and paths[b .. "/two.txt"])
assert(paths[a .. "/empty"].type == "directory")
assert(not paths[c .. "/outside.txt"] and not paths[a .. "/outside-link/outside.txt"])
assert(not paths[a .. "/.git/config"])

local fzf, captured, grep_options = require("fzf-lua")
fzf.fzf_exec = function(contents, opts)
  captured = { entries = {}, opts = opts }
  contents(function(value) if value == nil then captured.done = true end end, function(chunk, cb)
    vim.list_extend(captured.entries, vim.split(chunk, "\n", { trimempty = true }))
    if cb then cb() end
  end)
end
fzf.live_grep = function(opts) grep_options = opts end
vim.fn.maparg("<leader>f", "n", false, true).callback()
assert(captured, "picker should open before scanning finishes")
assert(vim.wait(3000, function() return captured.done end))
assert(#captured.entries == 3)
local selected = vim.tbl_filter(function(entry) return entry:find("two.txt", 1, true) end, captured.entries)[1]
assert(selected:find("B/two.txt", 1, true))
local preview = captured.opts.previewer._ctor()
assert(preview.entry_to_file(preview, selected).path == b .. "/two.txt")
captured.opts.actions.enter({ selected })
assert(vim.api.nvim_buf_get_name(0) == b .. "/two.txt")
local literal = vim.tbl_filter(function(entry) return entry:find('quote"', 1, true) end, captured.entries)[1]
captured.opts.actions.enter({ literal })
assert(vim.api.nvim_buf_get_name(0) == b .. '/quote"tab\t.txt', "literal path corrupted")
assert(vim.fn.getcwd() == cwd)
vim.fn.maparg("<leader>/", "n", false, true).callback()
assert(vim.deep_equal(grep_options.search_paths, { a, b }))
assert(grep_options.cwd == a and vim.fn.getcwd() == cwd)
-- Exercise fzf-lua's real rg command builder, not just the option forwarding.
local grep = vim.tbl_extend("force", grep_options, {
  rg_opts = "--column --line-number --no-heading --color=never --hidden --glob '!.git'",
})
local grep_cmd = require("fzf-lua.make_entry").get_grep_cmd(grep, "match")
local matches = vim.system({ "sh", "-c", grep_cmd }, { cwd = a, text = true }):wait()
assert(matches.code == 0, matches.stderr)
assert(matches.stdout:find("alpha match", 1, true) and matches.stdout:find("beta match", 1, true))
assert(not matches.stdout:find("outside match", 1, true), "grep escaped workspace")

local tab = vim.api.nvim_get_current_tabpage()
vim.cmd("tabnew")
assert(vim.deep_equal(workspace.roots(), { a, b }), "ordinary tabs must share roots")
-- The dedicated Codex config tab is explicitly excluded, not every terminal.
vim.t.codex_config_tab = true
vim.api.nvim_cmd({ cmd = "tcd", args = { vim.fn.stdpath("config") } }, {})
assert(#workspace.roots() == 0, "config tab inherited global roots")
assert(not require("workspace.fzf").find_files() and not require("workspace.fzf").live_grep())
assert(not require("workspace.neotree").toggle_tree())
assert(vim.deep_equal(workspace.all_roots(), { a, b }), "exclusion changed global roots")
local file_calls, old_files = 0, fzf.files
fzf.files = function(opts) assert(opts == nil); file_calls = file_calls + 1 end
vim.fn.maparg("<leader>f", "n", false, true).callback()
assert(file_calls == 1 and vim.fn.getcwd() == vim.fn.stdpath("config"))
fzf.files = old_files
vim.cmd("tabclose")
assert(vim.api.nvim_get_current_tabpage() == tab)
vim.cmd.source(vim.env.MYVIMRC)
workspace = require("workspace")
assert(vim.deep_equal(workspace.roots(), { a, b }), "reload lost roots")
vim.cmd("enew") -- Root-only browsing; current-file reveal has its own tests.
vim.fn.maparg("<leader>ee", "n", false, true).callback()
assert(#vim.api.nvim_get_autocmds({ group = "WorkspaceTree" }) == 2)
local state = require("neo-tree.sources.manager").get_state("workspace")
local function expand(tree_state, path)
  vim.api.nvim_win_call(tree_state.winid, function()
    require("neo-tree.ui.renderer").focus_node(tree_state, path)
    require("workspace.neotree").commands.open(tree_state)
  end)
end
assert(not state.tree:get_node(b .. "/two.txt"), "closed root was scanned eagerly")
expand(state, a)
expand(state, b)
assert(vim.wait(3000, function() return state.tree and state.tree:get_node(b .. "/two.txt") ~= nil end))
assert(state.tree:get_node(a) and state.tree:get_node(b), "missing roots")
assert(not state.tree:get_node(fixture), "parent directory leaked into tree")
local original_win = vim.api.nvim_get_current_win()
vim.cmd("tabnew")
local other_tab = vim.api.nvim_get_current_tabpage()
require("workspace.neotree").toggle_tree()
local other_state = require("neo-tree.sources.manager").get_state("workspace")
expand(other_state, a)
expand(other_state, b)
assert(vim.wait(3000, function() return other_state.tree and other_state.tree:get_node(b .. "/two.txt") end))
vim.api.nvim_set_current_win(original_win)
vim.cmd.source(vim.env.MYVIMRC)
workspace = require("workspace")
assert(#vim.api.nvim_get_autocmds({ group = "WorkspaceTree" }) == 2)
state = require("neo-tree.sources.manager").get_state("workspace", tab)
other_state = require("neo-tree.sources.manager").get_state("workspace", other_tab)
local renderer = require("neo-tree.ui.renderer")
renderer.focus_node(state, b .. "/two.txt")
require("workspace.neotree").commands.open(state)
assert(vim.api.nvim_buf_get_name(0) == b .. "/two.txt")
assert(workspace.add({ c }))
assert(state.tree:get_node(c) and not state.tree:get_node(c .. "/outside.txt"))
expand(state, c)
expand(other_state, c)
assert(vim.wait(3000, function() return state.tree:get_node(c .. "/outside.txt") ~= nil end))
assert(vim.wait(3000, function() return other_state.tree:get_node(c .. "/outside.txt") ~= nil end))
assert(vim.api.nvim_get_current_tabpage() == tab, "background refresh stole focus")
local select = vim.ui.select
vim.ui.select = function(_, _, callback) callback(c) end
vim.cmd("WorkspaceRemove")
vim.ui.select = select
assert(vim.wait(3000, function() return state.tree:get_node(c) == nil end))
assert(vim.wait(3000, function() return other_state.tree:get_node(c) == nil end))
vim.cmd("WorkspaceClear")
assert(#workspace.roots() == 0 and not vim.api.nvim_win_is_valid(state.winid or -1))
assert(not vim.api.nvim_win_is_valid(other_state.winid or -1), "clear left another tab's tree open")
vim.api.nvim_set_current_tabpage(other_tab)
assert(#workspace.roots() == 0)
vim.cmd("tabclose")
local act = require("fzf-lua.actions").act
require("fzf-lua.actions").act = function() error("stale grep action") end
grep_options.fn_selected({}, {})
require("fzf-lua.actions").act = act

-- Tree scans must not reopen closed windows.
assert(workspace.add({ a, b }))
local pending = {}
require("workspace.scan").list = function(_, _, callback) pending[#pending + 1] = callback end
require("workspace.neotree").toggle_tree()
state = require("neo-tree.sources.manager").get_state("workspace")
expand(state, a)
require("workspace.neotree").toggle_tree()
pending[1]({})
assert(not state.winid or not vim.api.nvim_win_is_valid(state.winid), "late result reopened tree")
workspace.setup({ blocked = function() return true end })
assert(not workspace.add({ c }), "yadm activation allowed")
assert(not require("workspace.fzf").find_files() and not require("workspace.fzf").live_grep() and not require("workspace.neotree").toggle_tree())
local labels = workspace.labels({ "/one/same", "/two/same" })
assert(labels["/one/same"] ~= labels["/two/same"])
print("workspace tests passed")
vim.cmd("qa!")

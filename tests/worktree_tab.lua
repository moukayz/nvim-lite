-- Exercise real worktree discovery; stub only picker UI and tree opening.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root)
local function git(args)
  local result = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true }):wait()
  assert(result.code == 0, result.stderr)
end
git({ "init", "-q" })
git({ "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "fixture" })
local target = root .. "/worktree space"
git({ "worktree", "add", "-qb", "test", target })
vim.cmd("enew")
vim.api.nvim_cmd({ cmd = "tcd", args = { root } }, {})
local original_tab, original_cwd = vim.api.nvim_get_current_tabpage(), vim.fn.getcwd()
local entries, opts, tree
require("fzf-lua").fzf_exec = function(e, o) entries, opts = e, o end
require("neo-tree.command").execute = function(o) tree = o end
vim.fn.maparg("<leader>gw", "n", false, true).callback()
assert(vim.wait(2000, function() return opts ~= nil end))
local selected
for _, entry in ipairs(entries) do if entry:find(target, 1, true) then selected = entry end end
assert(selected and opts.actions.enter)
assert(require("workspace").add({ root }))
local roots = require("workspace").all_roots()
opts.actions["ctrl-t"]({ selected })
assert(vim.api.nvim_get_current_tabpage() ~= original_tab)
assert(vim.fn.getcwd() == target)
assert(vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(0)) == target, "tab cwd not set")
assert(tree.source == "filesystem" and tree.dir == target and tree.action == "focus")
assert(vim.deep_equal(require("workspace").all_roots(), roots), "switch changed workspace scope")
vim.api.nvim_set_current_tabpage(original_tab)
assert(vim.fn.getcwd() == original_cwd, "switch changed original tab cwd")
local count = #vim.api.nvim_list_tabpages()
opts.actions["ctrl-t"]({})
assert(#vim.api.nvim_list_tabpages() == count)
print("worktree tab tests passed")
vim.cmd("qa!")

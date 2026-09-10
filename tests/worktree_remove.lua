vim.o.swapfile = false
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root)
local function git(args)
  local result = vim.system(vim.list_extend({ "git", "-C", root }, args), { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end
git({ "init", "-q" })
git({ "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "fixture" })
local target = root .. "/linked space"
git({ "worktree", "add", "-qb", "linked", target })
vim.cmd("enew")
vim.api.nvim_cmd({ cmd = "tcd", args = { root } }, {})
local entries, opts, confirmation, notice
require("fzf-lua").fzf_exec = function(e, o) entries, opts = e, o end
vim.ui.select = function(choices, _, callback)
  assert(choices[1] == "Cancel")
  confirmation = callback
end
vim.notify = function(message) notice = message end
vim.fn.maparg("<leader>gw", "n", false, true).callback()
assert(vim.wait(2000, function() return opts ~= nil end))
local selected
for _, entry in ipairs(entries) do if entry:find(target, 1, true) then selected = entry end end
assert(selected)
local function remove() opts.actions["ctrl-x"]({ selected }); assert(confirmation) end
remove(); confirmation("Cancel")
assert(vim.fn.isdirectory(target) == 1)
vim.fn.writefile({ "untracked" }, target .. "/dirty.txt")
remove(); confirmation("Remove")
assert(vim.wait(2000, function() return notice and notice:find("removal failed", 1, true) end))
assert(vim.fn.isdirectory(target) == 1, "dirty worktree was forced away")
vim.fn.delete(target .. "/dirty.txt")
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, target .. "/unsaved.txt")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved" })
remove(); confirmation("Remove")
assert(notice:find("unsaved buffers", 1, true))
assert(vim.fn.isdirectory(target) == 1)
vim.api.nvim_buf_delete(buf, { force = true })
notice = nil
remove(); confirmation("Remove")
assert(vim.wait(2000, function() return notice and notice:find("Removed worktree:", 1, true) end))
assert(vim.fn.isdirectory(target) == 0)
assert(git({ "branch", "--list", "linked" }):find("linked", 1, true), "branch deleted")
print("worktree removal tests passed")
vim.cmd("qa!")

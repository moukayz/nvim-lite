-- Load the full profile first; only stub the final picker UI.
vim.o.swapfile = false
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, "p")
fixture = vim.uv.fs_realpath(fixture)
local function git(dir, args)
  local result = vim.system(vim.list_extend({ "git", "-C", dir }, args), { text = true }):wait()
  assert(result.code == 0, result.stderr)
end
git(fixture, { "init", "-q" })
local source = fixture .. "/source"
vim.fn.mkdir(source, "p")
git(source, { "init", "-q" })
vim.fn.writefile({ "test" }, source .. "/file.txt")
git(source, { "add", "file.txt" })
git(source, { "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
  "-c", "commit.gpgsign=false", "commit", "-qm", "fixture" })
git(fixture, { "-c", "protocol.file.allow=always", "submodule", "add", "-q", source, "sub" })
vim.fn.writefile({ "parent" }, fixture .. "/main.txt")
vim.cmd.cd(fixture)
local selected
require("fzf-lua").git_status = function(opts) selected = opts.cwd end
for _, case in ipairs({ { "/main.txt", fixture }, { "/sub/file.txt", fixture .. "/sub" } }) do
  vim.api.nvim_set_current_buf(vim.fn.bufadd(fixture .. case[1]))
  vim.fn.maparg("<leader>gs", "n", false, true).callback()
  assert(selected == case[2], vim.inspect({ selected, case[2] }))
  assert(vim.fn.getcwd() == fixture, "picker must not change cwd")
end
print("git status root tests passed")
vim.cmd("qa!")

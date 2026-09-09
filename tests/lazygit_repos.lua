-- Full profile; real Git root resolution, stub only the terminal jobs.
vim.o.swapfile = false
local repo = vim.fn.tempname()
vim.fn.mkdir(repo .. "/nested", "p")
repo = vim.uv.fs_realpath(repo)
assert(vim.system({ "git", "-C", repo, "init", "-q" }):wait().code == 0)
local config = vim.uv.fs_realpath(vim.fn.stdpath("config"))
local starts, launch_dirs = 0, {}
vim.fn.jobstart = function(command, opts)
  assert(command[1] == "lazygit" and opts.term)
  starts = starts + 1
  launch_dirs[starts] = vim.uv.fs_realpath(opts.cwd)
  return starts
end
local function open()
  vim.fn.maparg("<leader>gg", "n", false, true).callback()
  return vim.api.nvim_get_current_buf()
end
local function hide() vim.fn.maparg("<C-g>", "n", false, true).callback() end
local function exit(buffer)
  vim.api.nvim_get_autocmds({ group = "LazygitTerminal", event = "TermClose" })[1].callback({ buf = buffer })
  assert(vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(buffer) end))
end
vim.cmd("enew")
vim.api.nvim_cmd({ cmd = "tcd", args = { repo } }, {})
local code_tab = vim.api.nvim_get_current_tabpage()
local code_buffer = open()
assert(launch_dirs[1] == repo)
hide()

vim.cmd("tabnew")
vim.api.nvim_cmd({ cmd = "tcd", args = { config } }, {})
-- Like the Codex terminal: no file path, so use this tab's cwd, not global cwd.
vim.bo.buftype = "nofile"
local config_tab = vim.api.nvim_get_current_tabpage()
local config_buffer = open()
assert(starts == 2 and launch_dirs[2] == config and config_buffer ~= code_buffer)
hide()
vim.cmd.source(vim.env.MYVIMRC)
assert(open() == config_buffer and starts == 2, "reload must preserve repo instances")
hide()
vim.api.nvim_set_current_tabpage(code_tab)
assert(open() == code_buffer and starts == 2, "code tab restored wrong repo")
hide()
-- Another directory and another tab in the same repo must share its process.
vim.cmd("tabnew")
vim.api.nvim_cmd({ cmd = "tcd", args = { repo .. "/nested" } }, {})
local nested_tab = vim.api.nvim_get_current_tabpage()
assert(open() == code_buffer and starts == 2)
-- If still visible elsewhere, move the float here without jumping tabs.
vim.api.nvim_set_current_tabpage(code_tab)
assert(open() == code_buffer and starts == 2)
assert(vim.api.nvim_get_current_tabpage() == code_tab)
assert(#vim.fn.win_findbuf(code_buffer) == 1)
exit(code_buffer)
assert(vim.api.nvim_buf_is_valid(config_buffer), "exit removed another repo instance")
assert(open() ~= code_buffer and starts == 3, "exit/reopen did not start a fresh job")
exit(vim.api.nvim_get_current_buf())
vim.api.nvim_set_current_tabpage(config_tab)
assert(open() == config_buffer and starts == 3)
exit(config_buffer)
assert(vim.api.nvim_tabpage_is_valid(nested_tab))
print("lazygit repository tests passed")
vim.cmd("qa!")

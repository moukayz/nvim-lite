local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

local config_dir = vim.fn.stdpath("config")
local config_init = vim.fs.joinpath(config_dir, "init.lua")
local starts = 0
vim.opt.swapfile = false

vim.fn.jobstart = function(command, options)
  starts = starts + 1
  assert(vim.deep_equal(command, { "codex", "resume", "--last" }), "unexpected Codex command")
  assert_equal(options.cwd, config_dir, "Codex cwd")
  assert_equal(options.term, true, "terminal job")
  return starts
end

local mapping = vim.fn.maparg("<leader>cc", "n", false, true)
mapping.callback()

local workspace_tab = vim.api.nvim_get_current_tabpage()
assert_equal(vim.api.nvim_tabpage_get_var(workspace_tab, "tabname"), "nvim-lite", "workspace tab name")
assert_equal(vim.fn.getcwd(-1, vim.api.nvim_tabpage_get_number(workspace_tab)), config_dir, "tab cwd")
assert_equal(#vim.api.nvim_tabpage_list_wins(workspace_tab), 2, "workspace window count")

local terminal_buffer
local terminal_col
local config_col
for _, win in ipairs(vim.api.nvim_tabpage_list_wins(workspace_tab)) do
  local buffer = vim.api.nvim_win_get_buf(win)
  local marker_ok, is_codex = pcall(vim.api.nvim_buf_get_var, buffer, "codex_config_buffer")
  if marker_ok and is_codex then
    terminal_buffer = buffer
    terminal_col = vim.api.nvim_win_get_position(win)[2]
  elseif vim.fs.normalize(vim.api.nvim_buf_get_name(buffer)) == vim.fs.normalize(config_init) then
    config_col = vim.api.nvim_win_get_position(win)[2]
  end
end
assert(terminal_buffer, "Codex terminal buffer was not created")
assert(terminal_col < config_col, "Codex terminal should be left of init.lua")

vim.cmd.source(vim.env.MYVIMRC)
mapping = vim.fn.maparg("<leader>cc", "n", false, true)
assert_equal(#vim.api.nvim_tabpage_list_wins(workspace_tab), 2, "reloaded workspace window count")
assert_equal(starts, 1, "reload terminal starts")

mapping.callback()
assert_equal(starts, 1, "singleton terminal starts")
assert_equal(vim.api.nvim_get_current_buf(), terminal_buffer, "singleton terminal focus")

local autocmd = vim.api.nvim_get_autocmds({ group = "CodexTerminal", event = "TermClose" })[1]
autocmd.callback({ buf = terminal_buffer })
assert(vim.wait(1000, function()
  return not vim.api.nvim_buf_is_valid(terminal_buffer)
end), "Codex terminal cleanup timed out")
assert(vim.api.nvim_tabpage_is_valid(workspace_tab), "workspace tab should remain after Codex exits")
assert_equal(#vim.api.nvim_tabpage_list_wins(workspace_tab), 1, "post-exit workspace window count")
assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(config_init), "post-exit config buffer")

mapping.callback()
assert_equal(starts, 2, "Codex restart count")
assert_equal(#vim.api.nvim_tabpage_list_wins(workspace_tab), 2, "reopened workspace window count")

print("nvim-lite Codex workspace: ok")
vim.cmd("qa!")

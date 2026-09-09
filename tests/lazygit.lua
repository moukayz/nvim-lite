local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

local starts = 0
local expected_command = { "lazygit" }
local real_system = vim.system
vim.system = function(argv, opts, callback)
  if argv[4] == "rev-parse" and #expected_command > 1 then
    return { wait = function() return { code = 0, stdout = "/test/yadm.git\n" } end }
  end
  return real_system(argv, opts, callback)
end
require("config.yadm").work_tree = function() return nil end
vim.fn.jobstart = function(command, options)
  starts = starts + 1
  assert(vim.deep_equal(command, expected_command), "unexpected Lazygit command: " .. vim.inspect(command))
  assert_equal(options.term, true, "terminal job")
  return starts
end

local mapping = vim.fn.maparg("<leader>gg", "n", false, true)
mapping.callback()

local lazygit_buffer = vim.api.nvim_get_current_buf()
assert_equal(vim.api.nvim_buf_get_var(lazygit_buffer, "lazygit_buffer"), true, "Lazygit buffer marker")
assert(vim.api.nvim_win_get_config(0).relative ~= "", "Lazygit should open in a floating window")

local hide = vim.fn.maparg("<C-g>", "n", false, true)
assert_equal(hide.desc, "Hide Lazygit", "Lazygit hide mapping")
hide.callback()
assert_equal(#vim.fn.win_findbuf(lazygit_buffer), 0, "hidden Lazygit window count")
assert(vim.api.nvim_buf_is_valid(lazygit_buffer), "hidden Lazygit buffer should remain valid")

vim.cmd.source(vim.env.MYVIMRC)
mapping = vim.fn.maparg("<leader>gg", "n", false, true)
mapping.callback()
assert_equal(starts, 1, "restored Lazygit starts")
assert_equal(vim.api.nvim_get_current_buf(), lazygit_buffer, "restored Lazygit buffer")
assert(vim.api.nvim_win_get_config(0).relative ~= "", "restored Lazygit window should float")

local autocmd = vim.api.nvim_get_autocmds({ group = "LazygitTerminal", event = "TermClose" })[1]
autocmd.callback({ buf = lazygit_buffer })
assert(vim.wait(1000, function()
  return not vim.api.nvim_buf_is_valid(lazygit_buffer)
end), "Lazygit terminal cleanup timed out")

-- A fresh yadm launch explicitly loads the user's config, while restore still
-- reuses the same process. No filesystem/config writes are needed for this test.
require("config.yadm").work_tree = function() return vim.env.HOME end
local original_readable = vim.fn.filereadable
local original_xdg = vim.env.XDG_CONFIG_HOME
vim.env.XDG_CONFIG_HOME = "/test/config with spaces"
expected_command = { "lazygit", "--use-config-file", "/test/config with spaces/lazygit/config.yml" }
vim.fn.filereadable = function(path)
  if path == expected_command[3] then return 1 end
  return original_readable(path)
end
mapping.callback()
local yadm_buffer = vim.api.nvim_get_current_buf()
assert_equal(starts, 2, "yadm starts")
vim.fn.maparg("<C-g>", "n", false, true).callback()
mapping.callback()
assert_equal(starts, 2, "yadm restore starts")
assert_equal(vim.api.nvim_get_current_buf(), yadm_buffer, "yadm restored buffer")
autocmd.callback({ buf = yadm_buffer })
assert(vim.wait(1000, function() return not vim.api.nvim_buf_is_valid(yadm_buffer) end))
vim.env.XDG_CONFIG_HOME = nil
expected_command[3] = vim.fs.joinpath(vim.env.HOME, ".config/lazygit/config.yml")
mapping.callback()
assert_equal(starts, 3, "home config fallback starts")
autocmd.callback({ buf = vim.api.nvim_get_current_buf() })
assert(vim.wait(1000, function() return #vim.api.nvim_list_wins() == 1 end))
vim.fn.filereadable = original_readable
vim.env.XDG_CONFIG_HOME = original_xdg

print("nvim-lite Lazygit: ok")
vim.cmd("qa!")

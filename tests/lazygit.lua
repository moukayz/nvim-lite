local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

local starts = 0
vim.fn.jobstart = function(command, options)
  starts = starts + 1
  assert(vim.deep_equal(command, { "lazygit" }), "unexpected Lazygit command")
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

print("nvim-lite Lazygit: ok")
vim.cmd("qa!")

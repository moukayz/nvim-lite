local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

-- A second load exercises the same path as <Space>rs.
vim.cmd.source(vim.env.MYVIMRC)

assert_equal(vim.g.mapleader, " ", "leader")
assert_equal(vim.o.number, true, "number")
assert_equal(vim.o.relativenumber, true, "relativenumber")
assert_equal(vim.fn.exists(":PackUpdate"), 2, "PackUpdate command")

local expected_mappings = {
  ["<leader>."] = "Open Neovim config",
  ["<leader>rs"] = "Source Neovim config",
  ["<leader>gg"] = "Lazygit",
  ["<leader>cc"] = "Codex in Neovim config",
  ["<leader>dd"] = "Open local changes",
  ["<leader>ee"] = "Toggle file tree",
  ["<leader>f"] = "Find files",
}
for lhs, description in pairs(expected_mappings) do
  assert_equal(vim.fn.maparg(lhs, "n", false, true).desc, description, lhs)
end

local expected_autocmd_counts = {
  TerminalUI = 2,
  tmux_navigation = 1,
  CodexTerminal = 1,
  LazygitTerminal = 1,
  NvimLiteTreesitter = 7,
  NvimLiteLsp = 1,
}
for group, count in pairs(expected_autocmd_counts) do
  assert_equal(#vim.api.nvim_get_autocmds({ group = group }), count, group)
end

print("nvim-lite smoke: ok")
vim.cmd("qa!")

local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

-- A second load exercises the same path as <Space>rs.
vim.cmd.source(vim.env.MYVIMRC)

assert_equal(vim.g.mapleader, " ", "leader")
assert_equal(vim.o.number, true, "number")
assert_equal(vim.o.relativenumber, true, "relativenumber")
assert_equal(vim.o.mouse, "", "mouse disabled")
assert_equal(vim.fn.exists(":PackUpdate"), 2, "PackUpdate command")
for _, command in ipairs({ "WorkspaceAdd", "WorkspaceRemove", "WorkspaceClear", "WorkspaceInfo" }) do
  assert_equal(vim.fn.exists(":" .. command), 2, command)
end
local workspace_paths = vim.tbl_filter(function(path)
  return path:match("/plugins/workspace%.nvim$") ~= nil
end, vim.opt.runtimepath:get())
assert_equal(#workspace_paths, 1, "workspace runtime path after reload")

local expected_mappings = {
  ["<leader>."] = "Open Neovim config",
  ["<leader>rs"] = "Source Neovim config",
  ["<leader>z"] = "Toggle window zoom",
  ["<leader>gg"] = "Lazygit",
  ["<leader>cc"] = "Open config workspace",
  ["<leader>dd"] = "Open local changes",
  ["<leader>ee"] = "Toggle file tree",
  ["<leader>ef"] = "Focus file tree",
  ["<leader>f"] = "Find files",
  ["<leader>w"] = "Switch windows across tabs",
}
for lhs, description in pairs(expected_mappings) do
  assert_equal(vim.fn.maparg(lhs, "n", false, true).desc, description, lhs)
end

local expected_autocmd_counts = {
  TerminalUI = 2,
  FileGutter = 1,
  tmux_navigation = 1,
  ConfigAgentTerminal = 1,
  LazygitTerminal = 1,
  NvimLiteStartup = 1,
  NvimLiteTreesitter = 7,
  NvimLiteLsp = 1,
}
for group, count in pairs(expected_autocmd_counts) do
  assert_equal(#vim.api.nvim_get_autocmds({ group = group }), count, group)
end

print("nvim-lite smoke: ok")
vim.cmd("qa!")

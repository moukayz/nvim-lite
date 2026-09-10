local markdown = require("render-markdown")
assert(vim.fn.exists(":RenderMarkdown") == 2)
for _, lang in ipairs({ "markdown", "markdown_inline" }) do
  assert(pcall(vim.treesitter.language.add, lang), lang .. " parser missing")
end
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "# Heading", "", "- [x] Completed", "", "```lua", "print('hello')", "```", "", "text",
})
vim.bo.filetype = "markdown"
vim.api.nvim_win_set_cursor(0, { 9, 0 })
markdown.enable()
local ns = vim.api.nvim_get_namespaces()["render-markdown.nvim"]
assert(ns)
assert(vim.wait(3000, function()
  return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0
end), "Markdown did not render")
local function autocmd_count()
  return #vim.tbl_filter(function(event)
    return (event.group_name or ""):find("[Rr]ender") ~= nil
  end, vim.api.nvim_get_autocmds({}))
end
local before = autocmd_count()
assert(before > 0)
vim.cmd.source(vim.env.MYVIMRC)
vim.cmd.source(vim.env.MYVIMRC)
assert(autocmd_count() == before, "reload accumulated Markdown autocmds")
assert(vim.fn.exists(":RenderMarkdown") == 2)
print("Markdown render/reload tests passed")
vim.cmd("qa!")

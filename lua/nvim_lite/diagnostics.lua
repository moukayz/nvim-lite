vim.diagnostic.config({
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "󰌵",
    },
  },
  virtual_text = {
    current_line = true,
    source = "if_many",
    spacing = 2,
    prefix = "●",
  },
  float = {
    border = "rounded",
    source = true,
    header = "",
    prefix = "",
  },
})

vim.keymap.set("n", "gl", function()
  vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Show line diagnostics" })

local function map_diagnostic_navigation(lhs, count, severity, description)
  vim.keymap.set("n", lhs, function()
    vim.diagnostic.jump({ count = count, severity = severity })
  end, { desc = description })
end

map_diagnostic_navigation("]w", 1, vim.diagnostic.severity.WARN, "Next warning")
map_diagnostic_navigation("[w", -1, vim.diagnostic.severity.WARN, "Previous warning")
map_diagnostic_navigation("]e", 1, vim.diagnostic.severity.ERROR, "Next error")
map_diagnostic_navigation("[e", -1, vim.diagnostic.severity.ERROR, "Previous error")
map_diagnostic_navigation("]i", 1, vim.diagnostic.severity.INFO, "Next info diagnostic")
map_diagnostic_navigation("[i", -1, vim.diagnostic.severity.INFO, "Previous info diagnostic")

vim.keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

vim.keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

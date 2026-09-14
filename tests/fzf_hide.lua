local fzf = require("fzf-lua")
local calls, opts, hidden, restores = 0, nil, false, 0
fzf.live_grep = function(o) calls = calls + 1; opts = o end
fzf.unhide = function()
  if hidden then hidden = false; restores = restores + 1; return true end
end
local function search() vim.fn.maparg("<leader>/", "n", false, true).callback() end
require("config.picker").setup()
local keys = require("fzf-lua.config").globals.keymap.builtin
assert(keys["<esc>"] == "hide" and keys["<c-c>"] == "abort")
for key, action in pairs({
  ["<a-v>"] = "toggle-preview", ["<a-r>"] = "toggle-preview-cw",
  ["<a-m>"] = "toggle-fullscreen", ["<a-w>"] = "toggle-preview-wrap",
}) do
  assert(keys[key] == action, "missing picker control: " .. key)
  assert(vim.fn.maparg(key, "n") == "" and vim.fn.maparg(key, "t") == "",
    "picker control leaked into global mappings: " .. key)
end
assert(keys["<f2>"] == "toggle-fullscreen", "existing F-key mapping lost")
search()
assert(calls == 1)
local buf = vim.api.nvim_create_buf(false, true)
opts.winopts.on_create({ bufnr = buf })
hidden = true
search()
assert(calls == 1 and restores == 1, "hidden grep was restarted")
-- Another picker replaces the old terminal; never unhide that other picker.
vim.api.nvim_buf_delete(buf, { force = true })
hidden = true
search()
assert(calls == 2 and restores == 1, "unrelated picker was restored")
print("fzf hide routing tests passed")
vim.cmd("qa!")

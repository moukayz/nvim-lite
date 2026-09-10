-- Run after loading the full profile.
local picker = require("config.picker")
local fzf = require("fzf-lua")
local old_files, count = fzf.files, 0
fzf.files = function() count = count + 1 end
picker.setup({ find_files = function() return true end })
vim.fn.maparg("<leader>f", "n", false, true).callback()
assert(count == 0, "injected handler did not handle request")
picker.setup({ find_files = function() return false end })
vim.fn.maparg("<leader>f", "n", false, true).callback()
assert(count == 1, "normal fallback was skipped")
picker.setup()
vim.fn.maparg("<leader>f", "n", false, true).callback()
assert(count == 2, "setup did not clear old handler")
fzf.files = old_files
local old_grep, grep_count = fzf.live_grep, 0
fzf.live_grep = function() grep_count = grep_count + 1 end
picker.setup({ live_grep = function() return true end })
vim.fn.maparg("<leader>/", "n", false, true).callback()
assert(grep_count == 0)
picker.setup()
vim.fn.maparg("<leader>/", "n", false, true).callback()
assert(grep_count == 1, "ordinary grep fallback")
fzf.live_grep = old_grep
local utils = require("fzf-lua.utils")
local old_selection = utils.get_visual_selection
utils.get_visual_selection = function() return "literal.*[text]" end
local selection_opts
fzf.live_grep = function(opts) selection_opts = opts end
picker.setup()
vim.fn.maparg("<leader>/", "x", false, true).callback()
assert(selection_opts.search == "literal.*[text]" and selection_opts.no_esc == false)
assert(selection_opts.cwd == vim.fn.getcwd())
picker.setup({ live_grep = function(opts)
  assert(opts.search == "literal.*[text]" and opts.no_esc == false)
  return true
end })
vim.fn.maparg("<leader>/", "x", false, true).callback()
utils.get_visual_selection = old_selection
fzf.live_grep = old_grep
local resume_config = require("fzf-lua.config")
resume_config.resume_set("search", "previous.*query", { __resume_key = "profile_live_grep" })
local grep_opts
fzf.live_grep = function(opts) grep_opts = opts end
picker.setup()
vim.fn.maparg("<leader>/", "n", false, true).callback()
assert(grep_opts.search == "previous.*query" and grep_opts.cwd == vim.fn.getcwd())
picker.setup({ live_grep = function(opts)
  assert(opts.search == "previous.*query" and opts.no_esc)
  return true
end })
vim.fn.maparg("<leader>/", "n", false, true).callback()
fzf.live_grep = old_grep
for _, key in ipairs({ " f", " ee", " gg" }) do
  local matches = vim.tbl_filter(function(map) return map.lhs == key end, vim.api.nvim_get_keymap("n"))
  assert(#matches == 1, "mapping must have one owner: " .. key)
end
for _, name in ipairs({ "picker", "explorer", "lazygit" }) do
  local source = table.concat(vim.fn.readfile("lua/config/" .. name .. ".lua"), "\n")
  assert(not source:find("yadm", 1, true), "integration leaked into " .. name)
end
vim.cmd.source(vim.env.MYVIMRC)
assert(package.loaded["config.integrations"] == nil, "entrypoint should wire tools directly")
assert(vim.fn.filereadable("lua/config/integrations.lua") == 0, "redundant wiring module remains")
print("nvim-lite integrations: ok")
vim.cmd("qa!")

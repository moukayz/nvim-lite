local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

vim.cmd("vnew")
vim.cmd("vertical resize 25")
vim.cmd("split")
vim.cmd("resize 8")

local zoomed_window = vim.api.nvim_get_current_win()
local original_sizes = {}
for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
  original_sizes[win] = {
    width = vim.api.nvim_win_get_width(win),
    height = vim.api.nvim_win_get_height(win),
  }
end

local mapping = vim.fn.maparg("<leader>z", "n", false, true)
mapping.callback()
assert(vim.t.window_zoom_restore, "zoom restore command was not saved")
local zoomed_width = vim.api.nvim_win_get_width(zoomed_window)
local zoomed_height = vim.api.nvim_win_get_height(zoomed_window)
local narrower_window = false
local shorter_window = false
for win in pairs(original_sizes) do
  if win ~= zoomed_window then
    narrower_window = narrower_window or vim.api.nvim_win_get_width(win) < zoomed_width
    shorter_window = shorter_window or vim.api.nvim_win_get_height(win) < zoomed_height
  end
end
assert(narrower_window, "focused window width was not maximized")
assert(shorter_window, "focused window height was not maximized")

vim.cmd.source(vim.env.MYVIMRC)
mapping = vim.fn.maparg("<leader>z", "n", false, true)
mapping.callback()
assert_equal(vim.t.window_zoom_restore, nil, "zoom restore command")
for win, size in pairs(original_sizes) do
  assert_equal(vim.api.nvim_win_get_width(win), size.width, "restored window width")
  assert_equal(vim.api.nvim_win_get_height(win), size.height, "restored window height")
end

print("nvim-lite window zoom: ok")
vim.cmd("qa!")

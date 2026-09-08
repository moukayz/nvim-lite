local function assert_equal(actual, expected, label)
  assert(actual == expected, string.format("%s: expected %s, got %s", label, vim.inspect(expected), vim.inspect(actual)))
end

vim.opt.swapfile = false
local config_dir = vim.fn.stdpath("config")
local init_path = vim.fs.joinpath(config_dir, "init.lua")
local ui_path = vim.fs.joinpath(config_dir, "lua", "config", "ui.lua")
local outside_path = vim.fs.joinpath(vim.fs.dirname(config_dir), "outside.lua")

require("config.startup").show(config_dir, { ui_path, outside_path, init_path, ui_path })

local startup_buffer = vim.api.nvim_get_current_buf()
assert_equal(vim.bo.filetype, "nvim-lite-start", "start page filetype")
assert_equal(vim.fn.getcwd(), config_dir, "start page cwd")
assert_equal(vim.wo.number, false, "start page number")
assert_equal(vim.wo.relativenumber, false, "start page relative number")
assert_equal(vim.wo.signcolumn, "no", "start page sign column")

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local ui_line
local init_line
local title_found = false
for line, text in ipairs(lines) do
  title_found = title_found or text:find("NVIM LITE", 1, true) ~= nil
  ui_line = ui_line or (text:find("lua/config/ui.lua", 1, true) and line)
  init_line = init_line or (text:find("init.lua", 1, true) and line)
end
assert(title_found, "start page title missing")
assert(ui_line, "first MRU file missing")
assert(init_line, "second MRU file missing")
assert(ui_line < init_line, "MRU file order changed")
assert_equal(vim.api.nvim_win_get_cursor(0)[1], ui_line, "initial MRU selection")

local open_second = vim.fn.maparg("2", "n", false, true)
assert_equal(open_second.desc, "Open recent file 2", "numbered recent file mapping")
open_second.callback()
assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(init_path), "opened recent file")
assert_equal(vim.wo.number, true, "opened file number")
assert_equal(vim.wo.relativenumber, true, "opened file relative number")
assert_equal(vim.wo.signcolumn, "yes", "opened file sign column")

local previous_jump = vim.api.nvim_replace_termcodes("<C-o>", true, false, true)
vim.api.nvim_cmd({ cmd = "normal", args = { previous_jump }, bang = true }, {})
assert_equal(vim.api.nvim_get_current_buf(), startup_buffer, "startup jump buffer")
assert_equal(vim.bo.filetype, "nvim-lite-start", "startup jump filetype")
assert_equal(vim.wo.number, false, "returned start page number")
assert_equal(vim.wo.relativenumber, false, "returned start page relative number")
assert_equal(vim.wo.signcolumn, "no", "returned start page sign column")

vim.api.nvim_win_set_cursor(0, { init_line, 0 })
local open = vim.fn.maparg("<CR>", "n", false, true)
assert_equal(open.desc, "Open recent file", "recent file mapping")
open.callback()
assert_equal(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(init_path), "opened cursor file")
assert_equal(vim.wo.number, true, "cursor-opened file number")
assert_equal(vim.wo.relativenumber, true, "cursor-opened file relative number")
assert_equal(vim.wo.signcolumn, "yes", "cursor-opened file sign column")

print("nvim-lite startup page: ok")
vim.cmd("qa!")

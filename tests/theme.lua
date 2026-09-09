local function check_theme(name)
  vim.cmd.colorscheme(name)
  local function hl(group)
    return vim.api.nvim_get_hl(0, { name = group, link = false })
  end
  local function hex(value)
    return value and string.format("#%06x", value)
  end
  assert(hl("WinBar").bg == hl("Visual").bg, name .. ": winbar background")
  assert(hl("WinSeparator").fg == hl("Directory").fg, name .. ": separator")
  assert(hl("DiffviewStatusModified").fg == hl("Directory").fg, name .. ": diff status")
  assert(hl("DiffviewStatusModified").bg == nil, name .. ": diff status background")
  local config = require("lualine").get_config()
  if vim.g.colors_name == "rose-pine" then
    assert(config.options.theme.normal.c.bg == require("rose-pine.palette").overlay)
    assert(hl("lualine_c_normal").bg == tonumber(require("rose-pine.palette").overlay:sub(2), 16))
  else
    assert(config.options.theme == "auto")
  end
  local active_tab = config.tabline.lualine_a[1].tabs_color.active()
  assert(active_tab.bg == hex(hl("lualine_a_normal").bg))
  assert(active_tab.fg == hex(hl("lualine_a_normal").fg))
  assert(active_tab.gui == "bold")
  local get_mode = vim.api.nvim_get_mode
  vim.api.nvim_get_mode = function() return { mode = "t" } end
  assert(config.sections.lualine_a[1].color().bg == hex(hl("DiagnosticInfo").fg))
  vim.api.nvim_get_mode = get_mode
  assert(hl("lualine_a_mode_terminal").bg, name .. ": terminal mode highlight")
  assert(config.winbar.lualine_c[1].color == "WinBar")
  vim.bo.modified = true
  local modified = config.sections.lualine_a[1].color()
  assert(modified.bg == hex(hl("DiagnosticWarn").fg))
  assert(modified.fg == hex(hl("Normal").bg))
  vim.bo.modified = false
end

for _ = 1, 2 do
  dofile("init.lua")
  assert(#vim.api.nvim_get_autocmds({ group = "ConfigTheme", event = "ColorScheme" }) == 2)
  for _, name in ipairs({
    "tokyonight-day", "tokyonight-night", "tokyonight-moon",
    "catppuccin-latte", "rose-pine-dawn", "rose-pine-main", "github_light",
  }) do
    check_theme(name)
  end
  vim.o.background = "light"
  check_theme("default")
  vim.o.background = "dark"
end
print("theme tests passed")
vim.cmd("qa!")

require("tokyonight").setup({
  style = "moon",
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
  },
})
local theme_group = vim.api.nvim_create_augroup("ConfigTheme", { clear = true })
vim.cmd.colorscheme("rose-pine-main")

vim.opt.fillchars:append({ diff = " " })
require("diffview").setup({ enhanced_diff_hl = true })

local function apply_highlights()
  local function hl(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false })
  end
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = hl("Directory").fg, bold = true })
  vim.api.nvim_set_hl(0, "WinBar", {
    fg = hl("Directory").fg, bg = hl("Visual").bg, bold = true,
  })
  vim.api.nvim_set_hl(0, "WinBarNC", { fg = hl("Comment").fg, bg = hl("Normal").bg })
  -- Copy foreground only: keep Diffview status icons free of background blocks.
  for group, source in pairs({
    DiffviewFilePanelInsertions = "DiagnosticOk",
    DiffviewFilePanelDeletions = "DiagnosticError",
    DiffviewStatusAdded = "DiagnosticOk",
    DiffviewStatusUntracked = "DiagnosticOk",
    DiffviewStatusModified = "Directory",
    DiffviewStatusRenamed = "Directory",
    DiffviewStatusCopied = "Directory",
    DiffviewStatusTypeChanged = "Directory",
    DiffviewStatusUnmerged = "DiagnosticWarn",
    DiffviewStatusUnknown = "DiagnosticError",
    DiffviewStatusDeleted = "DiagnosticError",
    DiffviewStatusBroken = "DiagnosticError",
  }) do
    vim.api.nvim_set_hl(0, group, { fg = hl(source).fg })
  end
end
vim.api.nvim_create_autocmd("ColorScheme", { group = theme_group, callback = apply_highlights })
apply_highlights()

vim.opt.laststatus = 3

local function preserve_content_tab_name(name, context)
  local buffers = vim.fn.tabpagebuflist(context.tabnr)
  local window_number = vim.fn.tabpagewinnr(context.tabnr)
  local buffer = buffers[window_number]

  if buffer and vim.bo[buffer].filetype ~= "neo-tree" then
    pcall(vim.api.nvim_tabpage_set_var, context.tabId, "content_name", name)
    return name
  end

  local ok, content_name = pcall(vim.api.nvim_tabpage_get_var, context.tabId, "content_name")
  return ok and content_name or name
end

local function format_winbar_filename(name)
  if vim.b.codex_config_buffer then
    return "Codex"
  end
  if vim.b.lazygit_buffer then
    return "Lazygit"
  end
  return name
end

local function terminal_colors()
  local info = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  return {
    bg = info.fg and string.format("#%06x", info.fg),
    fg = normal.bg and string.format("#%06x", normal.bg)
      or (vim.o.background == "light" and "#ffffff" or "#000000"),
    gui = "bold",
  }
end

local function winbar_filename(active)
  return {
    "filename",
    path = 1,
    shorting_target = 20,
    color = active and "WinBar" or "WinBarNC",
    symbols = {
      modified = " ●",
      readonly = " [RO]",
      unnamed = "[No Name]",
      newfile = "[New]",
    },
    fmt = format_winbar_filename,
  }
end

require("lualine").setup({
  options = {
    theme = "auto",
    icons_enabled = false,
    globalstatus = true,
    always_show_tabline = false,
    disabled_filetypes = {
      winbar = { "nvim-lite-start" },
    },
    component_separators = { left = "│", right = "│" },
    section_separators = { left = "", right = "" },
  },
  sections = {
    lualine_a = {
      {
        "mode",
        color = function()
          if vim.api.nvim_get_mode().mode == "t" then
            return terminal_colors()
          end
          if vim.bo.modified and vim.api.nvim_get_mode().mode:match("^n") then
            local warn = vim.api.nvim_get_hl(0, { name = "DiagnosticWarn", link = false })
            local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
            return {
              bg = warn.fg and string.format("#%06x", warn.fg),
              fg = normal.bg and string.format("#%06x", normal.bg)
                or (vim.o.background == "light" and "#ffffff" or "#000000"),
            }
          end
        end,
      },
    },
    lualine_b = { "branch" },
    lualine_c = {
      { "filename", path = 1, shorting_target = 40 },
    },
    lualine_x = { "diagnostics", "lsp_status" },
    lualine_y = { "filetype", "progress" },
    lualine_z = { "location" },
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      { "filename", path = 1 },
    },
    lualine_x = { "location" },
    lualine_y = {},
    lualine_z = {},
  },
  tabline = {
    lualine_a = {
      {
        "tabs",
        mode = 2,
        path = 0,
        tab_max_length = 28,
        max_length = function()
          return vim.o.columns
        end,
        use_mode_colors = false,
        tabs_color = {
          active = function()
            local hl = vim.api.nvim_get_hl(0, { name = "lualine_a_normal", link = false })
            return {
              fg = hl.fg and string.format("#%06x", hl.fg),
              bg = hl.bg and string.format("#%06x", hl.bg),
              gui = "bold",
            }
          end,
          inactive = "TabLine",
        },
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        show_modified_status = true,
        symbols = { modified = " ●" },
        fmt = preserve_content_tab_name,
      },
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  winbar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { winbar_filename(true) },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  inactive_winbar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { winbar_filename(false) },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  extensions = { "quickfix", "neo-tree" },
})

local function brighten_statusline()
  local config = require("lualine").get_config()
  config.options.theme = "auto"
  if vim.g.colors_name == "rose-pine" then
    local theme = require("lualine.utils.loader").load_theme("auto")
    for _, mode in pairs(theme) do
      if mode.c then mode.c.bg = require("rose-pine.palette").overlay end
    end
    config.options.theme = theme
  end
  require("lualine").setup(config)
end
vim.api.nvim_create_autocmd("ColorScheme", { group = theme_group, callback = brighten_statusline })
brighten_statusline()

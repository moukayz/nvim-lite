require("tokyonight").setup({
  style = "moon",
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
  },
  on_highlights = function(highlights, colors)
    highlights.WinSeparator = { fg = colors.blue, bold = true }
  end,
})
vim.cmd.colorscheme("tokyonight")

vim.opt.fillchars:append({ diff = " " })
require("diffview").setup({
  enhanced_diff_hl = true,
})

vim.opt.laststatus = 3
local colors = require("tokyonight.colors").setup({ style = "moon" })
require("lualine").setup({
  options = {
    theme = "tokyonight",
    icons_enabled = false,
    globalstatus = true,
    always_show_tabline = false,
    component_separators = { left = "│", right = "│" },
    section_separators = { left = "", right = "" },
  },
  sections = {
    lualine_a = {
      {
        "mode",
        color = function()
          if vim.bo.modified and vim.api.nvim_get_mode().mode:match("^n") then
            return { bg = colors.yellow, fg = colors.black }
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
          active = {
            fg = colors.blue,
            bg = colors.bg_highlight,
            gui = "bold",
          },
          inactive = {
            fg = colors.comment,
            bg = colors.bg_statusline,
          },
        },
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        show_modified_status = true,
        symbols = { modified = " ●" },
      },
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  },
  extensions = { "quickfix", "neo-tree" },
})

require("tokyonight").setup({
  style = "moon",
  terminal_colors = true,
  styles = {
    comments = { italic = true },
    keywords = { italic = true },
  },
  on_highlights = function(highlights, colors)
    highlights.WinSeparator = { fg = colors.blue, bold = true }
    highlights.WinBar = { fg = colors.blue, bg = colors.bg_highlight, bold = true }
    highlights.WinBarNC = { fg = colors.comment, bg = colors.bg_dark }
  end,
})
vim.cmd.colorscheme("tokyonight")

local colors = require("tokyonight.colors").setup({ style = "moon" })
vim.opt.fillchars:append({ diff = " " })
require("diffview").setup({
  enhanced_diff_hl = true,
})
local diffview_panel_colors = {
  DiffviewFilePanelInsertions = colors.green,
  DiffviewFilePanelDeletions = colors.red,
  DiffviewStatusAdded = colors.green,
  DiffviewStatusUntracked = colors.green,
  DiffviewStatusModified = colors.blue,
  DiffviewStatusRenamed = colors.blue,
  DiffviewStatusCopied = colors.blue,
  DiffviewStatusTypeChanged = colors.blue,
  DiffviewStatusUnmerged = colors.yellow,
  DiffviewStatusUnknown = colors.red,
  DiffviewStatusDeleted = colors.red,
  DiffviewStatusBroken = colors.red,
}
for group, foreground in pairs(diffview_panel_colors) do
  vim.api.nvim_set_hl(0, group, { fg = foreground })
end

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

local function winbar_filename(active)
  return {
    "filename",
    path = 1,
    shorting_target = 20,
    color = active and { fg = colors.blue, bg = colors.bg_highlight, gui = "bold" }
      or { fg = colors.comment, bg = colors.bg_dark },
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
    theme = "tokyonight",
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

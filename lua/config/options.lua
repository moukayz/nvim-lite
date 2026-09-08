vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt_global.number = true
vim.opt_global.relativenumber = true

local function hide_number_column()
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
end

local function configure_window_gutter()
  if vim.bo.buftype == "terminal" or vim.bo.filetype == "nvim-lite-start" then
    hide_number_column()
  elseif vim.bo.buftype == "" then
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
    vim.opt_local.signcolumn = "yes"
  end
end

local terminal_ui_group = vim.api.nvim_create_augroup("TerminalUI", { clear = true })
vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter" }, {
  group = terminal_ui_group,
  pattern = "term://*",
  callback = hide_number_column,
})

local file_gutter_group = vim.api.nvim_create_augroup("FileGutter", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = file_gutter_group,
  callback = configure_window_gutter,
})

-- Apply the policy immediately when the config is re-sourced.
configure_window_gutter()

vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.undofile = true
vim.opt.termguicolors = true
vim.opt.fillchars:append({
  horiz = "━",
  horizdown = "┳",
  horizup = "┻",
  vert = "┃",
  verthoriz = "╋",
  vertleft = "┫",
  vertright = "┣",
})
vim.opt.autocomplete = true
vim.opt.autocompletedelay = 120
vim.opt.complete = { "o^20", ".^10", "w^5", "b^5", "u^5" }
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy", "nearest" }

vim.opt.grepprg = "rg --vimgrep --smart-case --hidden --glob=!.git"
vim.opt.grepformat = "%f:%l:%c:%m"

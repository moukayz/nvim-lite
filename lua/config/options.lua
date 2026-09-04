vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt_global.number = true
vim.opt_global.relativenumber = true

local function hide_terminal_gutter()
  vim.opt_local.number = false
  vim.opt_local.relativenumber = false
end

local terminal_ui_group = vim.api.nvim_create_augroup("TerminalUI", { clear = true })
vim.api.nvim_create_autocmd({ "TermOpen", "BufWinEnter" }, {
  group = terminal_ui_group,
  pattern = "term://*",
  callback = hide_terminal_gutter,
})

-- Keep re-sourcing from changing the current terminal window's UI.
if vim.bo.buftype == "terminal" then
  hide_terminal_gutter()
elseif vim.bo.buftype == "" then
  vim.opt_local.number = true
  vim.opt_local.relativenumber = true
end

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

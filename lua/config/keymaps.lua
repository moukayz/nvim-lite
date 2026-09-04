vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true, silent = true, desc = "Next completion item or tab" })

vim.keymap.set("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true, silent = true, desc = "Previous completion item or shift-tab" })

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
vim.keymap.set("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix item" })
vim.keymap.set("n", "[q", "<cmd>cprevious<cr>", { desc = "Previous quickfix item" })
vim.keymap.set("n", "<leader>q", "<cmd>copen<cr>", { desc = "Open quickfix list" })
vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<cr>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<cr>", { desc = "Close other tabs" })
vim.keymap.set("n", "<leader>.", function()
  local config_dir = vim.fn.stdpath("config")
  vim.api.nvim_cmd({ cmd = "tabnew", args = { vim.fs.joinpath(config_dir, "init.lua") } }, {})
  vim.api.nvim_cmd({ cmd = "tcd", args = { config_dir } }, {})
end, { desc = "Open Neovim config" })
vim.keymap.set("n", "<A-h>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<A-l>", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("t", "<A-h>", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set("t", "<A-l>", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>rr", "<cmd>restart<cr>", { desc = "Restart Neovim" })
vim.keymap.set("n", "<leader>rs", function()
  local config_path = vim.env.MYVIMRC or (vim.fn.stdpath("config") .. "/init.lua")
  local ok, error_message = pcall(vim.api.nvim_cmd, {
    cmd = "source",
    args = { config_path },
  }, {})
  if ok then
    vim.notify("Neovim config reloaded", vim.log.levels.INFO)
  else
    vim.notify("Neovim config reload failed:\n" .. error_message, vim.log.levels.ERROR)
  end
end, { desc = "Source Neovim config" })
vim.keymap.set("n", "<A-t>", function()
  vim.cmd("belowright split")
  vim.cmd("terminal")
  vim.cmd("startinsert")
end, { desc = "Open terminal below" })
vim.keymap.set("t", "<C-g>", [[<C-\><C-n>]], { desc = "Leave terminal mode" })

-- Navigate Neovim windows first, then cross a Neovim edge into tmux without
-- starting 'shell'. This keeps pane switches fast even with expensive shells.
local tmux_socket = vim.env.TMUX and vim.env.TMUX:match("^([^,]+)")
local tmux_pane = vim.env.TMUX_PANE
local last_navigation_used_tmux = false

local function select_tmux_pane(direction)
  if not tmux_socket or not tmux_pane then
    return false
  end

  vim.system({
    "tmux",
    "-S",
    tmux_socket,
    "select-pane",
    "-t",
    tmux_pane,
    "-" .. direction,
  }, { text = true }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        local message = vim.trim(result.stderr or "")
        vim.notify(message ~= "" and message or "tmux pane navigation failed", vim.log.levels.ERROR)
      end)
    end
  end)
  return true
end

local pane_directions = {
  ["<C-h>"] = { window = "h", tmux = "L", name = "left", byte = 8 },
  ["<C-j>"] = { window = "j", tmux = "D", name = "down", byte = 10 },
  ["<C-k>"] = { window = "k", tmux = "U", name = "up", byte = 11 },
  ["<C-l>"] = { window = "l", tmux = "R", name = "right", byte = 12 },
}

local function navigate_pane(direction)
  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. direction.window)
  if vim.api.nvim_get_current_win() ~= previous_window then
    last_navigation_used_tmux = false
    return
  end

  last_navigation_used_tmux = select_tmux_pane(direction.tmux)
end

for lhs, direction in pairs(pane_directions) do
  vim.keymap.set("n", lhs, function()
    navigate_pane(direction)
  end, { silent = true, desc = "Navigate " .. direction.name .. " across panes" })

  vim.keymap.set("t", lhs, function()
    if vim.bo.filetype == "fzf" then
      vim.api.nvim_chan_send(vim.b.terminal_job_id, string.char(direction.byte))
      return
    end
    vim.cmd.stopinsert()
    navigate_pane(direction)
  end, { silent = true, desc = "Navigate " .. direction.name .. " across panes" })
end

vim.keymap.set("n", "<C-\\>", function()
  if last_navigation_used_tmux then
    select_tmux_pane("l")
    return
  end

  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd("wincmd p")
  if vim.api.nvim_get_current_win() == previous_window then
    last_navigation_used_tmux = select_tmux_pane("l")
  end
end, { silent = true, desc = "Navigate to previous pane" })

local tmux_navigation_group = vim.api.nvim_create_augroup("tmux_navigation", { clear = true })
vim.api.nvim_create_autocmd("WinEnter", {
  group = tmux_navigation_group,
  callback = function()
    last_navigation_used_tmux = false
  end,
  desc = "Reset previous tmux pane navigation",
})

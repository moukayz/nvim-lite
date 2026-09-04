local function find_marked_buffer(marker)
  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    local marker_ok, is_marked = pcall(vim.api.nvim_buf_get_var, buffer, marker)
    if marker_ok and is_marked then
      return buffer
    end
  end
end

local function open_lazygit_float(buffer)
  local available_lines = vim.o.lines - vim.o.cmdheight
  local width = math.max(1, math.min(vim.o.columns - 4, math.floor(vim.o.columns * 0.9)))
  local height = math.max(1, math.min(available_lines - 4, math.floor(available_lines * 0.9)))

  return vim.api.nvim_open_win(buffer, true, {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    title = " Lazygit ",
    title_pos = "center",
    width = width,
    height = height,
    row = math.floor((available_lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  })
end

local function configure_lazygit_buffer(buffer)
  vim.keymap.set({ "n", "t" }, "<C-g>", function()
    for _, win in ipairs(vim.fn.win_findbuf(buffer)) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_config(win).relative ~= "" then
        vim.api.nvim_win_close(win, true)
      end
    end
  end, { buffer = buffer, silent = true, desc = "Hide Lazygit" })
end

local lazygit_terminal_group = vim.api.nvim_create_augroup("LazygitTerminal", { clear = true })
vim.api.nvim_create_autocmd("TermClose", {
  group = lazygit_terminal_group,
  callback = function(event)
    local marker_ok, is_lazygit_buffer = pcall(vim.api.nvim_buf_get_var, event.buf, "lazygit_buffer")
    if not marker_ok or not is_lazygit_buffer then
      return
    end

    vim.schedule(function()
      for _, win in ipairs(vim.fn.win_findbuf(event.buf)) do
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.api.nvim_buf_delete(event.buf, { force = true })
      end
    end)
  end,
})

local existing_lazygit_buffer = find_marked_buffer("lazygit_buffer")
if existing_lazygit_buffer then
  configure_lazygit_buffer(existing_lazygit_buffer)
end

vim.keymap.set("n", "<leader>gg", function()
  local buffer = find_marked_buffer("lazygit_buffer")
  if buffer then
    local win = vim.fn.win_findbuf(buffer)[1]
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_set_current_tabpage(vim.api.nvim_win_get_tabpage(win))
      vim.api.nvim_set_current_win(win)
    else
      open_lazygit_float(buffer)
    end
    vim.cmd("startinsert")
    return
  end

  buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_var(buffer, "lazygit_buffer", true)
  configure_lazygit_buffer(buffer)
  open_lazygit_float(buffer)
  local job = vim.fn.jobstart({ "lazygit" }, { term = true })
  if job <= 0 then
    vim.api.nvim_buf_delete(buffer, { force = true })
    vim.notify("Could not start Lazygit", vim.log.levels.ERROR)
    return
  end
  vim.cmd("startinsert")
end, { desc = "Lazygit" })

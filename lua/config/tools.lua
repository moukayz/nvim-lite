local config_dir = vim.fn.stdpath("config")
local config_init = vim.fs.joinpath(config_dir, "init.lua")

local function in_tab(tab, callback)
  local original_tab = vim.api.nvim_get_current_tabpage()
  local original_win = vim.api.nvim_get_current_win()
  if original_tab ~= tab then
    vim.api.nvim_set_current_tabpage(tab)
  end

  local ok, result = pcall(callback)
  if vim.api.nvim_tabpage_is_valid(original_tab) then
    vim.api.nvim_set_current_tabpage(original_tab)
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
  end
  if not ok then
    error(result)
  end
  return result
end

local function get_marked_window(tab, buffer_marker)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    local buffer = vim.api.nvim_win_get_buf(win)
    local buffer_ok, is_marked = pcall(vim.api.nvim_buf_get_var, buffer, buffer_marker)
    if buffer_ok and is_marked then
      return win
    end
  end
end

local function find_marked_tab(tab_marker, buffer_marker)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local tab_ok, is_tool_tab = pcall(vim.api.nvim_tabpage_get_var, tab, tab_marker)
    if tab_ok and is_tool_tab then
      return tab, buffer_marker and get_marked_window(tab, buffer_marker) or nil
    end
  end
end

local function configure_codex_tab(tab)
  vim.api.nvim_tabpage_set_var(tab, "codex_config_tab", true)
  vim.api.nvim_tabpage_set_var(tab, "tabname", "nvim-lite")
  in_tab(tab, function()
    vim.api.nvim_cmd({ cmd = "tcd", args = { config_dir } }, {})
  end)
end

local function find_config_window(tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    local buffer = vim.api.nvim_win_get_buf(win)
    if vim.fs.normalize(vim.api.nvim_buf_get_name(buffer)) == vim.fs.normalize(config_init) then
      return win
    end
  end
end

local function ensure_config_window(tab, terminal_win)
  local config_win = find_config_window(tab)
  if config_win then
    return config_win
  end

  in_tab(tab, function()
    local reference_win = terminal_win or vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(reference_win) then
      vim.api.nvim_set_current_win(reference_win)
    end
    vim.cmd("rightbelow vsplit " .. vim.fn.fnameescape(config_init))
    config_win = vim.api.nvim_get_current_win()
  end)
  return config_win
end

local function focus_codex_terminal(tab, win)
  vim.api.nvim_set_current_tabpage(tab)
  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert")
end

local function start_codex_terminal(tab)
  configure_codex_tab(tab)
  local config_win = ensure_config_window(tab)
  vim.api.nvim_set_current_tabpage(tab)
  vim.api.nvim_set_current_win(config_win)
  vim.cmd("leftabove vnew")

  local terminal_win = vim.api.nvim_get_current_win()
  local terminal_buffer = vim.api.nvim_get_current_buf()
  local job = vim.fn.jobstart({ "codex", "resume", "--last" }, {
    term = true,
    cwd = config_dir,
  })
  if job <= 0 then
    vim.api.nvim_win_close(terminal_win, true)
    if vim.api.nvim_buf_is_valid(terminal_buffer) then
      vim.api.nvim_buf_delete(terminal_buffer, { force = true })
    end
    vim.notify("Could not start Codex CLI", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_var(terminal_buffer, "codex_config_buffer", true)
  focus_codex_terminal(tab, terminal_win)
end

local codex_terminal_group = vim.api.nvim_create_augroup("CodexTerminal", { clear = true })
vim.api.nvim_create_autocmd("TermClose", {
  group = codex_terminal_group,
  callback = function(event)
    local marker_ok, is_codex_buffer = pcall(vim.api.nvim_buf_get_var, event.buf, "codex_config_buffer")
    if not marker_ok or not is_codex_buffer then
      return
    end

    vim.schedule(function()
      local tab = find_marked_tab("codex_config_tab")
      if tab and vim.api.nvim_tabpage_is_valid(tab) then
        configure_codex_tab(tab)
        ensure_config_window(tab, get_marked_window(tab, "codex_config_buffer"))
      end
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

local existing_codex_tab, existing_codex_win = find_marked_tab("codex_config_tab", "codex_config_buffer")
if existing_codex_tab then
  configure_codex_tab(existing_codex_tab)
  ensure_config_window(existing_codex_tab, existing_codex_win)
end

local stale_codex_buffer = vim.fn.bufnr("Codex: nvim-lite")
if stale_codex_buffer >= 0 and #vim.fn.win_findbuf(stale_codex_buffer) == 0 then
  vim.api.nvim_buf_delete(stale_codex_buffer, { force = true })
end

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

vim.keymap.set("n", "<leader>cc", function()
  local tab, win = find_marked_tab("codex_config_tab", "codex_config_buffer")
  if tab then
    configure_codex_tab(tab)
    ensure_config_window(tab, win)
    if win then
      focus_codex_terminal(tab, win)
    else
      start_codex_terminal(tab)
    end
    return
  end

  vim.api.nvim_cmd({ cmd = "tabnew", args = { config_init } }, {})
  tab = vim.api.nvim_get_current_tabpage()
  start_codex_terminal(tab)
end, { desc = "Codex in Neovim config" })

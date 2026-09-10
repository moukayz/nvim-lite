local config_dir = vim.fn.stdpath("config")
local config_init = vim.fs.joinpath(config_dir, "init.lua")
local default_command = { "codex", "-c", "tui.notifications=false", "resume", "--last" }

-- Migrate existing sessions from the former Codex-specific identity on reload.
pcall(vim.api.nvim_del_augroup_by_name, "CodexTerminal")
pcall(vim.api.nvim_del_augroup_by_name, "AgentTerminal")
for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
  if vim.t[tab].codex_config_tab or vim.t[tab].agent_config_tab then
    vim.t[tab].config_workspace_tab, vim.t[tab].codex_config_tab = true, nil
    vim.t[tab].agent_config_tab = nil
  end
end
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.b[buf].codex_config_buffer or vim.b[buf].agent_config_buffer then
    vim.b[buf].config_agent_buffer, vim.b[buf].codex_config_buffer = true, nil
    vim.b[buf].agent_config_buffer = nil
  end
  if vim.b[buf].config_agent_buffer then vim.bo[buf].bufhidden = "wipe" end
end

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

local function configure_config_tab(tab)
  vim.api.nvim_tabpage_set_var(tab, "config_workspace_tab", true)
  vim.api.nvim_tabpage_set_var(tab, "tabname", "Nvim Config")
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

local function focus_agent_terminal(tab, win)
  vim.api.nvim_set_current_tabpage(tab)
  vim.api.nvim_set_current_win(win)
  vim.cmd("startinsert")
end

local function start_agent_terminal(tab)
  configure_config_tab(tab)
  local config_win = ensure_config_window(tab)
  vim.api.nvim_set_current_tabpage(tab)
  vim.api.nvim_set_current_win(config_win)
  vim.cmd("leftabove vnew")

  local terminal_win = vim.api.nvim_get_current_win()
  local terminal_buffer = vim.api.nvim_get_current_buf()
  -- Disable terminal notifications here; the external desktop hook is unchanged.
  local job = vim.fn.jobstart(vim.g.agent_command or default_command, {
    term = true,
    cwd = config_dir,
  })
  if job <= 0 then
    vim.api.nvim_win_close(terminal_win, true)
    if vim.api.nvim_buf_is_valid(terminal_buffer) then
      vim.api.nvim_buf_delete(terminal_buffer, { force = true })
    end
    vim.notify("Could not start Agent CLI", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_buf_set_var(terminal_buffer, "config_agent_buffer", true)
  -- Wiping a terminal buffer also stops its job when its last window closes.
  vim.bo[terminal_buffer].bufhidden = "wipe"
  focus_agent_terminal(tab, terminal_win)
end

local agent_terminal_group = vim.api.nvim_create_augroup("ConfigAgentTerminal", { clear = true })
vim.api.nvim_create_autocmd("TermClose", {
  group = agent_terminal_group,
  callback = function(event)
    local marker_ok, is_agent_buffer = pcall(vim.api.nvim_buf_get_var, event.buf, "config_agent_buffer")
    if not marker_ok or not is_agent_buffer then
      return
    end

    vim.schedule(function()
      local tab = find_marked_tab("config_workspace_tab")
      if tab and vim.api.nvim_tabpage_is_valid(tab) then
        configure_config_tab(tab)
        ensure_config_window(tab, get_marked_window(tab, "config_agent_buffer"))
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

local existing_agent_tab, existing_agent_win = find_marked_tab("config_workspace_tab", "config_agent_buffer")
if existing_agent_tab then
  configure_config_tab(existing_agent_tab)
  ensure_config_window(existing_agent_tab, existing_agent_win)
end

local stale_agent_buffer = vim.fn.bufnr("Codex: nvim-lite")
if stale_agent_buffer >= 0 and #vim.fn.win_findbuf(stale_agent_buffer) == 0 then
  vim.api.nvim_buf_delete(stale_agent_buffer, { force = true })
end

vim.keymap.set("n", "<leader>cc", function()
  local tab, win = find_marked_tab("config_workspace_tab", "config_agent_buffer")
  if tab then
    configure_config_tab(tab)
    ensure_config_window(tab, win)
    if win then
      focus_agent_terminal(tab, win)
    else
      start_agent_terminal(tab)
    end
    return
  end

  vim.api.nvim_cmd({ cmd = "tabnew", args = { config_init } }, {})
  tab = vim.api.nvim_get_current_tabpage()
  start_agent_terminal(tab)
end, { desc = "Open config workspace" })

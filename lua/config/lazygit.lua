local M = {}

function M.setup(options)
  options = options or {}
  local function find_repo_buffer(repo)
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if vim.b[buffer].lazygit_buffer and vim.b[buffer].lazygit_repo == repo
          and not vim.b[buffer].lazygit_exited then
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
      vim.b[event.buf].lazygit_exited = true

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

  for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[buffer].lazygit_buffer then configure_lazygit_buffer(buffer) end
  end

  vim.keymap.set("n", "<leader>gg", function()
    if vim.b.lazygit_buffer and not vim.b.lazygit_exited then
      vim.cmd("startinsert")
      return
    end
    local cwd = options.cwd and options.cwd() or vim.fn.getcwd()
    -- The Git directory distinguishes repositories, submodules, worktrees, and
    -- inherited Git contexts. Subdirectories share one instance.
    local result = vim.system({ "git", "-C", cwd, "rev-parse", "--absolute-git-dir" },
      { text = true }):wait(2000)
    if result.code ~= 0 then
      vim.notify("Could not resolve Lazygit repository:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end
    local git_dir = (result.stdout or ""):gsub("\n$", "")
    local repo = vim.uv.fs_realpath(git_dir) or git_dir
    local buffer = find_repo_buffer(repo)
    if buffer then
      local win
      for _, candidate in ipairs(vim.fn.win_findbuf(buffer)) do
        if vim.api.nvim_win_get_tabpage(candidate) == vim.api.nvim_get_current_tabpage() then
          win = candidate
        else
          vim.api.nvim_win_close(candidate, true)
        end
      end
      if win then
        vim.api.nvim_set_current_win(win)
      else
        open_lazygit_float(buffer)
      end
      vim.cmd("startinsert")
      return
    end

    local command = { "lazygit" }
    local args = options.launch_args and options.launch_args()
    if args == false then return end
    vim.list_extend(command, args or {})

    buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_var(buffer, "lazygit_buffer", true)
    vim.b[buffer].lazygit_repo = repo
    configure_lazygit_buffer(buffer)
    open_lazygit_float(buffer)
    local job = vim.fn.jobstart(command, { term = true, cwd = cwd })
    if job <= 0 then
      vim.api.nvim_buf_delete(buffer, { force = true })
      vim.notify("Could not start Lazygit", vim.log.levels.ERROR)
      return
    end
    vim.cmd("startinsert")
  end, { desc = "Lazygit" })

end

return M

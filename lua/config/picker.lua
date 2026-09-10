local M = {}

function M.setup(options)
  options = options or {}
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    return
  end

  fzf.setup({
    fzf_opts = { ["--layout"] = "reverse-list" },
    files = {
      fd_opts = "--color=never --type f --hidden --follow --exclude .git",
    },
    grep = {
      rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob '!.git'",
    },
  })

  local function review_worktree()
    local root = require("config.explorer").git_root_at_cursor()
    vim.system({ "git", "-C", root, "worktree", "list", "--porcelain", "-z" }, { text = true }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          local message = vim.trim(result.stderr or "")
          vim.notify(message ~= "" and message or "Could not list Git worktrees", vim.log.levels.ERROR)
          return
        end

        local worktrees = {}
        local current
        local function finish_worktree()
          if current and current.path then
            worktrees[#worktrees + 1] = current
          end
          current = nil
        end

        for _, field in ipairs(vim.split(result.stdout or "", "\0", { plain = true })) do
          if field == "" then
            finish_worktree()
          elseif vim.startswith(field, "worktree ") then
            finish_worktree()
            current = { path = field:sub(10) }
          elseif current then
            if vim.startswith(field, "HEAD ") then
              current.head = field:sub(6)
            elseif vim.startswith(field, "branch ") then
              current.branch = field:sub(8):gsub("^refs/heads/", "")
            elseif field == "detached" then
              current.detached = true
            elseif field == "bare" then
              current.bare = true
            end
          end
        end
        finish_worktree()

        if #worktrees == 0 then
          vim.notify("No Git worktrees found", vim.log.levels.WARN)
          return
        end

        local current_root = vim.uv.fs_realpath(root) or vim.fs.normalize(root)
        local entries = {}
        for index, worktree in ipairs(worktrees) do
          local path = vim.uv.fs_realpath(worktree.path) or vim.fs.normalize(worktree.path)
          local marker = path == current_root and "*" or " "
          local label = worktree.branch
            or (worktree.detached and ("detached@" .. (worktree.head or ""):sub(1, 8)))
            or (worktree.bare and "bare")
            or "unknown"
          entries[index] = string.format("%d\t%s %-24s %s", index, marker, label, worktree.path)
        end

        fzf.fzf_exec(entries, {
          prompt = "Worktrees> ",
          fzf_opts = {
            ["--delimiter"] = "\t",
            ["--with-nth"] = "2..",
          },
          winopts = { preview = { hidden = true } },
          actions = {
            ["ctrl-x"] = function(selected)
              local index = selected[1] and tonumber(selected[1]:match("^(%d+)\t"))
              local worktree = index and worktrees[index]
              if not worktree then return end
              local target = vim.uv.fs_realpath(worktree.path) or vim.fs.normalize(worktree.path)
              if worktree.bare or target == current_root then
                vim.notify("Cannot remove the current or bare worktree", vim.log.levels.WARN)
                return
              end
              vim.ui.select({ "Cancel", "Remove" }, {
                prompt = "Remove worktree directory " .. worktree.path .. "? (branch is kept)",
              }, function(choice)
                if choice ~= "Remove" then return end
                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                  local name = vim.api.nvim_buf_get_name(buf)
                  local path = vim.uv.fs_realpath(name) or vim.fs.normalize(name)
                  if vim.bo[buf].modified and vim.startswith(path, target .. "/") then
                    vim.notify("Worktree has unsaved buffers; removal cancelled", vim.log.levels.WARN)
                    return
                  end
                end
                vim.system({ "git", "-C", root, "worktree", "remove", "--", worktree.path },
                  { text = true }, vim.schedule_wrap(function(result)
                    if result.code ~= 0 then
                      vim.notify("Worktree removal failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
                    else
                      vim.notify("Removed worktree: " .. worktree.path .. "; branch kept")
                    end
                  end))
              end)
            end,
            ["ctrl-t"] = function(selected)
              local index = selected[1] and tonumber(selected[1]:match("^(%d+)\t"))
              local worktree = index and worktrees[index]
              if not worktree then return end
              if worktree.bare or vim.fn.isdirectory(worktree.path) ~= 1 then
                vim.notify("Worktree has no accessible working directory: " .. worktree.path, vim.log.levels.WARN)
                return
              end
              vim.cmd("tabnew")
              vim.api.nvim_cmd({ cmd = "tcd", args = { worktree.path } }, {})
              require("neo-tree.command").execute({
                source = "filesystem", action = "focus", position = "left", dir = worktree.path,
              })
            end,
            ["enter"] = function(selected)
              local index = selected[1] and tonumber(selected[1]:match("^(%d+)\t"))
              local worktree = index and worktrees[index]
              if worktree then
                vim.api.nvim_cmd({ cmd = "DiffviewOpen", args = { "-C=" .. worktree.path } }, {})
              end
            end,
          },
        })
      end)
    end)
  end

  local function find_files()
    if options.find_files and options.find_files() then return end
    fzf.files()
  end

  vim.keymap.set("n", "<leader>f", find_files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>/", function()
    -- Restore only grep's query, not a previous picker's cwd or callbacks.
    local opts = { __resume_key = "profile_live_grep" }
    opts.search = require("fzf-lua.config").resume_get("search", opts)
    opts.no_esc = true
    if options.live_grep and options.live_grep(opts) then return end
    opts.cwd = vim.fn.getcwd()
    fzf.live_grep(opts)
  end, { desc = "Search repository" })
  vim.keymap.set("x", "<leader>/", function()
    local search = require("fzf-lua.utils").get_visual_selection()
    if search == "" then return end
    local opts = { search = search, no_esc = false, __resume_key = "profile_live_grep" }
    if options.live_grep and options.live_grep(opts) then return end
    opts.cwd = vim.fn.getcwd()
    fzf.live_grep(opts)
  end, { desc = "Search selected text" })
  vim.keymap.set("n", "<leader>b", fzf.buffers, { desc = "Switch buffers" })
  vim.keymap.set("n", "<leader>w", fzf.tabs, { desc = "Switch windows across tabs" })
  vim.keymap.set("n", "<leader>sw", fzf.grep_cword, { desc = "Search word under cursor" })
  vim.keymap.set("n", "<leader>gs", function()
    fzf.git_status({ cwd = require("config.explorer").git_root_at_cursor() })
  end, { desc = "Git status" })
  vim.keymap.set("n", "<leader>gc", fzf.git_commits, { desc = "Git commits" })
  vim.keymap.set("n", "<leader>gb", fzf.git_branches, { desc = "Git branches" })
  vim.keymap.set("n", "<leader>gw", review_worktree, { desc = "Review Git worktree changes" })

end

return M

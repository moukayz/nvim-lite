local M = {}

function M.setup(options)
  options = options or {}

  local function started_with_directory()
    if vim.fn.argc(-1) ~= 1 then
      return false
    end
    local candidate = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
    local stat = vim.uv.fs_stat(candidate)
    return stat and stat.type == "directory" or false
  end

  local function copy_path(state, relative)
    local node = state.tree:get_node()
    if not node.path then
      vim.notify("This node has no filesystem path", vim.log.levels.WARN)
      return
    end

    local path = relative and vim.fn.fnamemodify(node.path, ":.") or node.path
    vim.fn.setreg("+", path)
    vim.notify(relative and "Copied relative path" or "Copied absolute path")
  end

  require("neo-tree").setup({
    sources = vim.list_extend({ "filesystem", "buffers", "git_status" }, options.sources or {}),
    close_if_last_window = true,
    popup_border_style = "rounded",
    default_component_configs = {
      indent = {
        with_expanders = true,
        expander_collapsed = "",
        expander_expanded = "",
      },
      modified = {
        symbol = "*",
      },
      git_status = {
        symbols = {
          added = "+",
          modified = "~",
          deleted = "x",
          renamed = "r",
          untracked = "?",
          ignored = "!",
          unstaged = "!",
          staged = "+",
          conflict = "!",
        },
      },
    },
    window = {
      position = "left",
      width = 32,
      mappings = {
        ["l"] = "open",
        ["h"] = "close_node",
        ["Y"] = {
          function(state)
            copy_path(state, false)
          end,
          desc = "Copy absolute path",
        },
        ["gy"] = {
          function(state)
            copy_path(state, true)
          end,
          desc = "Copy relative path",
        },
      },
    },
    filesystem = {
      hijack_netrw_behavior = started_with_directory() and "disabled" or "open_default",
      follow_current_file = {
        enabled = true,
        leave_dirs_open = false,
      },
      filtered_items = {
        visible = false,
        hide_dotfiles = true,
        hide_gitignored = true,
      },
    },
  })

  function M.git_root_at_cursor()
    local candidate
    local state = require("neo-tree.sources.manager").get_state_for_window()
    if state and state.tree then
      local node = state.tree:get_node()
      candidate = node and node.path or nil
    end

    if not candidate and vim.bo.buftype == "" then
      candidate = vim.api.nvim_buf_get_name(0)
    end
    if not candidate or candidate == "" then
      candidate = vim.fn.getcwd()
    end

    local stat = vim.uv.fs_stat(candidate)
    if not stat or stat.type ~= "directory" then
      candidate = vim.fs.dirname(candidate)
    end

    local git_root = require("neo-tree.git").find_worktree_info(candidate)
    return git_root or candidate
  end

  vim.keymap.set("n", "<leader>ee", function()
    if options.toggle_tree and options.toggle_tree() then return end
    vim.cmd("Neotree filesystem toggle reveal left")
  end, { desc = "Toggle file tree" })
  vim.keymap.set("n", "<leader>eg", function()
    require("neo-tree.command").execute({
      action = "focus",
      source = "git_status",
      position = "left",
      dir = M.git_root_at_cursor(),
    })
  end, { desc = "Open Git tree at cursor" })

end

return M

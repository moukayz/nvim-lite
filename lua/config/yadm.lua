-- Shared context detection: being in $HOME alone is not a yadm session.
local M = {}
local cached_key, cached_root

function M.work_tree()
  local git_dir, work_tree = vim.env.GIT_DIR, vim.env.GIT_WORK_TREE
  if not git_dir or git_dir == "" or not work_tree or work_tree == ""
      or vim.fn.executable("yadm") ~= 1 then
    return
  end
  local key = table.concat({ git_dir, work_tree, vim.fn.getcwd(), vim.env.XDG_DATA_HOME or "",
    vim.env.XDG_CONFIG_HOME or "", vim.env.HOME or "" }, "\0")
  if key == cached_key then return cached_root end
  local result = vim.system({ "yadm", "introspect", "repo" }, { text = true }):wait(2000)
  local inherited_repo = vim.uv.fs_realpath(git_dir)
  if result.code == 0 and inherited_repo
      and inherited_repo == vim.uv.fs_realpath(vim.trim(result.stdout or "")) then
    cached_key, cached_root = key, work_tree
    return work_tree
  end
end

local function show_yadm_files(work_tree, result)
    if result.code ~= 0 then
      vim.notify("Could not list yadm files: " .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end
    local files = vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })
    local entries = {}
    for index, file in ipairs(files) do
      -- Only the label is escaped. Preview and actions resolve an opaque ID
      -- back to the exact path, never interpreting Git quoting or fzf text.
      entries[index] = index .. "\t" .. vim.fn.strtrans(file)
    end
    local function selected_path(entry)
      local index = entry and tonumber(entry:match("^(%d+)\t"))
      return index and files[index] and vim.fs.joinpath(work_tree, files[index]) or nil
    end
    local previewer = require("fzf-lua.previewer.builtin").buffer_or_file:extend()
    function previewer:entry_to_file(entry)
      local path = selected_path(entry)
      return { path = path, stripped = path, line = 1, col = 1 }
    end
    local function open(cmd)
      return function(selected)
        for _, entry in ipairs(selected) do
          local path = selected_path(entry)
          if path then
            -- Ex filename arguments still interpret backslashes. Buffer APIs
            -- accept the literal filename, including tabs and newlines.
            local buffer = vim.fn.bufadd(path)
            if cmd == "tabedit" then
              vim.cmd("tabnew")
            elseif cmd ~= "edit" then
              vim.api.nvim_cmd({ cmd = cmd }, {})
            end
            vim.api.nvim_set_current_buf(buffer)
          end
        end
      end
    end
    require("fzf-lua").fzf_exec(entries, {
      prompt = "Dotfiles> ",
      cwd = work_tree,
      previewer = { _ctor = function() return previewer end },
      fzf_opts = { ["--delimiter"] = "\t", ["--with-nth"] = "2.." },
      actions = {
        ["enter"] = open("edit"),
        ["ctrl-s"] = open("split"),
        ["ctrl-v"] = open("vsplit"),
        ["ctrl-t"] = open("tabedit"),
      },
    })
end

-- Invalidate pending requests on both a new invocation and config reload.
vim.g.nvim_lite_yadm_picker_request = (vim.g.nvim_lite_yadm_picker_request or 0) + 1
function M.find_files()
  vim.g.nvim_lite_yadm_picker_request = vim.g.nvim_lite_yadm_picker_request + 1
  local request = vim.g.nvim_lite_yadm_picker_request
  local work_tree = M.work_tree()
  if not work_tree then
    return false
  end
  local git_dir = vim.env.GIT_DIR
  local win, buffer = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.system({ "git", "--git-dir=" .. git_dir, "--work-tree=" .. work_tree,
    "ls-files", "--full-name", "-z" }, { cwd = work_tree, timeout = 5000 }, function(result)
    vim.schedule(function()
      if request ~= vim.g.nvim_lite_yadm_picker_request
          or vim.env.GIT_DIR ~= git_dir or vim.env.GIT_WORK_TREE ~= work_tree
          or vim.api.nvim_get_current_win() ~= win or vim.api.nvim_get_current_buf() ~= buffer then
        return
      end
      show_yadm_files(work_tree, result)
    end)
  end)
  return true
end


function M.toggle_tree()
  local root = M.work_tree()
  if not root then return false end
  require("neo-tree.command").execute({ source = "yadm", action = "focus", toggle = true, position = "left", dir = root })
  return true
end

-- nil keeps defaults; false aborts launch after a reported error.
function M.lazygit_args()
  if M.work_tree() then
    local config_root = vim.env.XDG_CONFIG_HOME
    if not config_root or config_root == "" then
      config_root = vim.fs.joinpath(vim.env.HOME, ".config")
    end
    local config_file = vim.fs.joinpath(config_root, "lazygit", "config.yml")
    if vim.fn.filereadable(config_file) ~= 1 then
      vim.notify("Lazygit config not found: " .. config_file, vim.log.levels.ERROR)
      return false
    end
    return { "--use-config-file", config_file }
  end
end

return M

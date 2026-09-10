-- Resolve outside statusline rendering; cache by the buffer's directory.
local M = {}
local cache, request, label = {}, 0, ""
local function update()
  request = request + 1
  local current = request
  local file = vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or ""
  local dir = file ~= "" and vim.fs.dirname(file) or vim.fn.getcwd()
  label = cache[dir] or ""
  if cache[dir] ~= nil then return end
  local env = vim.fn.environ()
  env.GIT_DIR, env.GIT_WORK_TREE, env.GIT_COMMON_DIR = nil, nil, nil
  vim.system({ "git", "-C", dir, "rev-parse", "--path-format=absolute",
    "--show-toplevel", "--git-dir", "--git-common-dir" },
    { text = true, timeout = 2000, env = env, clear_env = true },
    vim.schedule_wrap(function(result)
      if package.loaded["config.worktree_status"] ~= M then return end
      local paths = vim.split(result.stdout or "", "\n", { trimempty = true })
      local value = ""
      if result.code == 0 and #paths == 3 then
        local git_dir = vim.uv.fs_realpath(paths[2]) or paths[2]
        local common = vim.uv.fs_realpath(paths[3]) or paths[3]
        if git_dir ~= common then value = vim.fs.basename(paths[1]) end
      end
      cache[dir] = value
      if request == current then
        label = value
        vim.cmd("redrawstatus")
      end
    end))
end
function M.component() return label end
vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
  group = vim.api.nvim_create_augroup("WorktreeStatus", { clear = true }),
  callback = update,
})
vim.schedule(update)
return M

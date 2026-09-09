local function reload_config(config_path)
  config_path = config_path or vim.env.MYVIMRC or (vim.fn.stdpath("config") .. "/init.lua")
  local ok, error_message = pcall(vim.api.nvim_cmd, {
    cmd = "source",
    args = { config_path },
  }, {})
  if ok then
    vim.notify("Neovim config reloaded", vim.log.levels.INFO)
  else
    vim.notify("Neovim config reload failed:\n" .. error_message, vim.log.levels.ERROR)
  end
end

vim.api.nvim_create_user_command("NvimConfigUpdate", function()
  local root = vim.fn.stdpath("config")
  -- Do not inherit yadm repository/index overrides.
  local env = vim.fn.environ()
  for _, key in ipairs({ "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE" }) do
    env[key] = nil
  end
  vim.notify("Updating Neovim config…")
  vim.system({ "git", "-C", root, "pull", "--ff-only" }, {
    text = true, env = env, clear_env = true,
  }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      vim.notify("Config update failed:\n" .. (result.stderr or ""), vim.log.levels.ERROR)
      return
    end
    vim.cmd("checktime")
    reload_config(root .. "/init.lua")
  end))
end, { desc = "Fast-forward config repository and reload" })

return { reload = reload_config }

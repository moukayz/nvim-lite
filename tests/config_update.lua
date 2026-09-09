local pending, calls, sourced = {}, {}, 0
local pull_code = 0
vim.system = function(argv, opts, callback)
  assert(opts.clear_env and opts.env.GIT_DIR == nil)
  assert(argv[3] == vim.fn.stdpath("config") and argv[4] == "pull" and argv[5] == "--ff-only")
  calls[#calls + 1] = argv[4]
  pending[#pending + 1] = function()
    callback({ code = pull_code, stdout = "", stderr = "test error" })
  end
end
vim.api.nvim_cmd = function(cmd)
  assert(cmd.cmd == "source")
  sourced = sourced + 1
end
vim.notify = function() end
local function drain()
  while #pending > 0 do
    table.remove(pending, 1)()
    vim.wait(20, function() return false end)
  end
end
dofile("lua/config/config_update.lua")
dofile("lua/config/config_update.lua")
vim.cmd("NvimConfigUpdate")
assert(sourced == 0, "must wait for Git")
drain()
assert(sourced == 1 and #calls == 1)
pull_code = 1
vim.cmd("NvimConfigUpdate")
drain()
assert(sourced == 1, "must not reload after failure")
print("config update tests passed")
vim.cmd("qa!")

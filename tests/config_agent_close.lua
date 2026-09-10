-- Real terminal job: quitting its window must stop it, not merely hide it.
vim.o.swapfile = false
vim.g.agent_command = { "sleep", "60" }
local function open()
  vim.fn.maparg("<leader>cc", "n", false, true).callback()
  vim.cmd("stopinsert")
  local buf = vim.api.nvim_get_current_buf()
  assert(vim.b[buf].config_agent_buffer and vim.bo[buf].buftype == "terminal")
  assert(vim.bo[buf].bufhidden == "wipe")
  return buf, vim.b[buf].terminal_job_id
end
local buf, job = open()
local tab = vim.api.nvim_get_current_tabpage()
assert(vim.fn.jobwait({ job }, 0)[1] == -1)
-- Switching away must not stop a terminal that still has an open window.
vim.cmd("wincmd l")
assert(vim.fn.jobwait({ job }, 0)[1] == -1)
vim.cmd("wincmd h")
vim.cmd.source(vim.env.MYVIMRC)
vim.cmd.source(vim.env.MYVIMRC)
vim.cmd("quit")
assert(vim.wait(2000, function() return not vim.api.nvim_buf_is_valid(buf) end))
assert(vim.fn.jobwait({ job }, 1000)[1] ~= -1, "closed agent job still running")
vim.wait(100, function() return false end)
assert(vim.api.nvim_tabpage_is_valid(tab) and #vim.api.nvim_tabpage_list_wins(tab) == 1)
assert(vim.api.nvim_buf_get_name(0) == vim.fn.stdpath("config") .. "/init.lua")
local next_buf, next_job = open()
assert(next_buf ~= buf and next_job ~= job)
vim.cmd("quit")
assert(vim.wait(2000, function() return not vim.api.nvim_buf_is_valid(next_buf) end))
assert(vim.fn.jobwait({ next_job }, 1000)[1] ~= -1)
print("config agent close tests passed")
vim.cmd("qa!")

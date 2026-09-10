-- Global explicit roots; excluded tool tabs retain their own browsing context.
local M = {}
local blocked = function() return false end
local excluded = function() return false end
vim.g.workspace_generation = (vim.g.workspace_generation or 0) + 1
local generation = vim.g.workspace_generation

function M.is_blocked()
  return blocked()
end

function M.all_roots()
  return vim.deepcopy(vim.g.workspace_roots or {})
end

function M.roots(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  if not vim.api.nvim_tabpage_is_valid(tab) or excluded(tab) then return {} end
  return M.all_roots()
end

function M.snapshot(tab)
  tab = tab or vim.api.nvim_get_current_tabpage()
  local roots, revision = M.roots(tab), vim.g.workspace_revision
  return roots, function()
    return vim.api.nvim_tabpage_is_valid(tab) and vim.g.workspace_generation == generation
      and vim.g.workspace_revision == revision and vim.deep_equal(M.roots(tab), roots)
  end
end

function M.labels(roots)
  local labels, counts = {}, {}
  for _, root in ipairs(roots) do
    local name = vim.fs.basename(root)
    counts[name] = (counts[name] or 0) + 1
  end
  for _, root in ipairs(roots) do
    local name = vim.fs.basename(root)
    labels[root] = counts[name] == 1 and name or vim.fn.fnamemodify(root, ":~")
  end
  return labels
end

local function set_roots(roots)
  vim.g.workspace_roots = roots
  vim.g.workspace_revision = (vim.g.workspace_revision or 0) + 1
  vim.api.nvim_exec_autocmds("User", { pattern = "WorkspaceChanged" })
end

function M.add(paths)
  if blocked() then return false, "Workspaces are disabled in this context" end
  local roots = M.all_roots()
  for _, input in ipairs(paths) do
    local path = vim.uv.fs_realpath(vim.fn.fnamemodify(input, ":p"))
    if not path or vim.fn.isdirectory(path) ~= 1 then
      return false, "Not a directory: " .. input
    end
    local duplicate = false
    for _, root in ipairs(roots) do
      if root == path then
        duplicate = true
      elseif vim.startswith(path, root .. "/") or vim.startswith(root, path .. "/")
          or root == "/" or path == "/" then
        return false, "Nested workspace roots are not supported: " .. path
      end
    end
    if not duplicate then roots[#roots + 1] = path end
  end
  set_roots(roots)
  return true
end

function M.setup(options)
  blocked = options and options.blocked or function() return false end
  excluded = options and options.excluded or function() return false end
  vim.api.nvim_create_user_command("WorkspaceAdd", function(args)
    local tab = vim.api.nvim_get_current_tabpage()
    local function add(paths)
      if not vim.api.nvim_tabpage_is_valid(tab) then return end
      local ok, err = M.add(paths)
      vim.notify(ok and ("Global workspace: " .. #M.all_roots() .. " roots") or err,
        ok and vim.log.levels.INFO or vim.log.levels.WARN)
    end
    if #args.fargs > 0 then return add(args.fargs) end
    vim.ui.input({ prompt = "Workspace directory: ", default = vim.fn.getcwd() .. "/", completion = "dir" },
      function(path) if path and path ~= "" then add({ path }) end end)
  end, { nargs = "*", complete = "dir", desc = "Add directories to the global workspace" })
  vim.api.nvim_create_user_command("WorkspaceRemove", function()
    local tab = vim.api.nvim_get_current_tabpage()
    local _, valid = M.snapshot(tab)
    local roots = M.all_roots()
    vim.ui.select(roots, { prompt = "Remove workspace root:" }, function(path)
      if not path or not valid() then return end
      set_roots(vim.tbl_filter(function(root) return root ~= path end, roots))
    end)
  end, { desc = "Remove a workspace directory" })
  vim.api.nvim_create_user_command("WorkspaceClear", function()
    set_roots({})
    vim.notify("Workspace cleared; ordinary browsing restored")
  end, { desc = "Clear the global workspace" })
  vim.api.nvim_create_user_command("WorkspaceInfo", function()
    local roots = M.all_roots()
    local message = #roots > 0 and ("Global workspace:\n" .. table.concat(roots, "\n")) or "No global workspace"
    if excluded(vim.api.nvim_get_current_tabpage()) then message = message .. "\nThis tab uses its own browsing context." end
    vim.notify(message)
  end, { desc = "Show global workspace roots" })
end

return M

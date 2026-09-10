local M = {}

-- fd respects ignore files and does not follow directory symlinks outside roots.
-- NUL output preserves literal filenames (including tabs and newlines).
function M.list(roots, directories, callback, max_depth)
  if #roots == 0 then
    vim.schedule(function() callback({}) end)
    return
  end
  local fd = vim.fn.executable("fd") == 1 and "fd" or "fdfind"
  if vim.fn.executable(fd) ~= 1 then
    vim.schedule(function() callback(nil, "Workspace browsing requires fd") end)
    return
  end
  local argv = { fd, "--color=never", "--hidden", "--exclude", ".git", "--print0", "--type", "f" }
  if directories then vim.list_extend(argv, { "--type", "d" }) end
  if max_depth then vim.list_extend(argv, { "--max-depth", tostring(max_depth) }) end
  vim.list_extend(argv, { ".", unpack(roots) })
  return vim.system(argv, { timeout = 30000 }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then return callback(nil, result.stderr or "fd failed") end
    local items = {}
    for _, path in ipairs(vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })) do
      local directory = path:sub(-1) == "/"
      path = directory and path:sub(1, -2) or path
      for _, root in ipairs(roots) do
        local prefix = root == "/" and "/" or root .. "/"
        if vim.startswith(path, prefix) then
          items[#items + 1] = { path = path, root = root, relative = path:sub(#prefix + 1),
            type = directory and "directory" or "file" }
          break
        end
      end
    end
    table.sort(items, function(a, b) return a.path < b.path end)
    callback(items)
  end))
end

return M

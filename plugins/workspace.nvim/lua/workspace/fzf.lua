local M = {}
local workspace = require("workspace")
local picker_request = 0

local function show_files(roots, valid)
  local labels, items = workspace.labels(roots), {}
  local job, closed = nil, false
  local function stop()
    closed = true
    if job then pcall(job.kill, job, 15) end
  end
  local function contents(push, push_raw)
    if closed or not valid() then push(nil); return end
    local fd = vim.fn.executable("fd") == 1 and "fd" or "fdfind"
    local argv = { fd, "--color=never", "--hidden", "--exclude", ".git", "--print0", "--type", "f", "." }
    vim.list_extend(argv, roots)
    local pending = ""
    local ok, process = pcall(vim.system, argv, {
      stdout = function(err, data)
        vim.schedule(function()
          if closed then return end
          if not valid() then stop(); push(nil); return end
          if err then vim.notify(err, vim.log.levels.ERROR); stop(); push(nil); return end
          if not data then return end
          pending = pending .. data
          local entries, offset = {}, 1
          while true do
            local last = pending:find("\0", offset, true)
            if not last then break end
            local target = pending:sub(offset, last - 1)
            offset = last + 1
            for _, root in ipairs(roots) do
              local prefix = root == "/" and "/" or root .. "/"
              if vim.startswith(target, prefix) then
                items[#items + 1] = { path = target }
                entries[#entries + 1] = #items .. "\t"
                  .. vim.fn.strtrans(labels[root] .. "/" .. target:sub(#prefix + 1))
                break
              end
            end
          end
          pending = pending:sub(offset)
          if #entries > 0 then
            push_raw(table.concat(entries, "\n") .. "\n", function(write_err)
              if write_err then stop() end
            end)
          end
        end)
      end,
    }, vim.schedule_wrap(function(result)
      job = nil
      if closed then return end
      if result.code ~= 0 then
        vim.notify("Workspace file scan failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
      end
      push(nil)
    end))
    if ok then
      job = process
    else
      vim.notify("Workspace file scan failed: " .. tostring(process), vim.log.levels.ERROR)
      push(nil)
    end
  end
  local function path(entry)
    local i = entry and tonumber(entry:match("^(%d+)\t"))
    return i and items[i] and items[i].path
  end
  local previewer = require("fzf-lua.previewer.builtin").buffer_or_file:extend()
  function previewer:entry_to_file(entry)
    return { path = path(entry), stripped = path(entry), line = 1, col = 1 }
  end
  local function open(cmd)
    return function(selected)
      if not valid() then return end
      for _, entry in ipairs(selected) do
        local target = path(entry)
        if target then
          if cmd then vim.api.nvim_cmd({ cmd = cmd }, {}) end
          vim.api.nvim_set_current_buf(vim.fn.bufadd(target))
        end
      end
    end
  end
  require("fzf-lua").fzf_exec(contents, {
    prompt = "Workspace files> ", cwd = roots[1],
    winopts = { on_close = stop },
    previewer = { _ctor = function() return previewer end },
    fzf_opts = { ["--delimiter"] = "\t", ["--with-nth"] = "2.." },
    actions = { enter = open(), ["ctrl-s"] = open("split"),
      ["ctrl-v"] = open("vsplit"), ["ctrl-t"] = open("tabnew") },
  })
end

function M.find_files()
  picker_request = picker_request + 1
  local request = picker_request
  local roots, valid = workspace.snapshot()
  if #roots == 0 or workspace.is_blocked() then return false end
  show_files(roots, function() return valid() and request == picker_request end)
  return true
end

function M.live_grep()
  local roots, valid = workspace.snapshot()
  if #roots == 0 or workspace.is_blocked() then return false end
  require("fzf-lua").live_grep({
    search_paths = roots, cwd = roots[1], prompt = "Workspace grep> ",
    fn_selected = function(selected, opts)
      if valid() then require("fzf-lua.actions").act(selected, opts) end
    end,
  })
  return true
end

return M

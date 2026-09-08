-- Run with: nvim --headless -i NONE -u NONE -l tests/picker.lua
vim.g.mapleader = " "
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("packadd fzf-lua")
local calls = {}
package.loaded["fzf-lua"] = setmetatable({
  setup = function() end,
  files = function(opts) calls[#calls + 1] = opts or false end,
  fzf_exec = function(entries, opts)
    opts.test_entries = entries
    calls[#calls + 1] = opts
  end,
}, { __index = function() return function() end end })
local real_system, real_executable, real_realpath = vim.system, vim.fn.executable, vim.uv.fs_realpath
local available, code, probes = true, 0, 0
local listing_code = 0
local names = { 'quote"name', "back\\slash", "tab\tname", "line\nname", "space name", "中文" }
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, "p")
fixture = vim.uv.fs_realpath(fixture)
for i, name in ipairs(names) do vim.fn.writefile({ "fixture " .. i }, fixture .. "/" .. name) end
-- Get real Git output: these are valid tracked paths, including a newline.
local function git(args)
  local r = real_system(vim.list_extend({ "git", "-C", fixture }, args), { text = false }):wait()
  assert(r.code == 0, r.stderr)
  return r.stdout
end
git({ "init", "-q" })
git({ "add", "--all" })
local listing = git({ "ls-files", "--full-name", "-z" })
local listed_names = vim.split(listing, "\0", { plain = true, trimempty = true })
vim.fn.executable = function(name) return name == "yadm" and (available and 1 or 0) or real_executable(name) end
vim.uv.fs_realpath = function(path)
  if path == "/alias/yadm.git" then return "/canonical/yadm.git" end
  return path ~= "" and path or nil
end
local pending = {}
vim.system = function(argv, opts, callback)
  if argv[1] == "git" then
    assert(vim.deep_equal(argv, { "git", "--git-dir=" .. vim.env.GIT_DIR,
      "--work-tree=" .. vim.env.GIT_WORK_TREE, "ls-files", "--full-name", "-z" }))
    assert(opts.cwd == vim.env.GIT_WORK_TREE)
    assert(type(callback) == "function" and opts.timeout == 5000)
    pending[#pending + 1] = callback
    return {}
  end
  assert(vim.deep_equal(argv, { "yadm", "introspect", "repo" }))
  probes = probes + 1
  return { wait = function(_, timeout)
    assert(timeout == 2000)
    return { code = code, stdout = "/canonical/yadm.git\n" }
  end }
end
local function pick()
  local before = #calls
  vim.fn.maparg("<leader>f", "n", false, true).callback()
  if #pending > 0 then
    assert(#calls == before, "picker opened before async completion")
    table.remove(pending, 1)({ code = listing_code, stdout = listing, stderr = "listing failed" })
    assert(vim.wait(1000, function() return #calls > before end))
  end
  return calls[#calls]
end
local function reload()
  package.loaded["config.yadm"] = nil
  dofile("lua/config/picker.lua").setup({ find_files = require("config.yadm").find_files })
end
for _ = 1, 2 do
  reload()
  vim.env.GIT_DIR, vim.env.GIT_WORK_TREE = nil, nil
  local before = probes
  assert(pick() == false and probes == before, "ordinary picker must not call yadm")
  vim.env.GIT_DIR, vim.env.GIT_WORK_TREE = "/other/.git", "/project"
  assert(pick() == false, "other Git context must stay ordinary")
  vim.env.GIT_DIR, vim.env.GIT_WORK_TREE = "/alias/yadm.git", fixture
  local opts = pick()
  local checked = probes
  pick()
  assert(probes == checked, "context should be cached")
  assert(opts.cwd == vim.env.GIT_WORK_TREE and opts.prompt == "Dotfiles> ")
  assert(#opts.test_entries == #names)
  local preview = opts.previewer._ctor()
  for index, entry in ipairs(opts.test_entries) do
    assert(not entry:find("\n"), "display label contains literal newline")
    local expected = fixture .. "/" .. listed_names[index]
    local parsed = preview.entry_to_file({}, entry)
    assert(parsed.path == expected, "preview path was altered")
    -- Use the actual builtin preview parser, including its stat/size checks.
    local parsed_preview = preview.parse_entry(setmetatable({ extensions = {}, limit_b = 1024 * 1024 }, { __index = preview }), entry)
    assert(parsed_preview.path == expected and not parsed_preview.content, "preview failed to stat exact path")
    opts.actions.enter({ entry })
    assert(vim.api.nvim_buf_get_name(0) == expected, "opened " .. vim.inspect(vim.api.nvim_buf_get_name(0)) .. " instead of " .. vim.inspect(expected))
    assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:match("^fixture "), "opened empty buffer")
    vim.cmd("bwipeout!")
  end
  available = false
  assert(pick() == false, "missing yadm must fall back")
  available, code = true, 1
  package.loaded["config.yadm"] = nil
  reload()
  assert(pick() == false, "failed introspection must fall back")
  code = 0
  vim.env.GIT_WORK_TREE = nil
  assert(pick() == false, "incomplete environment must fall back")
end
-- Superseded/reloaded requests must not open an unexpected picker.
vim.env.GIT_DIR, vim.env.GIT_WORK_TREE = "/alias/yadm.git", fixture
local before = #calls
local map = vim.fn.maparg("<leader>f", "n", false, true).callback
map()
map()
pending[1]({ code = 0, stdout = listing })
vim.wait(20, function() return false end)
assert(#calls == before, "older request was not discarded")
reload()
pending[2]({ code = 0, stdout = listing })
vim.wait(20, function() return false end)
assert(#calls == before, "reload did not invalidate pending request")
vim.system, vim.fn.executable, vim.uv.fs_realpath = real_system, real_executable, real_realpath
vim.fn.delete(fixture, "rf")
print("nvim-lite picker: ok")
vim.cmd("qa!")

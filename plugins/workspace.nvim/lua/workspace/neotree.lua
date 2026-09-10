local renderer = require("neo-tree.ui.renderer")
local common = require("neo-tree.sources.common.commands")
local workspace = require("workspace")
local M = {
  name = "workspace", display_name = "Workspace",
  components = require("neo-tree.sources.common.components"),
  commands = {},
  default_config = {
    -- Keep names in the buffer even when indentation exceeds the window width.
    -- The default container clips them, making horizontal reveal impossible.
    renderers = {
      directory = { { "indent" }, { "icon" }, { "name" }, { "diagnostics", errors_only = true } },
      file = { { "indent" }, { "icon" }, { "name" }, { "modified" }, { "diagnostics" } },
    },
    window = { mappings = {
      a = "none", A = "none", d = "none", r = "none",
      y = "none", x = "none", p = "none", c = "none", m = "none",
      ["<bs>"] = "none", ["."] = "none",
      ["<"] = "none", [">"] = "none", ["<C-r>"] = "none",
    } },
  },
}

local function node(path, name, directory)
  return { id = path, path = path, name = name, type = directory and "directory" or "file",
    loaded = not directory, children = directory and {} or nil }
end

local function cached_node(nodes, path)
  for _, item in ipairs(nodes) do
    if item.path == path then return item end
    local prefix = item.path == "/" and "/" or item.path .. "/"
    if item.children and vim.startswith(path, prefix) then
      return cached_node(item.children, path)
    end
  end
end

local follow_pending
local function load_directory(state, parent)
  local _, valid = workspace.snapshot(state.tabid)
  local win, epoch, path = state.winid, state.workspace_request, parent.path
  local request = {}
  state.workspace_loads[path] = request
  require("workspace.scan").list({ path }, true, function(items, err)
    if not valid() or state.disposed or state.workspace_request ~= epoch
        or state.workspace_loads[path] ~= request or state.winid ~= win
        or not vim.api.nvim_win_is_valid(win) or state.tree:get_node(path) ~= parent then return end
    state.workspace_loads[path] = nil
    if not items then return vim.notify(err, vim.log.levels.ERROR) end
    local children = {}
    for _, item in ipairs(items) do
      children[#children + 1] = node(item.path, item.relative, item.type == "directory")
    end
    table.sort(children, function(a, b)
      if a.type ~= b.type then return a.type == "directory" end
      return a.name < b.name
    end)
    local cached = cached_node(state.workspace_cache, path)
    cached.children, cached.loaded = children, true
    vim.api.nvim_win_call(win, function() renderer.show_nodes(vim.deepcopy(children), state, path) end)
    -- Refresh only branches that were already expanded, never hidden descendants.
    for _, child in ipairs(children) do
      if child.type == "directory" and state.workspace_expanded[child.path] then
        load_directory(state, state.tree:get_node(child.path))
      end
    end
    follow_pending(state)
  end, 1)
end

-- Walk only the target's ancestors; an in-flight expansion resumes this walk.
follow_pending = function(state)
  local target = state.workspace_follow
  if not target or workspace.is_blocked() or state.tabid ~= vim.api.nvim_get_current_tabpage()
      or not state.winid or not vim.api.nvim_win_is_valid(state.winid) then return end
  local path
  for _, root in ipairs(workspace.roots(state.tabid)) do
    if vim.startswith(target, root == "/" and "/" or root .. "/") then path = root; break end
  end
  if not path then return end
  while path ~= target do
    local parent = state.tree:get_node(path)
    if not parent or parent.type ~= "directory" then return end
    if not parent.loaded then
      if not state.workspace_loads[path] then load_directory(state, parent) end
      return
    end
    parent:expand()
    local prefix = path == "/" and "/" or path .. "/"
    local part = target:sub(#prefix + 1):match("^[^/]+")
    if not part then return end
    path = prefix .. part
  end
  if state.tree:get_node(target) then
    renderer.redraw(state)
    renderer.focus_node(state, target, true)
    -- Custom nodes have no `indent` field for Neo-tree's focus helper, which
    -- otherwise leaves the cursor at column zero and deep filenames off-screen.
    vim.api.nvim_win_call(state.winid, function()
      local line = vim.api.nvim_get_current_line()
      local name = state.tree:get_node(target).name
      local start, offset = nil, 1
      while true do
        local found = line:find(name, offset, true)
        if not found then break end
        start, offset = found, found + #name
      end
      if not start then return end
      local column = vim.fn.strdisplaywidth(line:sub(1, start - 1))
      local view = vim.fn.winsaveview()
      view.col = start - 1
      view.leftcol = column > vim.api.nvim_win_get_width(0) / 2 and math.max(0, column - 4) or 0
      vim.fn.winrestview(view)
    end)
  end
  state.workspace_follow = nil
end

local function follow_file(state, path)
  state.workspace_follow = path
  follow_pending(state)
end

local function toggle_directory(state, parent)
  state.workspace_follow = nil -- Manual tree navigation wins over pending follow.
  if state.workspace_loads[parent.path] then
    state.workspace_loads[parent.path] = nil -- Cancel an in-flight expansion.
  elseif parent.loaded then
    if parent:is_expanded() then parent:collapse() else parent:expand() end
    renderer.redraw(state)
  else
    load_directory(state, parent)
  end
end

function M.navigate(state, _, path_to_reveal, callback)
  local roots = workspace.roots(state.tabid)
  if #roots == 0 then return end
  local expanded = state.tree and renderer.get_expanded_nodes(state.tree) or {}
  state.workspace_request, state.workspace_loads, state.workspace_expanded = {}, {}, {}
  for _, path in ipairs(expanded) do state.workspace_expanded[path] = true end
  if state.workspace_cache and state.workspace_cache_revision == vim.g.workspace_revision then
    state.default_expanded_nodes = expanded
    -- Neo-tree deletes its UI buffer on close; keep the filesystem data separately.
    renderer.show_nodes(vim.deepcopy(state.workspace_cache), state)
    if path_to_reveal then follow_file(state, path_to_reveal) end
    if callback then vim.schedule(callback) end
    return
  end
  state.path, state.dirty, state.default_expanded_nodes = roots[1], false, {}
  local labels, nodes = workspace.labels(roots), {}
  for _, root in ipairs(roots) do
    nodes[#nodes + 1] = node(root, labels[root], true)
  end
  state.workspace_cache = nodes
  state.workspace_cache_revision = vim.g.workspace_revision
  renderer.show_nodes(vim.deepcopy(nodes), state)
  for _, root in ipairs(roots) do
    if state.workspace_expanded[root] then load_directory(state, state.tree:get_node(root)) end
  end
  if path_to_reveal then follow_file(state, path_to_reveal) end
  if callback then vim.schedule(callback) end
end

for _, name in ipairs({ "open", "open_split", "open_vsplit", "open_tabnew", "toggle_node",
  "open_with_window_picker" }) do
  M.commands[name] = function(state)
    state = require("neo-tree.sources.manager").get_state("workspace", state.tabid)
    common[name](state, function(parent) toggle_directory(state, parent) end)
  end
end
for _, name in ipairs({ "close_all_nodes", "expand_all_nodes", "close_window", "show_help", "toggle_preview",
  "toggle_auto_expand_width", "cancel", "scroll_preview" }) do
  M.commands[name] = common[name]
end
M.commands.close_node = function(state)
  state = require("neo-tree.sources.manager").get_state("workspace", state.tabid)
  state.workspace_follow = nil
  local current = state.tree:get_node()
  if current and state.workspace_loads[current.path] then
    state.workspace_loads[current.path] = nil
  else
    common.close_node(state)
  end
end
M.commands.refresh = function(state)
  state = require("neo-tree.sources.manager").get_state("workspace", state.tabid)
  state.workspace_cache = nil
  M.navigate(state)
end
M.commands.close_all_nodes = function(state)
  state = require("neo-tree.sources.manager").get_state("workspace", state.tabid)
  state.workspace_follow = nil
  state.workspace_loads, state.workspace_expanded = {}, {}
  common.close_all_nodes(state)
end

local function open_tree(toggle)
  local roots = workspace.roots()
  if #roots == 0 or workspace.is_blocked() then return false end
  local path = vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) or nil
  require("neo-tree.command").execute({
    source = "workspace", action = "focus", toggle = toggle, position = "left", dir = roots[1],
  })
  local state = require("neo-tree.sources.manager").get_state("workspace")
  if path and state.winid and vim.api.nvim_win_is_valid(state.winid) then follow_file(state, path) end
  return true
end
function M.toggle_tree() return open_tree(true) end
function M.focus_tree() return open_tree(false) end

function M.setup()
  local group = vim.api.nvim_create_augroup("WorkspaceTree", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(event)
      -- Do not react to the tree itself, terminals, or picker previews.
      if vim.bo[event.buf].buftype ~= "" then return end
      local tab, win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(win).relative ~= "" then return end
      vim.schedule(function()
        if vim.api.nvim_get_current_tabpage() ~= tab or vim.api.nvim_get_current_win() ~= win
            or vim.api.nvim_get_current_buf() ~= event.buf then return end
        local state = require("neo-tree.sources.manager").get_state("workspace", tab)
        if state.winid and vim.api.nvim_win_is_valid(state.winid) then
          follow_file(state, vim.api.nvim_buf_get_name(event.buf))
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "WorkspaceChanged",
    callback = function()
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local state = require("neo-tree.sources.manager").get_state("workspace", tab)
        if state.winid and vim.api.nvim_win_is_valid(state.winid) then
          if #workspace.roots(tab) == 0 then
            common.close_window(state)
          else
            M.navigate(state)
          end
        end
      end
    end,
  })
end
return M

local renderer = require("neo-tree.ui.renderer")
local common = require("neo-tree.sources.common.commands")
local M = {
  name = "yadm",
  display_name = "Dotfiles",
  components = require("neo-tree.sources.common.components"),
  commands = {},
  default_config = {
    window = { mappings = {
      ["a"] = "none", ["A"] = "none", ["d"] = "none", ["r"] = "none",
      ["y"] = "none", ["x"] = "none", ["p"] = "none", ["c"] = "none", ["m"] = "none",
    } },
  },
}

-- Build only tracked leaves and their parent directories; never scan $HOME.
function M.build_nodes(root_path, files)
  local root = { id = root_path, path = root_path, name = "Dotfiles", type = "directory", loaded = true, children = {} }
  local nodes_by_path = { [root_path] = root }
  for _, relative in ipairs(files) do
    local parent = root
    local parts = vim.split(relative, "/", { plain = true, trimempty = true })
    for index, part in ipairs(parts) do
      local path = vim.fs.joinpath(parent.path, part)
      local leaf = index == #parts
      local node = nodes_by_path[path]
      if not node then
        node = { id = path, path = path, name = part, type = leaf and "file" or "directory", loaded = true }
        if not leaf then
          node.children = {}
        end
        -- Conflicted index entries can list one file at multiple stages.
        nodes_by_path[path] = node
        table.insert(parent.children, node)
      end
      parent = node
    end
  end
  local function sort(node)
    if not node.children then return end
    table.sort(node.children, function(a, b)
      if a.type ~= b.type then return a.type == "directory" end
      return a.name < b.name
    end)
    for _, child in ipairs(node.children) do sort(child) end
  end
  sort(root)
  return { root }
end

function M.navigate(state, _, path_to_reveal, callback)
  local root = require("config.yadm").work_tree()
  if not root then
    vim.notify("Dotfiles tree requires a yadm session", vim.log.levels.WARN)
    return
  end
  state.path, state.dirty = root, false
  state.default_expanded_nodes = { root }
  -- Open immediately so toggle/close works even while Git is still running.
  if not state.winid or not vim.api.nvim_win_is_valid(state.winid) then
    renderer.show_nodes(M.build_nodes(root, {}), state)
  end
  local win = state.winid
  local request = {}
  state.yadm_request = request
  vim.system({ "git", "--git-dir=" .. vim.env.GIT_DIR, "--work-tree=" .. root,
    "ls-files", "--full-name", "-z" }, { cwd = root, timeout = 5000 }, function(result)
    vim.schedule(function()
      -- Ignore superseded refreshes and results arriving after close/reload.
      if state.disposed or state.yadm_request ~= request or state.winid ~= win
          or not vim.api.nvim_win_is_valid(win) then return end
      if result.code ~= 0 then
        vim.notify("Could not list yadm files: " .. (result.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local focused = vim.api.nvim_get_current_win()
      local nodes = M.build_nodes(root, vim.split(result.stdout or "", "\0", { plain = true, trimempty = true }))
      if path_to_reveal then renderer.position.set(state, path_to_reveal) end
      renderer.show_nodes(nodes, state)
      if vim.api.nvim_win_is_valid(focused) then vim.api.nvim_set_current_win(focused) end
    end)
  end)
  if callback then vim.schedule(callback) end
end

for _, name in ipairs({ "open", "open_split", "open_vsplit", "open_tabnew", "toggle_node",
  "close_node", "close_all_nodes", "expand_all_nodes", "close_window", "show_help", "toggle_preview",
  "clear_clipboard", "prev_source", "next_source", "open_with_window_picker",
  "toggle_auto_expand_width", "cancel", "scroll_preview" }) do
  M.commands[name] = common[name]
end
M.commands.refresh = function(state) M.navigate(state) end
M.setup = function() end
return M

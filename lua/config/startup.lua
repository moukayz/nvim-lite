local M = {}

local max_recent_files = 10
local highlight_namespace = vim.api.nvim_create_namespace("nvim_lite_startup")

local function normalize_existing_path(path)
  local absolute = vim.fn.fnamemodify(path, ":p")
  return vim.uv.fs_realpath(absolute) or vim.fs.normalize(absolute)
end

local function recent_files(directory, oldfiles)
  local root = normalize_existing_path(directory):gsub("/$", "")
  local prefix = root .. "/"
  local files = {}
  local seen = {}

  for _, oldfile in ipairs(oldfiles) do
    local path = normalize_existing_path(oldfile)
    local stat = vim.uv.fs_stat(path)
    if not seen[path] and stat and stat.type == "file" and vim.startswith(path, prefix) then
      seen[path] = true
      files[#files + 1] = {
        path = path,
        relative = path:sub(#prefix + 1),
      }
      if #files == max_recent_files then
        break
      end
    end
  end

  return files
end

local function startup_directory()
  local argument_count = vim.fn.argc(-1)
  if argument_count == 1 then
    local candidate = normalize_existing_path(vim.fn.argv(0))
    local stat = vim.uv.fs_stat(candidate)
    return stat and stat.type == "directory" and candidate or nil
  end
  if argument_count ~= 0 then
    return
  end

  local initial_lines = vim.api.nvim_buf_get_lines(0, 0, 2, false)
  local initial_buffer_is_empty = vim.bo.buftype == ""
    and vim.api.nvim_buf_get_name(0) == ""
    and not vim.bo.modified
    and #initial_lines == 1
    and initial_lines[1] == ""
  if initial_buffer_is_empty then
    return normalize_existing_path(vim.fn.getcwd())
  end
end

local function open_file_at_cursor(buffer, entries)
  local path = entries[vim.api.nvim_win_get_cursor(0)[1]]
  if path then
    vim.api.nvim_cmd({ cmd = "edit", args = { path } }, {})
  end
end

local function fit_text(text, width)
  if vim.fn.strdisplaywidth(text) <= width then
    return text
  end
  return "…" .. vim.fn.strcharpart(text, vim.fn.strchars(text) - width + 1)
end

local function centered(text, width)
  return string.rep(" ", math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))) .. text
end

local function centered_row(text, width)
  local text_width = vim.fn.strdisplaywidth(text)
  local left = math.max(0, math.floor((width - text_width) / 2))
  local right = math.max(0, width - text_width - left)
  return string.rep(" ", left) .. text .. string.rep(" ", right)
end

local function padded_row(text, width)
  return text .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(text)))
end

local function add_highlight(buffer, group, line, start_col, end_col)
  vim.api.nvim_buf_add_highlight(buffer, highlight_namespace, group, line - 1, start_col, end_col)
end

local function render(buffer, directory, files, entries)
  local window_width = vim.api.nvim_win_get_width(0)
  local window_height = vim.api.nvim_win_get_height(0)
  local widest_file = 0
  for _, file in ipairs(files) do
    widest_file = math.max(widest_file, vim.fn.strdisplaywidth(file.relative))
  end

  local panel_width = math.min(math.max(48, widest_file + 10), math.max(24, window_width - 8))
  local inner_width = panel_width - 2
  local root_label = fit_text(vim.fn.fnamemodify(directory, ":~"), inner_width - 4)
  local content = {
    "╭" .. string.rep("─", inner_width) .. "╮",
    "│" .. centered_row("NVIM LITE", inner_width) .. "│",
    "│" .. centered_row(root_label, inner_width) .. "│",
    "╰" .. string.rep("─", inner_width) .. "╯",
    "",
    padded_row("  RECENT FILES", panel_width),
    "",
  }

  if #files == 0 then
    content[#content + 1] = padded_row("  No recent files in this directory", panel_width)
  else
    for index, file in ipairs(files) do
      local row = string.format("  %2d   %s", index, fit_text(file.relative, panel_width - 9))
      content[#content + 1] = padded_row(row, panel_width)
    end
  end
  content[#content + 1] = ""
  content[#content + 1] = centered_row("↵/number open   f files   e explorer   q close", panel_width)

  local top_padding = math.max(1, math.floor((window_height - #content) / 3))
  local lines = {}
  for _ = 1, top_padding do
    lines[#lines + 1] = ""
  end
  for _, line in ipairs(content) do
    lines[#lines + 1] = centered(line, window_width)
  end

  vim.bo[buffer].modifiable = true
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  vim.api.nvim_buf_clear_namespace(buffer, highlight_namespace, 0, -1)

  for line in pairs(entries) do
    entries[line] = nil
  end
  local first_content_line = top_padding + 1
  add_highlight(buffer, "FloatBorder", first_content_line, 0, -1)
  add_highlight(buffer, "Title", first_content_line + 1, 0, -1)
  add_highlight(buffer, "Directory", first_content_line + 2, 0, -1)
  add_highlight(buffer, "FloatBorder", first_content_line + 3, 0, -1)
  add_highlight(buffer, "Special", first_content_line + 5, 0, -1)

  if #files == 0 then
    add_highlight(buffer, "Comment", first_content_line + 7, 0, -1)
  else
    for index, file in ipairs(files) do
      local line = first_content_line + 6 + index
      entries[line] = file.path
      local number_start = lines[line]:find("%d") - 1
      add_highlight(buffer, "Number", line, number_start, number_start + #tostring(index))
    end
  end
  add_highlight(buffer, "Comment", #lines, 0, -1)

  if next(entries) then
    vim.api.nvim_win_set_cursor(0, { first_content_line + 7, 0 })
  end
end

function M.show(directory, oldfiles)
  directory = normalize_existing_path(directory)
  vim.api.nvim_set_current_dir(directory)

  local files = recent_files(directory, oldfiles or vim.v.oldfiles)
  local entries = {}

  local buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, buffer)
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "hide"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].filetype = "nvim-lite-start"

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.foldcolumn = "0"
  vim.wo.cursorline = true
  render(buffer, directory, files, entries)

  vim.keymap.set("n", "<CR>", function()
    open_file_at_cursor(buffer, entries)
  end, { buffer = buffer, desc = "Open recent file" })
  for index, file in ipairs(files) do
    local key = index == 10 and "0" or tostring(index)
    local path = file.path
    vim.keymap.set("n", key, function()
      vim.api.nvim_cmd({ cmd = "edit", args = { path } }, {})
    end, { buffer = buffer, desc = "Open recent file " .. index })
  end
  vim.keymap.set("n", "f", function()
    require("fzf-lua").files({ cwd = directory })
  end, { buffer = buffer, desc = "Find files" })
  vim.keymap.set("n", "e", function()
    require("neo-tree.command").execute({
      action = "focus",
      source = "filesystem",
      position = "left",
      dir = directory,
    })
  end, { buffer = buffer, desc = "Open file tree" })
  vim.keymap.set("n", "q", "<cmd>enew<cr>", { buffer = buffer, desc = "Close start page" })
end

local startup_group = vim.api.nvim_create_augroup("NvimLiteStartup", { clear = true })
vim.api.nvim_create_autocmd("VimEnter", {
  group = startup_group,
  once = true,
  callback = function()
    local directory = startup_directory()
    if directory then
      vim.schedule(function()
        M.show(directory)
      end)
    end
  end,
})

return M

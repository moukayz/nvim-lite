local parsers = {
  "c",
  "cpp",
  "javascript",
  "markdown",
  "markdown_inline",
  "python",
  "ruby",
  "tsx",
  "typescript",
}
vim.filetype.add({ filename = { Podfile = "ruby" }, extension = { podspec = "ruby" } })
local cli_root = vim.fs.joinpath(vim.fn.stdpath("data"), "tree-sitter-cli")
local cli_bin = vim.fs.joinpath(cli_root, "bin")
if not vim.tbl_contains(vim.split(vim.env.PATH or "", ":", { plain = true }), cli_bin) then
  vim.env.PATH = cli_bin .. ":" .. (vim.env.PATH or "")
end

local function install_parsers()
  local missing = require("nvim-treesitter.config").norm_languages(parsers, { installed = true })
  if #missing == 0 then return end
  if vim.fn.executable("tree-sitter") == 1 then
    require("nvim-treesitter").install(missing)
    return
  end
  -- Session-scoped state survives <Space>rs, including while the job is running.
  if vim.g.nvim_lite_ts_cli_attempted then return end
  vim.g.nvim_lite_ts_cli_attempted = true
  local command
  if vim.fn.executable("brew") == 1 then
    command = { "brew", "install", "tree-sitter-cli" }
  elseif vim.fn.executable("npm") == 1 then
    command = { "npm", "install", "--global", "--prefix", cli_root, "tree-sitter-cli@0.26.13" }
  elseif vim.fn.executable("cargo") == 1 then
    command = { "cargo", "install", "--locked", "--root", cli_root, "tree-sitter-cli", "--version", "0.26.13" }
  else
    vim.notify("Parser installation needs tree-sitter CLI; automatic setup requires Homebrew, npm, or Cargo.", vim.log.levels.WARN)
    return
  end
  vim.notify("Installing tree-sitter CLI in the background…")
  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 or vim.fn.executable("tree-sitter") ~= 1 then
        vim.notify("Tree-sitter CLI installation failed; parsers were not installed. "
          .. vim.trim(result.stderr or "") .. "\nRetry on the next Neovim launch.", vim.log.levels.ERROR)
        return
      end
      vim.notify("Tree-sitter CLI installed; installing missing parsers…")
      install_parsers()
    end)
  end)
end
install_parsers()

local treesitter_group = vim.api.nvim_create_augroup("NvimLiteTreesitter", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = treesitter_group,
  pattern = {
    "c",
    "cpp",
    "javascript",
    "javascriptreact",
    "python",
    "ruby",
    "typescript",
    "typescriptreact",
  },
  callback = function(event)
    pcall(vim.treesitter.start, event.buf)
  end,
  desc = "Enable Tree-sitter highlighting",
})

require("nvim-treesitter-textobjects").setup({
  select = {
    lookahead = true,
    selection_modes = {
      ["@parameter.outer"] = "v",
      ["@function.outer"] = "V",
      ["@class.outer"] = "V",
    },
    include_surrounding_whitespace = false,
  },
})

local ts_select = require("nvim-treesitter-textobjects.select")
local function map_textobject(lhs, capture, description)
  vim.keymap.set({ "x", "o" }, lhs, function()
    ts_select.select_textobject(capture, "textobjects")
  end, { desc = description })
end

map_textobject("af", "@function.outer", "Around function")
map_textobject("if", "@function.inner", "Inside function")
map_textobject("ac", "@class.outer", "Around class")
map_textobject("ic", "@class.inner", "Inside class")
map_textobject("aa", "@parameter.outer", "Around argument")
map_textobject("ia", "@parameter.inner", "Inside argument")

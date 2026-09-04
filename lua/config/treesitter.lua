local parsers = {
  "c",
  "cpp",
  "javascript",
  "python",
  "tsx",
  "typescript",
}
local missing_parsers = require("nvim-treesitter.config").norm_languages(parsers, { installed = true })
if #missing_parsers > 0 then
  require("nvim-treesitter").install(missing_parsers)
end

local treesitter_group = vim.api.nvim_create_augroup("NvimLiteTreesitter", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = treesitter_group,
  pattern = {
    "c",
    "cpp",
    "javascript",
    "javascriptreact",
    "python",
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

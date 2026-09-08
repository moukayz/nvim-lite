local installed, parses, jobs = false, 0, {}
local manager = "npm"
package.loaded["nvim-treesitter.config"] = { norm_languages = function() return { "c" } end }
package.loaded["nvim-treesitter"] = { install = function() parses = parses + 1 end }
package.loaded["nvim-treesitter-textobjects"] = { setup = function() end }
package.loaded["nvim-treesitter-textobjects.select"] = { select_textobject = function() end }
vim.notify = function() end
vim.fn.executable = function(name) return (name == "tree-sitter" and installed or name == manager) and 1 or 0 end
vim.system = function(argv, _, callback)
  jobs[#jobs + 1] = { argv = argv, callback = callback }
end
local function reload() dofile("lua/config/treesitter.lua") end
reload()
reload()
assert(#jobs == 1 and parses == 0, "reload duplicated install or installed parsers too early")
assert(jobs[1].argv[1] == "npm" and jobs[1].argv[5] == vim.fs.joinpath(vim.fn.stdpath("data"), "tree-sitter-cli"))
installed = true
jobs[1].callback({ code = 0 })
assert(vim.wait(1000, function() return parses == 1 end), "successful CLI install did not resume parsers")
reload()
assert(#jobs == 1 and parses == 2, "existing CLI should install parsers directly")
installed, manager = false, "brew"
vim.g.nvim_lite_ts_cli_attempted = nil
reload()
assert(jobs[2].argv[1] == "brew")
jobs[2].callback({ code = 1, stderr = "offline" })
vim.wait(20, function() return false end)
reload()
assert(#jobs == 2 and parses == 2, "failed install should not loop or install parsers")
manager = "cargo"
vim.g.nvim_lite_ts_cli_attempted = nil
reload()
assert(jobs[3].argv[1] == "cargo")
manager = "none"
vim.g.nvim_lite_ts_cli_attempted = nil
reload()
assert(#jobs == 3, "no supported installer should not spawn")
print("nvim-lite treesitter: ok")
vim.cmd("qa!")

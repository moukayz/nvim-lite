-- Full profile; drive the fd stream manually to check latency, chunking and cancellation.
local workspace = require("workspace")
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
root = vim.uv.fs_realpath(root)
assert(workspace.add({ root }))
local producer, options, output, finished
require("fzf-lua").fzf_exec = function(contents, opts)
  producer, options, output, finished = contents, opts, {}, false
end
local stdout, on_exit, killed, starts = nil, nil, 0, 0
local real_system = vim.system
vim.system = function(argv, opts, callback)
  if argv[1] ~= "fd" and argv[1] ~= "fdfind" then return real_system(argv, opts, callback) end
  starts = starts + 1
  assert(argv[#argv] == root and opts.stdout and not opts.text)
  stdout, on_exit = opts.stdout, callback
  return { kill = function() killed = killed + 1 end }
end
local function flush() vim.wait(20, function() return false end) end
local function start()
  require("workspace.fzf").find_files()
  assert(type(producer) == "function" and not finished, "picker did not open immediately")
  producer(function(value) if value == nil then finished = true end end, function(chunk, cb)
    vim.list_extend(output, vim.split(chunk, "\n", { trimempty = true }))
    if cb then cb() end
  end)
end
start()
assert(starts == 1 and #output == 0)
local target = root .. '/quote"tab\tline\n.txt'
stdout(nil, target:sub(1, 8)); flush()
assert(#output == 0, "partial filename emitted")
stdout(nil, target:sub(9) .. "\0"); flush()
assert(#output == 1 and not finished, "must show results before process exits")
local preview = options.previewer._ctor()
assert(preview.entry_to_file(preview, output[1]).path == target, "literal filename corrupted")
stdout(nil, root .. "/two.txt\0" .. root .. "/three.txt\0"); flush()
assert(#output == 3)
on_exit({ code = 0 }); flush()
assert(finished)
options.winopts.on_close()
assert(killed == 0, "completed process should not be killed")
start()
options.winopts.on_close()
assert(killed == 1)
stdout(nil, root .. "/late\0"); flush()
assert(#output == 0, "closed picker got late output")
start()
vim.cmd("WorkspaceClear")
stdout(nil, root .. "/stale\0"); flush()
assert(#output == 0 and finished and killed == 2, "changed roots did not invalidate stream")
print("workspace streaming tests passed")
vim.cmd("qa!")

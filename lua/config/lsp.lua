if vim.fn.executable("clangd") == 1 then
  vim.lsp.config("clangd", {
    cmd = { "clangd" },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
    root_markers = { ".clangd", "compile_commands.json", "compile_flags.txt", ".git" },
  })
  vim.lsp.enable("clangd")
end

local ts_lsp = vim.fn.stdpath("data")
  .. "/lsp/typescript/node_modules/.bin/typescript-language-server"
local tsserver_path = vim.fn.stdpath("data")
  .. "/lsp/typescript/node_modules/typescript/lib/tsserver.js"
local ts_filetypes = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
}
local ts_root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" }

local function find_typescript_installation(start_dir)
  local dir = start_dir
  while dir and dir ~= "" do
    local package_path = dir .. "/node_modules/typescript/package.json"
    local tsc_path = dir .. "/node_modules/.bin/tsc"
    if vim.fn.filereadable(package_path) == 1 and vim.fn.executable(tsc_path) == 1 then
      local ok, package = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_path), "\n"))
      local major = ok and package.version and tonumber(package.version:match("^(%d+)"))
      if major then
        return { major = major, tsc = tsc_path }
      end
    end

    local parent = vim.fs.dirname(dir)
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
end

local function typescript_workspace(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local start_dir = filename ~= "" and vim.fs.dirname(filename) or vim.uv.cwd()
  return {
    root = vim.fs.root(start_dir, ts_root_markers),
    installation = find_typescript_installation(start_dir),
  }
end

if vim.fn.executable(ts_lsp) ~= 1 then
  ts_lsp = "typescript-language-server"
end

-- TypeScript 7 ships a native LSP. Activate it only for workspaces that have
-- the native compiler installed, and launch that exact project-local version.
vim.lsp.config("tsgo", {
  cmd = function(dispatchers, config)
    local installation = find_typescript_installation(config.root_dir)
    assert(installation and installation.major >= 7, "TypeScript 7 installation disappeared")
    return vim.lsp.rpc.start(
      { installation.tsc, "--lsp", "--stdio" },
      dispatchers,
      { cwd = config.root_dir }
    )
  end,
  filetypes = ts_filetypes,
  root_dir = function(bufnr, on_dir)
    local workspace = typescript_workspace(bufnr)
    if workspace.root and workspace.installation and workspace.installation.major >= 7 then
      on_dir(workspace.root)
    end
  end,
  workspace_required = true,
})
vim.lsp.enable("tsgo")

if vim.fn.executable(ts_lsp) == 1 then
  vim.lsp.config("ts_ls", {
    cmd = { ts_lsp, "--stdio" },
    filetypes = ts_filetypes,
    root_dir = function(bufnr, on_dir)
      local workspace = typescript_workspace(bufnr)
      if not workspace.installation or workspace.installation.major < 7 then
        on_dir(workspace.root)
      end
    end,
    workspace_required = false,
    init_options = {
      hostInfo = "neovim",
      tsserver = {
        fallbackPath = tsserver_path,
        useSyntaxServer = "never",
      },
    },
  })
  vim.lsp.enable("ts_ls")
end

local lsp_group = vim.api.nvim_create_augroup("NvimLiteLsp", { clear = true })
vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf)
    end

    -- Neovim supplies grr/gri/grn/gra, grt/grx, gO, K, and insert Ctrl-S.
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
      buffer = event.buf,
      desc = "Go to definition",
    })

    vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get, {
      buffer = event.buf,
      desc = "Trigger LSP completion",
    })
  end,
})

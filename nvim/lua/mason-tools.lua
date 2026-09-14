-- Single source of truth for Mason tools (LSP servers, formatters,
-- linters, DAP). Two consumers:
--   * lua/plugins/tools.lua -- mason-tool-installer ensure_installed
--     (interactive auto-install on nvim startup)
--   * install.sh -- headless bootstrap via require("mason-tools"):bootstrap()
--
-- The bootstrap drives :MasonInstall, which mason.nvim runs synchronously
-- in headless mode (blocking wait_all, non-zero exit naming any failure) --
-- unlike MasonToolsInstallSync, whose wait loop has no timeout and can
-- deadlock after a successful run (mason.nvim#2049).
local M = {}

M.tools = {
  -- bash (no dedicated LazyVim lang extra)
  "bash-language-server",
  "shfmt",
  "shellcheck",
  -- python (lang.python)
  "basedpyright",
  "ruff",
  "debugpy",
  -- go (lang.go)
  "gopls",
  "gofumpt",
  "goimports",
  "golangci-lint",
  "delve",
  -- typescript (lang.typescript)
  "vtsls",
  "js-debug-adapter",
  -- yaml / k8s (lang.yaml, lang.helm)
  "yaml-language-server",
  "helm-ls",
  -- docker (lang.docker)
  "dockerfile-language-server",
  "docker-compose-language-service",
  "hadolint",
  -- terraform (lang.terraform)
  "terraform-ls",
  "tflint",
  -- json/markdown (lang.json, lang.markdown)
  "json-lsp",
  "marksman",
  "markdownlint-cli2",
  "markdown-toc",
  -- toml (lang.toml)
  "taplo",
  -- lua (LazyVim config itself)
  "lua-language-server",
  "stylua",
}

--- Headless-bootstrap install of every tool still missing (installed
--- tools are skipped, so repeated runs are cheap).
function M.bootstrap()
  require("lazy").load({ plugins = { "mason.nvim" } })
  local registry = require("mason-registry")
  local missing = {}
  for _, name in ipairs(M.tools) do
    local ok, pkg = pcall(registry.get_package, name)
    if not ok or not pkg:is_installed() then
      missing[#missing + 1] = name
    end
  end
  if #missing > 0 then
    vim.cmd(("MasonInstall %s"):format(table.concat(missing, " ")))
  end
end

return M

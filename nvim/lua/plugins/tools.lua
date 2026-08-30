-- This file is automatically loaded by lazyvim.config.init
-- Add custom plugins or overrides here. Language support comes from
-- LazyVim extras (see lazyvim.json) — keep this file for tweaks only.

return {
  -- mason-tool-installer: enables "+MasonToolsInstallSync" for headless
  -- pre-warm in .devcontainer/post-create.sh and dotfiles install.sh.
  -- Installs the LSP servers/formatters/linters that the enabled extras
  -- declare, deterministically, without opening the UI.
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    cmd = { "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsUpdate" },
    opts = {
      -- Servers/formatters the extras don't already declare via mason.
      -- LazyVim extras auto-register their own tools on LSP attach, but for
      -- deterministic headless bootstrap (post-create.sh / install.sh) we
      -- list every server explicitly so first `nvim` open is fully warm.
      ensure_installed = {
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
      },
      auto_update = false, -- updates stay deliberate: lazy-lock.json / :MasonUpdate
      run_on_start = true,
    },
  },
}

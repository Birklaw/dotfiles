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
      -- LazyVim extras auto-register their own tools; keep this list for
      -- anything extra (e.g. bash tools have no dedicated lang extra).
      ensure_installed = {
        "bash-language-server",
        "shfmt",
        "shellcheck",
      },
      auto_update = false,
      run_on_start = false,
    },
  },
}

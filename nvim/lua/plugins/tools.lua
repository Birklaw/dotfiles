-- This file is automatically loaded by lazyvim.config.init
-- Add custom plugins or overrides here. Language support comes from
-- LazyVim extras (see lazyvim.json) — keep this file for tweaks only.

return {
  -- mason-tool-installer: interactive auto-install of the tools in
  -- lua/mason-tools.lua on nvim startup, plus the :MasonTools* commands.
  -- NOT used by the headless bootstrap in install.sh — that drives
  -- Package:install (see mason-tools.bootstrap) so each install can be
  -- awaited and attributed; MasonToolsInstallSync can deadlock after a
  -- successful run (mason.nvim#2049).
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    cmd = { "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsUpdate" },
    opts = {
      -- Version-pinned tools are installed by install.sh's bootstrap; this
      -- plugin cannot express a version (see mason-tools.interactive_tools).
      ensure_installed = require("mason-tools").interactive_tools(),
      auto_update = false, -- Updates stay deliberate: lazy-lock.json / :MasonUpdate
      run_on_start = true,
      start_delay = 2000, -- Avoid racing a manual :MasonToolsInstallSync
    },
  },

  -- Snacks explorer: show hidden files by default. `<a-h>` still toggles
  -- them per-session; gitignored files stay excluded (`ignored = false`).
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
          },
        },
      },
    },
  },
}

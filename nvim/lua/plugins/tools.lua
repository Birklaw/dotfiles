-- This file is automatically loaded by lazyvim.config.init
-- Add custom plugins or overrides here. Language support comes from
-- LazyVim extras (see lazyvim.json) — keep this file for tweaks only.

return {
  -- mason-tool-installer: interactive auto-install of the tools in
  -- lua/mason-tools.lua on nvim startup, plus the :MasonTools* commands.
  -- NOT used by the headless bootstrap in install.sh — that drives
  -- :MasonInstall directly, because MasonToolsInstallSync can deadlock
  -- after a successful run (mason.nvim#2049).
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    cmd = { "MasonToolsInstall", "MasonToolsInstallSync", "MasonToolsUpdate" },
    opts = {
      ensure_installed = require("mason-tools").tools,
      auto_update = false, -- Updates stay deliberate: lazy-lock.json / :MasonUpdate
      run_on_start = true,
      start_delay = 2000, -- Avoid racing a manual :MasonToolsInstallSync
    },
  },
}

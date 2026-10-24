-- Single source of truth for Mason tools (LSP servers, formatters,
-- linters, DAP). Two consumers:
--   * lua/plugins/tools.lua -- mason-tool-installer ensure_installed
--     (interactive auto-install on nvim startup)
--   * install.sh -- headless bootstrap via require("mason-tools"):bootstrap()
--
-- npm packages go through the dotfiles `.npmrc`, which sets
-- `min-release-age=14` (supply-chain guard). That guard is honoured here, not
-- bypassed: if mason's registry pins a version published within the last 14
-- days, npm refuses it (`npm error code ETARGET`) and bootstrap fails naming
-- the tool. Fix by pinning an older release with the `name@version` form in
-- M.tools (Package:install takes an exact version), or wait until the pin ages
-- out. Entries are `name` or `name@version`; a bare name uses mason's pin.

local M = {}

--- Names for mason-tool-installer's `ensure_installed`. Pinned entries
--- (`name@version`) are excluded: mason-tool-installer cannot express a
--- version, and letting it ask for mason's (blocked) pin would fail on every
--- startup. install.sh's headless bootstrap installs the pinned versions.
---@return string[]
function M.interactive_tools()
  local names = {}
  for _, entry in ipairs(M.tools) do
    if not entry:find("@", 1, true) then
      names[#names + 1] = entry
    end
  end
  return names
end

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
  -- mason pins 2.0.0 (published 2026-10-16); .npmrc min-release-age=14
  -- rejects it, so pin the newest release outside the window instead.
  "yaml-language-server@1.24.0",
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
  -- mason pins 0.24.0 (published 2026-10-21); same 14-day window.
  "markdownlint-cli2@0.23.3",
  "markdown-toc",
  -- toml (lang.toml)
  "taplo",
  -- lua (LazyVim config itself)
  "lua-language-server",
  "stylua",
}

--- How long a single package may take before it is reported as failed.
local INSTALL_TIMEOUT_MS = 10 * 60 * 1000

--- True when an npm failure is the min-release-age guard (not a network or
--- build error), so the message can say what to change.
---@param err any
local function is_release_age_failure(err)
  local text = type(err) == "string" and err or vim.inspect(err)
  return text:find("ETARGET", 1, true) ~= nil
    or text:find("notarget", 1, true) ~= nil
    or text:find("min-release-age", 1, true) ~= nil
    or text:find("No matching version found", 1, true) ~= nil
end

--- Install one package and block until mason reports success or failure.
---
--- `:MasonInstall` is asynchronous even in headless mode: call it, return,
--- and install.sh's `+qa` kills the installs mid-flight ("Neovim is exiting
--- while packages are still installing"). Driving `Package:install` directly
--- gives a completion callback, so each tool can be awaited and its failure
--- attributed by name instead of surfacing as an anonymous E5108.
---
--- Packages may already be installing: `lua/plugins/tools.lua` (mason-tool-
--- installer `ensure_installed`) kicks off the same tools on startup, and
--- `Package:install` asserts on a package that is already in flight. Wait for
--- that install instead of starting a second one.
---@param pkg Package
---@param version string? exact version to install instead of mason's pin
---@return boolean ok, any err
local function install_blocking(pkg, version)
  if pkg:is_installed() then
    return true
  end
  if pkg:is_installing() then
    if
      not vim.wait(INSTALL_TIMEOUT_MS, function()
        return pkg:is_installed() or not pkg:is_installing()
      end, 250)
    then
      return false, "timed out waiting for an install already in progress"
    end
    return pkg:is_installed(), "install was started by mason-tool-installer and did not complete"
  end

  local done, success, err = false, nil, nil
  pkg:install(version and { version = version } or {}, function(ok, e)
    success, err, done = ok, e, true
  end)
  if
    not vim.wait(INSTALL_TIMEOUT_MS, function()
      return done
    end, 250)
  then
    return false, ("timed out after %ds"):format(INSTALL_TIMEOUT_MS / 1000)
  end
  -- The callback fires before mason's link/post-install phase has drained;
  -- quitting then rolls the package back. Wait for the package to settle.
  if
    not vim.wait(INSTALL_TIMEOUT_MS, function()
      return not pkg:is_installing()
    end, 250)
  then
    return false, "install did not settle"
  end
  return success == true and pkg:is_installed(), err
end

--- Headless-bootstrap install of every tool still missing (installed
--- tools are skipped, so repeated runs are cheap). Fails only after trying
--- every tool, and names the ones that failed.
---
--- Changing a pin (`name@version`) on an already-installed package needs a
--- clean slate first: mason refuses to re-link an existing schema
--- ("... is already linked"). Run `:MasonUninstall <name>` in nvim first.
function M.bootstrap()
  require("lazy").load({ plugins = { "mason.nvim" } })
  local registry = require("mason-registry")
  local failed = {}

  for _, entry in ipairs(M.tools) do
    local name, version = entry:match("^([^@]+)@(.+)$")
    name = name or entry
    local found, pkg = pcall(registry.get_package, name)
    if not found then
      failed[#failed + 1] = entry .. " (not in registry)"
      print(("mason: FAILED %s: not in registry"):format(entry))
    elseif not pkg:is_installed() then
      print(("mason: installing %s"):format(entry))
      local ok, err = install_blocking(pkg, version)
      if not ok then
        failed[#failed + 1] = entry
        print(("mason: FAILED %s: %s"):format(entry, err and vim.inspect(err) or "unknown error"))
        if is_release_age_failure(err) then
          print(("mason: %s is blocked by .npmrc min-release-age=14, not by a network or build error."):format(name))
          print(("mason: pin an older release: change \"%s\" to \"%s@<version>\" in M.tools,"):format(entry, name))
          print("mason: or wait until mason's pinned version is older than 14 days.")
        end
      end
    end
  end

  -- Installs started elsewhere (mason-tool-installer at startup) or still in
  -- mason's link/post-install tail are not done when the callback fires; wait
  -- for every tool that is not already marked failed, so install.sh's `+qa`
  -- cannot abort one.
  local pending = {}
  for _, entry in ipairs(M.tools) do
    local name = entry:match("^([^@]+)") or entry
    local ok, pkg = pcall(registry.get_package, name)
    if ok and not pkg:is_installed() and not vim.tbl_contains(failed, entry) then
      pending[#pending + 1] = pkg
    end
  end
  if #pending > 0 then
    vim.wait(INSTALL_TIMEOUT_MS, function()
      for _, pkg in ipairs(pending) do
        if not pkg:is_installed() then
          return false
        end
      end
      return true
    end, 250)
  end

  for _, entry in ipairs(M.tools) do
    local name = entry:match("^([^@]+)") or entry
    local ok, pkg = pcall(registry.get_package, name)
    if not ok or not pkg:is_installed() then
      if not vim.tbl_contains(failed, entry) then
        failed[#failed + 1] = entry
        print(("mason: MISSING %s"):format(entry))
      end
    end
  end

  if #failed > 0 then
    error(("mason bootstrap failed for: %s"):format(table.concat(failed, ", ")))
  end
  print("mason: all tools installed")
end

return M

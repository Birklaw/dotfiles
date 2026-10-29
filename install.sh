#!/bin/bash
#
# Dotfiles installer — safe to run multiple times, on host or in container.
#
# Usage:
#   ./install.sh           # apply (with backups)
#   ./install.sh --dry-run # preview changes without applying
#   ./install.sh --unlink  # remove symlinks created by this script
#
# Design principles:
#   - Never overwrite an existing file without backing it up first.
#   - Idempotent: re-running is safe and produces no extra symlinks.
#   - Container-aware: works on Fedora VM ($USER=$USER) and in DevPod
#     containers ($USER=vscode, $HOME=/home/vscode).
#   - Dry-run mode for previewing changes.

set -euo pipefail

# ---------- config ----------
MODE="apply"
case "${1:-}" in
  --dry-run|-n) MODE="dry-run" ;;
  --unlink|-u)  MODE="unlink" ;;
  --help|-h)
    sed -n '2,12p' "$0"
    exit 0
    ;;
  "") ;;
  *) echo "Unknown option: $1. Use --help for usage." >&2; exit 1 ;;
esac

# ---------- locate dotfiles repo ----------
# DevPod clones dotfiles to ~/.dotfiles by default; fall back to script dir.
# DOTFILES_DIR may be set explicitly (dev-env-template's bootstrap pins the
# checkout it just synced, so a stale ~/.dotfiles cannot be applied instead).
if [[ -n "${DOTFILES_DIR:-}" ]]; then
  : # explicit override, keep it
elif [[ -d "$HOME/.dotfiles" ]]; then
  DOTFILES_DIR="$HOME/.dotfiles"
elif [[ -f "$HOME/dotfiles/install.sh" ]]; then
  DOTFILES_DIR="$HOME/dotfiles"
else
  # Last resort: assume script is run from the repo root
  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

echo "==> Dotfiles source: $DOTFILES_DIR"
echo "==> Target \$HOME:    $HOME"
echo "==> Mode:             $MODE"
echo

# ---------- helpers ----------
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# DevPod tags its containers with DEVPOD / DEVPOD_WORKSPACE_ID; several links
# below are host-only, so detect it once instead of per block.
is_devpod() {
  [[ -n "${DEVPOD:-}" || -n "${DEVPOD_WORKSPACE_ID:-}" ]]
}

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/$(basename "$target")"
    echo "    [backup] $target -> $BACKUP_DIR/$(basename "$target")"
  fi
}

link_file() {
  local source="$1"
  local target="$2"

  # Source must exist
  if [[ ! -e "$source" ]]; then
    echo "    [skip]   source missing: $source"
    return 0
  fi

  # Already a correct symlink — nothing to do
  if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
    echo "    [ok]     $target (already linked)"
    return 0
  fi

  # Target exists and is NOT a symlink — back it up
  if [[ -e "$target" && ! -L "$target" ]]; then
    if [[ "$MODE" == "dry-run" ]]; then
      echo "    [would-backup] $target"
    else
      backup_if_exists "$target"
    fi
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    echo "    [would-link]  $target -> $source"
  else
    mkdir -p "$(dirname "$target")"
    ln -sf "$source" "$target"
    echo "    [linked]  $target -> $source"
  fi
}

unlink_file() {
  local target="$1"
  if [[ -L "$target" ]]; then
    local source
    source="$(readlink "$target")"
    # Only unlink if it points into our dotfiles repo
    if [[ "$source" == "$DOTFILES_DIR"* ]]; then
      if [[ "$MODE" == "dry-run" ]]; then
        echo "    [would-unlink] $target"
      else
        rm "$target"
        echo "    [unlinked] $target"
      fi
    else
      echo "    [skip]   $target (not our symlink: $source)"
    fi
  fi
}

# ---------- dotfile definitions ----------
# Format: "source_path:target_path"
# Use $HOME for target to make it portable across VM and container.

HOME_DOTFILES=(
  ".npmrc:$HOME/.npmrc"
  ".tmux.conf:$HOME/.tmux.conf"
  ".vimrc:$HOME/.vimrc"
)

CONFIG_DOTFILES=(
  "pnpm.config.yaml:$HOME/.config/pnpm/config.yaml"
  "uv.toml:$HOME/.config/uv/uv.toml"
  "herdr/config.toml:$HOME/.config/herdr/config.toml"
  "nvim:$HOME/.config/nvim"
)

# Pi agent config. AGENTS.md carries cross-cutting operating behaviours that
# complement the skill packs installed by dev-env-template.
PI_DOTFILES=(
  "pi/AGENTS.md:$HOME/.pi/agent/AGENTS.md"
  "pi/prompts/evaluate-review.md:$HOME/.pi/agent/prompts/evaluate-review.md"
)

# Host-only Pi config: entries that only make sense where Pi itself runs on the
# machine, not in a workspace container.
#
# `pi/mcp.json` registers the chrome-devtools MCP server: headless Chromium on
# this machine, --isolated profile, --allowedUrlPattern restricted to
# localhost/127.0.0.1 (plus about:), network headers redacted, and a pinned
# server version. That is the "hardened host flow": browser testing happens
# from the host against the workspace's forwarded dev-server port, while the
# app keeps running inside the container.
#
# DevPod applies these dotfiles *inside every container*. There is no browser
# there, and the point of the split is that container-side agents do not reach
# the host's forwarded ports — an MCP entry would just fail to launch on every
# session. Hence: host-only.
PI_HOST_DOTFILES=(
  "pi/mcp.json:$HOME/.pi/agent/mcp.json"
)

# ---------- apply ----------
if [[ "$MODE" == "unlink" ]]; then
  echo "==> Removing dotfile symlinks..."
  for entry in "${HOME_DOTFILES[@]}" "${CONFIG_DOTFILES[@]}" "${PI_DOTFILES[@]}" "${PI_HOST_DOTFILES[@]}"; do
    target="${entry##*:}"
    unlink_file "$target"
  done
  echo
  echo "==> Done. Original files (if any) are in: $BACKUP_DIR"
  exit 0
fi

echo "==> Linking dotfiles..."
for entry in "${HOME_DOTFILES[@]}"; do
  source="${entry%%:*}"
  target="${entry##*:}"
  link_file "$DOTFILES_DIR/$source" "$target"
done

echo
echo "==> Linking config files..."
for entry in "${CONFIG_DOTFILES[@]}"; do
  source="${entry%%:*}"
  target="${entry##*:}"
  link_file "$DOTFILES_DIR/$source" "$target"
done

echo
echo "==> Linking Pi config..."
for entry in "${PI_DOTFILES[@]}"; do
  source="${entry%%:*}"
  target="${entry##*:}"
  link_file "$DOTFILES_DIR/$source" "$target"
done

if is_devpod; then
  echo
  echo "==> Skipping host-only Pi config (browser testing) inside this DevPod workspace."
else
  echo
  echo "==> Linking host-only Pi config..."
  for entry in "${PI_HOST_DOTFILES[@]}"; do
    source="${entry%%:*}"
    target="${entry##*:}"
    link_file "$DOTFILES_DIR/$source" "$target"
  done
  # The chrome-devtools entry launches the distro browser at a fixed path.
  # dev-env-template's bootstrap installs it; flag it if this host lacks it so
  # the MCP failure is explained here rather than mid-session.
  if [[ "$MODE" == "apply" ]] && [[ ! -x /usr/bin/chromium ]]; then
    echo "    [warn]   /usr/bin/chromium is missing: chrome-devtools MCP will fail to launch."
    echo "             Run dev-env-template's bootstrap, or point --executablePath in"
    echo "             ~/.pi/agent/mcp.json at an installed Chrome/Chromium."
  fi
fi

echo
if [[ "$MODE" == "dry-run" ]]; then
  echo "==> Dry run complete. No changes made. Re-run without --dry-run to apply."
else
  echo "==> Done. Backups (if any) are in: $BACKUP_DIR"
fi

# ---------- Neovim (LazyVim) headless bootstrap ----------
# Installs lazy.nvim plugins and Mason LSP servers/formatters (headless).
# Skip with SKIP_NVIM_BOOTSTRAP=1.
# Deliberately NOT MasonToolsInstallSync
if [[ "$MODE" == "apply" && "${SKIP_NVIM_BOOTSTRAP:-0}" != "1" ]] && command -v nvim &>/dev/null; then
  NVIM_BOOTSTRAP_TIMEOUT="${NVIM_BOOTSTRAP_TIMEOUT:-1800}"
  echo
  echo "==> Bootstrapping Neovim plugins (headless; ${NVIM_BOOTSTRAP_TIMEOUT}s bound)..."
  timeout --kill-after=10 "$NVIM_BOOTSTRAP_TIMEOUT" \
  nvim --headless "+Lazy! sync" '+lua require("mason-tools").bootstrap()' +qa \
  || echo "[warn] Neovim bootstrap failed or hit the ${NVIM_BOOTSTRAP_TIMEOUT}s bound; it retries on the next devpod up / first nvim launch"
fi

# ---------- GitHub credentials (DevPod workspaces only) ----------
# DevPod injects a git credential helper that forwards credential prompts to
# the host. For github.com, reset that inherited helper chain (the empty
# value clears it) and use the built-in `store` helper instead, so a
# fine-grained PAT can be entered once and is then read from
# ~/.git-credentials. All other hosts keep DevPod's forwarding.
# --replace-all keeps the pair idempotent, matching this script's contract of
# being safe to run repeatedly: a plain `git config` set would fail on a
# second run ("cannot overwrite multiple values" once the key is multi-valued).
# DevPod-only on purpose: on the host these lines would reroute github.com
# credentials into plaintext ~/.git-credentials.
if [[ "$MODE" == "apply" ]] && command -v git &>/dev/null && is_devpod; then
  git config --global --replace-all credential.https://github.com.helper ""
  git config --global --add credential.https://github.com.helper store
  echo
  echo "==> GitHub: credential helper set to 'store' for https://github.com (other hosts keep DevPod's forwarding)"
  if grep -Eq '^https://[^:]+:[^@]+@github\.com' "$HOME/.git-credentials" 2>/dev/null; then
    echo "    [ok]     GitHub credentials already stored in ~/.git-credentials"
  else
    cat <<'EOF'
    One manual step left (needed once per workspace): store your GitHub credentials.

      1. Create a fine-grained PAT with "Contents: Read and write" on the
         repo(s) you will work on here:
         https://github.com/settings/personal-access-tokens/new
      2. Run any authenticated git command, e.g.:
           git ls-remote https://github.com/<owner>/<repo>
         When prompted: username = your GitHub username, password = the PAT.

    Git saves the credentials to ~/.git-credentials (plaintext, workspace-local)
    and won't prompt again. GitHub operations needing auth fail until then.
EOF
  fi
fi

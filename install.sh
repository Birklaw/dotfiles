#!/bin/bash
#
# Dotfiles installer — safe to run multiple times, on host or in container.
#
# Usage:
#   ./setup.sh           # apply (with backups)
#   ./setup.sh --dry-run # preview changes without applying
#   ./setup.sh --unlink  # remove symlinks created by this script
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
if [[ -d "$HOME/.dotfiles" ]]; then
  DOTFILES_DIR="$HOME/.dotfiles"
elif [[ -f "$HOME/dotfiles/setup.sh" ]]; then
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
  "nvim:$HOME/.config/nvim"
)

# ---------- apply ----------
if [[ "$MODE" == "unlink" ]]; then
  echo "==> Removing dotfile symlinks..."
  for entry in "${HOME_DOTFILES[@]}" "${CONFIG_DOTFILES[@]}"; do
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
if [[ "$MODE" == "dry-run" ]]; then
  echo "==> Dry run complete. No changes made. Re-run without --dry-run to apply."
else
  echo "==> Done. Backups (if any) are in: $BACKUP_DIR"
fi

# ---------- Neovim (LazyVim) headless bootstrap ----------
# Installs lazy.nvim plugins and Mason LSP servers/formatters (headless).
# Skip with SKIP_NVIM_BOOTSTRAP=1.
if [[ "$MODE" == "apply" && "${SKIP_NVIM_BOOTSTRAP:-0}" != "1" ]] && command -v nvim &>/dev/null; then
  echo
  echo "==> Bootstrapping Neovim plugins (headless)..."
  nvim --headless "+Lazy! sync" +qa \
    || echo "    [warn] Lazy sync failed; first nvim launch will retry"
  nvim --headless "+MasonToolsInstallSync" +qa 2>/dev/null \
    || nvim --headless "+MasonUpdate" +qa \
    || echo "    [warn] Mason tool install skipped; first nvim launch will auto-install"
fi

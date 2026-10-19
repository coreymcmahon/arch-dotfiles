#!/usr/bin/env bash
# Fresh-machine bootstrap: clone this repository over HTTPS (no SSH keys
# needed) and hand over to install.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/coreymcmahon/arch-dotfiles/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --dry-run
#
# Environment overrides: DOTFILES_REPO, DOTFILES_DIR
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/coreymcmahon/arch-dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/Code/coreymcmahon/arch-dotfiles}"

if (( EUID == 0 )); then
  echo "ERROR: run bootstrap.sh as your regular user, not root." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "==> git not found; installing (full upgrade to avoid a partial upgrade)"
  sudo pacman -Syu --needed --noconfirm git
fi

if [[ -d "$DOTFILES_DIR/.git" ]]; then
  echo "==> $DOTFILES_DIR already exists; not re-cloning."
else
  echo "==> Cloning $DOTFILES_REPO -> $DOTFILES_DIR"
  mkdir -p -- "$(dirname -- "$DOTFILES_DIR")"
  git clone -- "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

exec "$DOTFILES_DIR/install.sh" "$@"

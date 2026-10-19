#!/usr/bin/env bash
# Stage: dotfiles
# Symlink configuration groups into $HOME with GNU Stow.
#
#   stages/50-dotfiles.sh            stow everything in packages/stow.txt
#   stages/50-dotfiles.sh hypr nvim  stow only the named groups
#
# Existing files are never overwritten. Untouched /etc/skel defaults are moved
# aside automatically; anything else is reported and left in place unless
# BACKUP_CONFLICTS=1 (install.sh --backup-conflicts).
# shellcheck source=lib/stow.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/stow.sh"
install_traps

have stow || [[ "$DRY_RUN" == 1 ]] || die "stow is not installed. Run: $DOTFILES_DIR/install.sh --stage system"

if (( $# )); then
  packages=("$@")
else
  mapfile -t packages < <(read_package_list "$PACKAGES_DIR/stow.txt")
fi
(( ${#packages[@]} )) || die "No stow packages selected."

# Pre-create ~/.config so Stow links individual app directories into it
# instead of turning ~/.config itself into a symlink into this repo.
run mkdir -p -- "$STOW_TARGET/.config"

failed=()
for pkg in "${packages[@]}"; do
  stow_package "$pkg" || failed+=("$pkg")
done

# Create ~/Documents, ~/Pictures (hyprshot's default save dir) etc. if missing.
if have xdg-user-dirs-update; then
  run xdg-user-dirs-update
fi

if (( ${#failed[@]} )); then
  error "Conflicts prevented stowing: ${failed[*]}"
  info "Resolve the files listed above, then rerun: $DOTFILES_DIR/install.sh --stage dotfiles ${failed[*]}"
  exit 1
fi

ok "Dotfiles stage complete."

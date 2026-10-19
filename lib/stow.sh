#!/usr/bin/env bash
# GNU Stow helpers: conflict detection, safe backups and (re)stowing.
# Sourced by stages/50-dotfiles.sh (and the tests).

# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

STOW_TARGET="${STOW_TARGET:-$HOME}"
SKEL_DIR="${SKEL_DIR:-/etc/skel}"
BACKUP_CONFLICTS="${BACKUP_CONFLICTS:-0}"
BACKUP_ROOT="${BACKUP_ROOT:-$STOW_TARGET/.dotfiles-backup}"
_BACKUP_DIR=''

_resolve() { readlink -f -- "$1" 2>/dev/null || true; }

# Print every target path that would stop `stow PKG` from succeeding: a file
# that exists and is not already a symlink into this package. Folded
# directories (e.g. ~/.config/hypr -> repo) are handled by resolving paths.
stow_conflicts() {
  local pkg=$1 pkgdir="$DOTFILES_DIR/$1" f rel target
  while IFS= read -r -d '' f; do
    rel="${f#"$pkgdir"/}"
    target="$STOW_TARGET/$rel"
    [[ -e "$target" || -L "$target" ]] || continue
    [[ "$(_resolve "$target")" == "$(_resolve "$f")" ]] && continue
    printf '%s\n' "$target"
  done < <(find "$pkgdir" -type f -print0 | sort -z)
}

# True when TARGET is byte-identical to the default copied from /etc/skel,
# i.e. not a file the user ever modified.
is_untouched_skel_file() {
  local target=$1 rel="${1#"$STOW_TARGET"/}"
  [[ -f "$target" && ! -L "$target" && -f "$SKEL_DIR/$rel" ]] || return 1
  cmp -s -- "$target" "$SKEL_DIR/$rel"
}

# Move TARGET into a timestamped backup directory, preserving its relative path.
backup_target() {
  local target=$1 rel="${1#"$STOW_TARGET"/}" dest
  if [[ -z "$_BACKUP_DIR" ]]; then
    _BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  fi
  dest="$_BACKUP_DIR/$rel"
  info "Backing up $target -> $dest"
  run mkdir -p -- "$(dirname -- "$dest")"
  run mv -- "$target" "$dest"
}

# Stow one package. Returns 0 on success, 1 when conflicts were left in place.
stow_package() {
  local pkg=$1 pkgdir="$DOTFILES_DIR/$1" target
  local -a conflicts unresolved=()
  [[ -d "$pkgdir" ]] || { error "No such stow package: $pkg ($pkgdir)"; return 1; }

  mapfile -t conflicts < <(stow_conflicts "$pkg")
  for target in "${conflicts[@]}"; do
    if is_untouched_skel_file "$target"; then
      info "$target is an unmodified /etc/skel default"
      backup_target "$target"
    elif [[ "$BACKUP_CONFLICTS" == 1 ]]; then
      backup_target "$target"
    else
      unresolved+=("$target")
    fi
  done

  if (( ${#unresolved[@]} )); then
    error "Not stowing '$pkg': existing files would be overwritten:"
    for target in "${unresolved[@]}"; do info "  $target"; done
    info "Review/merge them manually, or rerun with --backup-conflicts to move them to $BACKUP_ROOT/."
    return 1
  fi

  log "Stowing $pkg -> $STOW_TARGET"
  # --restow re-links an already stowed package and prunes stale links, so
  # reruns are idempotent.
  run stow --restow --dir "$DOTFILES_DIR" --target "$STOW_TARGET" "$pkg"
}

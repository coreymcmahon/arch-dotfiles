#!/usr/bin/env bash
# Stage: development
# Docker, mise and the language runtimes it manages (Node.js, PHP, Go), plus
# the libraries needed to compile PHP from source.
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
install_traps
require_not_root

pacman_install_from "$PACKAGES_DIR/development.txt"

# --- mise runtimes ------------------------------------------------------------
# Each tool is installed once. Reruns do not rebuild "latest"; use
# `mise upgrade` to move to newer versions deliberately.
MISE_TOOLS=(node@lts php@latest go@latest)

mise_tool_installed() {
  local tool=$1
  [[ -n "$(mise ls --installed "$tool" 2>/dev/null)" ]]
}

if have mise || [[ "$DRY_RUN" == 1 ]]; then
  for spec in "${MISE_TOOLS[@]}"; do
    tool="${spec%%@*}"
    if have mise && mise_tool_installed "$tool"; then
      info "mise: $tool already installed ($(mise ls --installed "$tool" 2>/dev/null | awk 'NR==1{print $2}'))."
      # Make sure it is still pinned globally (cheap, idempotent).
      run mise use --global --yes "$spec"
    else
      log "mise: installing $spec"
      [[ "$tool" == php ]] && info "PHP is compiled from source by mise (vfox-php); this takes a while."
      run mise use --global --yes "$spec"
    fi
  done
else
  die "mise is not installed (it is in packages/development.txt)."
fi

ok "Development stage complete."
info "Open a new shell so mise is activated via ~/.bashrc, then verify with: mise ls"

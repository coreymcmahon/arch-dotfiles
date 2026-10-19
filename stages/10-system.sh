#!/usr/bin/env bash
# Stage: system
# Full system upgrade plus the baseline CLI toolset from the official repos.
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
install_traps
require_not_root

pacman_upgrade
pacman_install_from "$PACKAGES_DIR/system.txt"

ok "System stage complete."

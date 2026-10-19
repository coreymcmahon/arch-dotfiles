#!/usr/bin/env bash
# Stage: aur
# Build yay (as the regular user) and install the AUR package inventory.
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
install_traps
require_not_root

ensure_yay
aur_install_from "$PACKAGES_DIR/aur.txt"

ok "AUR stage complete."

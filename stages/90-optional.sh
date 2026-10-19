#!/usr/bin/env bash
# Stage: optional (not part of the default run)
# Nice-to-have official packages from packages/optional.txt.
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
install_traps
require_not_root

pacman_install_from "$PACKAGES_DIR/optional.txt"

ok "Optional stage complete."

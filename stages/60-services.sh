#!/usr/bin/env bash
# Stage: services
# Enable system/user services and group membership for the installed stack.
# Networking (NetworkManager), the bootloader and encryption set up by
# archinstall are left untouched.
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
install_traps
require_not_root

pkg_installed() {
  if have pacman; then
    pacman -Qq "$1" >/dev/null 2>&1
  else
    [[ "$DRY_RUN" == 1 ]]   # dry run on a non-Arch host: assume installed
  fi
}

# --- Docker -------------------------------------------------------------------
if pkg_installed docker; then
  log "Docker"
  enable_system_service docker.service
  if user_in_group "$USER" docker; then
    info "$USER is already in the docker group."
  else
    run_sudo usermod -aG docker "$USER"
    warn "Added $USER to the docker group; log out and back in for it to take effect."
  fi
else
  info "docker not installed; skipping (run the development stage first)."
fi

# --- Bluetooth (Waybar module, blueberry) --------------------------------------
if pkg_installed bluez; then
  log "Bluetooth"
  enable_system_service bluetooth.service
else
  info "bluez not installed; skipping bluetooth.service."
fi

# --- PipeWire user session ----------------------------------------------------
# archinstall's PipeWire profile normally enables these via presets; this only
# fills gaps and never disables anything.
if pkg_installed pipewire; then
  log "PipeWire (user units)"
  for unit in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    enable_user_service "$unit"
  done
fi

ok "Services stage complete."

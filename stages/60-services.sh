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

# --- Login greeter (greetd + tuigreet on tty1) ---------------------------------
# The config is installed from the repo; greetd is enabled but NOT started now so
# the current TTY session is not replaced mid-install. It takes over tty1 on the
# next boot. GREETD_CONFIG/GREETD_PAM are overridable for tests.
GREETD_CONFIG=${GREETD_CONFIG:-/etc/greetd/config.toml}
GREETD_PAM=${GREETD_PAM:-/etc/pam.d/greetd}
if pkg_installed greetd; then
  log "greetd (login greeter)"
  if cmp -s "$DOTFILES_DIR/etc/greetd/config.toml" "$GREETD_CONFIG" 2>/dev/null; then
    info "$GREETD_CONFIG already up to date."
  else
    run_sudo install -Dm644 "$DOTFILES_DIR/etc/greetd/config.toml" "$GREETD_CONFIG"
  fi
  if have systemctl && systemctl is-enabled --quiet greetd.service 2>/dev/null; then
    info "greetd.service already enabled."
  else
    run_sudo systemctl enable greetd.service
    warn "greetd.service enabled; it starts on tty1 at next boot (if it fails, log in on tty2)."
  fi
else
  info "greetd not installed; skipping (run the desktop stage first)."
fi

# --- Keyring (gnome-keyring unlocked by PAM at login, gcr SSH agent) ------------
if pkg_installed gnome-keyring; then
  log "gnome-keyring"
  if [[ -f "$GREETD_PAM" ]] || [[ "$DRY_RUN" == 1 ]]; then
    if grep -qs pam_gnome_keyring "$GREETD_PAM"; then
      info "pam_gnome_keyring already configured in $GREETD_PAM."
    else
      # Appended after the system-local-login includes so the password is already
      # available to unlock the login keyring.
      printf '%s\n' \
        'auth       optional     pam_gnome_keyring.so' \
        'session    optional     pam_gnome_keyring.so auto_start' \
        | run_sudo tee -a "$GREETD_PAM"
    fi
  else
    warn "$GREETD_PAM not found; install greetd first so the keyring can be unlocked at login."
  fi
  enable_user_service gcr-ssh-agent.socket
fi

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

# --- Backlight access (swayosd brightness keys) --------------------------------
# swayosd ships udev rules that let members of "video" write /sys/class/backlight.
if pkg_installed swayosd; then
  log "Backlight (video group)"
  if user_in_group "$USER" video; then
    info "$USER is already in the video group."
  else
    run_sudo usermod -aG video "$USER"
    warn "Added $USER to the video group; log out and back in for it to take effect."
  fi
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

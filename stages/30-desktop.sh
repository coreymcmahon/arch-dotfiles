#!/usr/bin/env bash
# Stage: desktop
# Hyprland, Waybar, Walker, fonts, notifications, Wayland utilities and the
# GPU driver stack matching the detected hardware.
# shellcheck source=lib/common.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/common.sh"
install_traps
require_not_root

# --- GPU drivers --------------------------------------------------------------
log "Detecting GPU vendor"
mapfile -t vendors < <(detect_gpu_vendors)
gpu_pkgs=()
if (( ${#vendors[@]} == 0 )); then
  warn "No PCI display controller detected; installing mesa only. Override with GPU_VENDORS=amd|intel|nvidia."
  vendors=(virtual)
fi
for v in "${vendors[@]}"; do
  case "$v" in
    amd)     info "AMD GPU detected"; gpu_pkgs+=("$PACKAGES_DIR/gpu-amd.txt") ;;
    intel)   info "Intel GPU detected"; gpu_pkgs+=("$PACKAGES_DIR/gpu-intel.txt") ;;
    nvidia)
      info "NVIDIA GPU detected"
      gpu_pkgs+=("$PACKAGES_DIR/gpu-nvidia.txt")
      warn "nvidia-open-dkms supports Turing (GTX 16xx/RTX 20xx) and newer. Older cards need an AUR legacy driver; see README."
      warn "Hyprland on NVIDIA needs extra environment variables; see the 'GPU drivers' section of the README."
      ;;
    virtual) info "Virtual/unknown display controller; using mesa only"; gpu_pkgs+=("$PACKAGES_DIR/gpu-virtual.txt") ;;
    *)       warn "Unrecognised GPU vendor '$v'; installing mesa only"; gpu_pkgs+=("$PACKAGES_DIR/gpu-virtual.txt") ;;
  esac
done
mapfile -t gpu_list < <(read_package_list "${gpu_pkgs[@]}")
if [[ " ${vendors[*]} " == *" nvidia "* ]]; then
  # DKMS needs headers for every installed kernel.
  mapfile -t headers < <(kernel_headers_packages)
  if (( ${#headers[@]} == 0 )); then
    warn "Could not determine installed kernel; defaulting to linux-headers."
    headers=(linux-headers)
  fi
  gpu_list+=("${headers[@]}")
fi
pacman_install "${gpu_list[@]}"

# --- Desktop packages ---------------------------------------------------------
pacman_install_from "$PACKAGES_DIR/desktop.txt"

# Walker and its elephant backend live in the AUR; they are listed in
# packages/aur.txt and installed by the aur stage. Remind if that was skipped.
if ! have walker && [[ "$DRY_RUN" != 1 ]]; then
  warn "walker is not installed yet; run './install.sh --stage aur' for Walker/elephant."
fi

ok "Desktop stage complete."

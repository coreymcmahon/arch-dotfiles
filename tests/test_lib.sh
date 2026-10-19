#!/usr/bin/env bash
# lib/common.sh behaviour with stubbed pacman/yay/systemctl.
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

load_lib() { unset __ARCH_DOTFILES_COMMON_LOADED; source "$REPO_DIR/lib/common.sh"; }

test_missing_packages_respects_installed_and_provides() {
  load_lib
  export STUB_INSTALLED="git curl"
  assert_eq "wget" "$(missing_packages git curl wget)"
  assert_eq "" "$(missing_packages git)"
}

test_pacman_install_only_installs_missing_and_uses_syu_then_s() {
  load_lib
  export STUB_INSTALLED="git"
  PACMAN_SYNCED=0
  pacman_install git wget >/dev/null
  pacman_install git stow >/dev/null
  pacman_install git >/dev/null
  local installs
  installs=$(grep '^sudo pacman -S' "$STUB_LOG")
  assert_eq $'sudo pacman -Syu --needed --noconfirm wget\nsudo pacman -S --needed --noconfirm stow' "$installs"
  assert_not_contains "$(cat "$STUB_LOG")" " -Sy " "partial upgrade flag"
}

test_pacman_install_interactive_drops_noconfirm() {
  load_lib
  NOCONFIRM=0
  pacman_install wget >/dev/null
  assert_contains "$(cat "$STUB_LOG")" "sudo pacman -Syu --needed wget"
  assert_not_contains "$(cat "$STUB_LOG")" "--noconfirm"
}

test_pacman_install_dry_run_never_calls_sudo() {
  load_lib
  DRY_RUN=1
  capture pacman_install wget
  assert_contains "$OUT" "[dry-run] sudo pacman -Syu --needed --noconfirm wget"
  assert_not_contains "$(cat "$STUB_LOG")" "sudo"
}

test_aur_install_skips_installed_and_never_uses_sudo() {
  load_lib
  export STUB_INSTALLED="walker-bin"
  aur_install walker-bin blueberry >/dev/null
  assert_eq "yay -S --needed --noconfirm --answerdiff None --answerclean None --removemake blueberry" "$(grep '^yay -S' "$STUB_LOG")"
  assert_not_contains "$(cat "$STUB_LOG")" "sudo yay"
}

test_ensure_yay_noop_when_present() {
  load_lib
  ensure_yay >/dev/null
  assert_not_contains "$(cat "$STUB_LOG")" "makepkg"
}

test_gpu_detection_from_sysfs() {
  load_lib
  local sys="$SANDBOX/pci"
  mkdir -p "$sys"/{a,b,c,d}
  printf '0x030000\n' >"$sys/a/class"; printf '0x1002\n' >"$sys/a/vendor"   # AMD GPU
  printf '0x020000\n' >"$sys/b/class"; printf '0x10de\n' >"$sys/b/vendor"   # NVIDIA *network* card: ignored
  printf '0x030200\n' >"$sys/c/class"; printf '0x10de\n' >"$sys/c/vendor"   # NVIDIA 3D controller
  printf '0x030000\n' >"$sys/d/class"; printf '0x1af4\n' >"$sys/d/vendor"   # virtio
  export SYSFS_PCI_DIR="$sys"
  assert_eq $'amd\nnvidia\nvirtual' "$(detect_gpu_vendors)"
  export GPU_VENDORS="intel, nvidia"
  assert_eq $'intel\nnvidia' "$(detect_gpu_vendors)"
  unset GPU_VENDORS SYSFS_PCI_DIR
}

test_enable_system_service_is_idempotent() {
  load_lib
  export STUB_ENABLED="docker.service"
  enable_system_service docker.service >/dev/null
  enable_system_service bluetooth.service >/dev/null
  assert_not_contains "$(cat "$STUB_LOG")" "enable --now docker.service"
  assert_contains "$(cat "$STUB_LOG")" "sudo systemctl enable --now bluetooth.service"
}

test_services_stage_adds_docker_group_once() {
  export STUB_INSTALLED="docker" STUB_GROUPS="wheel"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$(cat "$STUB_LOG")" "sudo usermod -aG docker $USER"
  : >"$STUB_LOG"; export STUB_GROUPS="wheel docker"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_not_contains "$(cat "$STUB_LOG")" "usermod"
}

test_services_stage_adds_video_group_for_swayosd() {
  export STUB_INSTALLED="swayosd" STUB_GROUPS="wheel"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$(cat "$STUB_LOG")" "sudo usermod -aG video $USER"
  : >"$STUB_LOG"; export STUB_GROUPS="wheel video"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_not_contains "$(cat "$STUB_LOG")" "usermod"
}

test_services_stage_configures_greetd_without_starting_it() {
  export STUB_INSTALLED="greetd" GREETD_CONFIG="$SANDBOX/etc/greetd/config.toml" GREETD_PAM="$SANDBOX/etc/pam.d/greetd"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_file "$GREETD_CONFIG"
  assert_contains "$(cat "$GREETD_CONFIG")" "start-hyprland"
  assert_contains "$(cat "$STUB_LOG")" "sudo systemctl enable greetd.service"
  assert_not_contains "$(cat "$STUB_LOG")" "enable --now greetd.service"
  : >"$STUB_LOG"; export STUB_ENABLED="greetd.service"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_not_contains "$(cat "$STUB_LOG")" "install"
  assert_not_contains "$(cat "$STUB_LOG")" "systemctl enable"
}

test_services_stage_adds_keyring_pam_once() {
  export STUB_INSTALLED="gnome-keyring" GREETD_CONFIG="$SANDBOX/etc/greetd/config.toml" GREETD_PAM="$SANDBOX/etc/pam.d/greetd"
  mkdir -p "$SANDBOX/etc/pam.d"
  printf '#%%PAM-1.0\nauth include system-local-login\n' >"$GREETD_PAM"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_eq 1 "$(grep -c 'pam_gnome_keyring.so auto_start' "$GREETD_PAM")"
  assert_contains "$(cat "$STUB_LOG")" "systemctl --user enable --now gcr-ssh-agent.socket"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_eq 1 "$(grep -c 'pam_gnome_keyring.so auto_start' "$GREETD_PAM")"
}

test_services_stage_installs_brave_policies_once() {
  export STUB_INSTALLED="brave-bin" BRAVE_POLICY_FILE="$SANDBOX/etc/brave/policies/managed/policies.json"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_file "$BRAVE_POLICY_FILE"
  assert_contains "$(cat "$BRAVE_POLICY_FILE")" '"BraveRewardsDisabled": true'
  : >"$STUB_LOG"
  capture bash "$REPO_DIR/stages/60-services.sh"
  assert_not_contains "$(cat "$STUB_LOG")" "install"
}

test_development_stage_skips_installed_runtimes() {
  export STUB_INSTALLED="docker mise" STUB_MISE_INSTALLED="node php go"
  capture bash "$REPO_DIR/stages/40-development.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$OUT" "php already installed"
  # Never (re)installs, only (re)pins the global version.
  assert_eq 3 "$(grep -c '^mise use --global --yes' "$STUB_LOG")"
  assert_not_contains "$(cat "$STUB_LOG")" "mise install"
}

run_tests
report

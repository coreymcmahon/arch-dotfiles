#!/usr/bin/env bash
# Shared helpers for the arch-dotfiles installer. Sourced by install.sh and
# every script under stages/; never executed directly.
#
# Conventions:
#   run CMD...       execute CMD, or print it when DRY_RUN=1
#   run_sudo CMD...  same, prefixed with sudo (only for privileged operations)
#   die MSG          print an error and exit 1

[[ -n "${__ARCH_DOTFILES_COMMON_LOADED:-}" ]] && return 0
__ARCH_DOTFILES_COMMON_LOADED=1

set -Eeuo pipefail

# Repository root, regardless of the caller's working directory.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC2034  # used by the scripts that source this file
PACKAGES_DIR="$DOTFILES_DIR/packages"
# shellcheck disable=SC2034
STAGES_DIR="$DOTFILES_DIR/stages"

DRY_RUN="${DRY_RUN:-0}"              # 1: print actions instead of performing them
NOCONFIRM="${NOCONFIRM:-1}"          # 1: pass --noconfirm to pacman/yay
PACMAN_SYNCED="${PACMAN_SYNCED:-0}"  # 1: databases already refreshed in this run
export DOTFILES_DIR DRY_RUN NOCONFIRM

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_BLUE=$'\033[1;34m' C_GREEN=$'\033[1;32m' C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m' C_CYAN=$'\033[0;36m' C_RESET=$'\033[0m'
else
  C_BLUE='' C_GREEN='' C_YELLOW='' C_RED='' C_CYAN='' C_RESET=''
fi

log()   { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s==>%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
info()  { printf '    %s\n' "$*"; }
warn()  { printf '%sWARNING:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
error() { printf '%sERROR:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()   { error "$@"; exit 1; }
dry()   { printf '%s[dry-run]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }

# ---------------------------------------------------------------------------
# Execution wrappers
# ---------------------------------------------------------------------------
run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    dry "$(printf '%q ' "$@")"
    return 0
  fi
  "$@"
}

run_sudo() {
  if (( EUID == 0 )); then run "$@"; else run sudo "$@"; fi
}

have() { command -v "$1" >/dev/null 2>&1; }

is_arch() { [[ -f /etc/arch-release ]]; }

require_not_root() {
  if (( EUID == 0 )); then
    die "Run this as your regular user, not root. makepkg/yay refuse to run as root; sudo is used where needed."
  fi
}

# Keep sudo's timestamp fresh for the lifetime of the calling script so long
# stages (PHP compiles) don't stall on a password prompt.
_SUDO_KEEPALIVE_PID=''
sudo_keepalive() {
  [[ "$DRY_RUN" == 1 ]] && return 0
  (( EUID == 0 )) && return 0
  sudo -v || die "sudo authentication failed."
  (
    while kill -0 "$$" 2>/dev/null; do
      sudo -n true 2>/dev/null || true
      sleep 60
    done
  ) &
  _SUDO_KEEPALIVE_PID=$!
}

# ---------------------------------------------------------------------------
# Cleanup / error traps
# ---------------------------------------------------------------------------
_CLEANUP_PATHS=()
register_cleanup() { _CLEANUP_PATHS+=("$1"); }

_on_exit() {
  local rc=$? p
  [[ -n "$_SUDO_KEEPALIVE_PID" ]] && kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
  for p in "${_CLEANUP_PATHS[@]}"; do
    # Only ever remove temp dirs this script created via mktemp.
    [[ -n "$p" && -d "$p" && "$p" == "${TMPDIR:-/tmp}"/* ]] && rm -rf -- "$p"
  done
  return "$rc"
}

_ERR_REPORTED=0
_on_err() {
  local rc=$1 line=$2 cmd=$3
  # Explicit exits (die, usage errors) already explained themselves, and with
  # set -E the trap fires once per enclosing function: report only once.
  [[ "$cmd" == exit* || "$cmd" == 'return'* ]] && return 0
  (( _ERR_REPORTED )) && return 0
  _ERR_REPORTED=1
  error "Command failed (exit $rc) at ${BASH_SOURCE[1]##*/}:$line: $cmd"
}

install_traps() {
  trap _on_exit EXIT
  # shellcheck disable=SC2154  # $LINENO / $BASH_COMMAND are expanded at trap time
  trap '_on_err $? $LINENO "$BASH_COMMAND"' ERR
}

make_temp_dir() {
  local d
  d=$(mktemp -d "${TMPDIR:-/tmp}/arch-dotfiles.XXXXXX")
  register_cleanup "$d"
  printf '%s\n' "$d"
}

# ---------------------------------------------------------------------------
# Package inventories (packages/*.txt: one or more names per line, # comments)
# ---------------------------------------------------------------------------
read_package_list() {
  local f
  for f in "$@"; do
    [[ -f "$f" ]] || die "Package list not found: $f"
    awk '{ sub(/#.*/, ""); for (i = 1; i <= NF; i++) print $i }' "$f"
  done | awk '!seen[$0]++'   # de-duplicate across lists, keep order
}

# Print the subset of the given packages that is not already satisfied
# (installed directly or via a 'provides'). Prints all of them when pacman
# is unavailable (dry runs on non-Arch hosts).
missing_packages() {
  (( $# )) || return 0
  if ! have pacman; then
    printf '%s\n' "$@"
    return 0
  fi
  local out rc=0
  out=$(pacman -T "$@") || rc=$?
  # pacman -T: exit 0 when everything is satisfied, 127 when it printed missing deps.
  if (( rc != 0 && rc != 127 )); then
    die "pacman -T failed with exit code $rc"
  fi
  [[ -n "$out" ]] && printf '%s\n' "$out"
  return 0
}

_pacman_confirm_flags() {
  [[ "$NOCONFIRM" == 1 ]] && printf '%s\n' --noconfirm
  return 0
}

# Full system upgrade. Always -Syu, never -Sy, to avoid partial upgrades.
pacman_upgrade() {
  log "Refreshing package databases and upgrading the system (pacman -Syu)"
  local -a flags
  mapfile -t flags < <(_pacman_confirm_flags)
  run_sudo pacman -Syu "${flags[@]}"
  PACMAN_SYNCED=1
}

# Install only the packages that are missing. The first install in a run
# piggybacks on a full upgrade (-Syu) so the database is fresh and the
# system is never left partially upgraded.
pacman_install() {
  local -a want=("$@") missing flags
  (( ${#want[@]} )) || return 0
  mapfile -t missing < <(missing_packages "${want[@]}")
  if (( ${#missing[@]} == 0 )); then
    info "All ${#want[@]} official package(s) already installed."
    return 0
  fi
  log "Installing ${#missing[@]} official package(s): ${missing[*]}"
  mapfile -t flags < <(_pacman_confirm_flags)
  if (( PACMAN_SYNCED )); then
    run_sudo pacman -S --needed "${flags[@]}" "${missing[@]}"
  else
    run_sudo pacman -Syu --needed "${flags[@]}" "${missing[@]}"
    PACMAN_SYNCED=1
  fi
}

pacman_install_from() {
  local -a pkgs
  mapfile -t pkgs < <(read_package_list "$@")
  pacman_install "${pkgs[@]}"
}

# ---------------------------------------------------------------------------
# AUR (always as the regular user)
# ---------------------------------------------------------------------------
ensure_yay() {
  if have yay; then
    info "yay already installed ($(yay --version 2>/dev/null | head -n1))"
    return 0
  fi
  require_not_root
  pacman_install base-devel git
  log "Building yay-bin from the AUR (prebuilt binary; avoids a Go toolchain)"
  if [[ "$DRY_RUN" == 1 ]]; then
    dry "git clone https://aur.archlinux.org/yay-bin.git <tmpdir> && makepkg -si --needed"
    return 0
  fi
  local build
  build=$(make_temp_dir)
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$build/yay-bin"
  local -a flags
  mapfile -t flags < <(_pacman_confirm_flags)
  ( cd "$build/yay-bin" && makepkg -si --needed "${flags[@]}" )
  have yay || die "yay build finished but the yay binary was not found."
}

aur_install() {
  local -a want=("$@") missing flags
  (( ${#want[@]} )) || return 0
  require_not_root
  mapfile -t missing < <(missing_packages "${want[@]}")
  if (( ${#missing[@]} == 0 )); then
    info "All ${#want[@]} AUR package(s) already installed."
    return 0
  fi
  have yay || [[ "$DRY_RUN" == 1 ]] || die "yay is not installed. Run: $DOTFILES_DIR/install.sh --stage aur"
  log "Installing ${#missing[@]} AUR package(s): ${missing[*]}"
  mapfile -t flags < <(_pacman_confirm_flags)
  # --answerdiff/--answerclean suppress yay's interactive prompts; pacman still
  # asks for sudo as needed.
  run yay -S --needed "${flags[@]}" --answerdiff None --answerclean None --removemake "${missing[@]}"
}

aur_install_from() {
  local -a pkgs
  mapfile -t pkgs < <(read_package_list "$@")
  aur_install "${pkgs[@]}"
}

# ---------------------------------------------------------------------------
# Hardware
# ---------------------------------------------------------------------------
# Print detected GPU vendors, one per line: amd, intel, nvidia, virtual or
# unknown:<pci-vendor-id>. Override with GPU_VENDORS="amd nvidia" if needed.
detect_gpu_vendors() {
  if [[ -n "${GPU_VENDORS:-}" ]]; then
    tr ' ,' '\n' <<<"$GPU_VENDORS" | awk 'NF' | sort -u
    return 0
  fi
  local sysfs="${SYSFS_PCI_DIR:-/sys/bus/pci/devices}" dev class vendor
  [[ -d "$sysfs" ]] || return 0
  for dev in "$sysfs"/*; do
    [[ -r "$dev/class" && -r "$dev/vendor" ]] || continue
    read -r class < "$dev/class"
    [[ "$class" == 0x03* ]] || continue   # PCI class 0x03: display controller
    read -r vendor < "$dev/vendor"
    case "$vendor" in
      0x1002) echo amd ;;
      0x8086) echo intel ;;
      0x10de) echo nvidia ;;
      0x1af4|0x15ad|0x80ee|0x1234|0x1b36) echo virtual ;;
      *) echo "unknown:$vendor" ;;
    esac
  done | sort -u
}

# Print the headers package for every installed kernel (linux -> linux-headers).
kernel_headers_packages() {
  local f pkgbase
  for f in /usr/lib/modules/*/pkgbase; do
    [[ -r "$f" ]] || continue
    read -r pkgbase < "$f"
    [[ -n "$pkgbase" ]] && echo "${pkgbase}-headers"
  done | sort -u
}

# ---------------------------------------------------------------------------
# systemd helpers (idempotent)
# ---------------------------------------------------------------------------
enable_system_service() {
  local unit=$1
  if ! have systemctl; then
    [[ "$DRY_RUN" == 1 ]] && { dry "sudo systemctl enable --now $unit"; return 0; }
    die "systemctl not available"
  fi
  if systemctl is-enabled --quiet "$unit" 2>/dev/null; then
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
      info "$unit already enabled and running."
    else
      run_sudo systemctl start "$unit"
    fi
  else
    run_sudo systemctl enable --now "$unit"
  fi
}

enable_user_service() {
  local unit=$1
  if ! have systemctl; then
    [[ "$DRY_RUN" == 1 ]] && { dry "systemctl --user enable --now $unit"; return 0; }
    die "systemctl not available"
  fi
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "No systemd user session available; skipping user unit $unit (log in normally and rerun the services stage)."
    return 0
  fi
  if systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
    info "$unit (user) already enabled."
  else
    run systemctl --user enable --now "$unit"
  fi
}

user_in_group() {
  local user=$1 group=$2
  id -nG "$user" 2>/dev/null | tr ' ' '\n' | grep -qx "$group"
}

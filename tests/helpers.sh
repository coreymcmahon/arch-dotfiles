#!/usr/bin/env bash
# Minimal assertion helpers for the test suite (no bats dependency).
# shellcheck disable=SC2034  # REPO_DIR/OUT/RC are consumed by the test files

TESTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$TESTS_DIR/.." && pwd)"
STUBS_DIR="$TESTS_DIR/stubs"

_pass=0 _fail=0 _current=''

fail() {
  _fail=$((_fail + 1))
  printf '  FAIL %s: %s\n' "$_current" "$*" >&2
}

assert_eq() {  # expected actual [msg]
  if [[ "$1" == "$2" ]]; then _pass=$((_pass + 1)); else fail "${3:-assert_eq}: expected '$1', got '$2'"; fi
}
assert_contains() {  # haystack needle [msg]
  if [[ "$1" == *"$2"* ]]; then _pass=$((_pass + 1)); else fail "${3:-assert_contains}: '$2' not found in:"$'\n'"$1"; fi
}
assert_not_contains() {
  if [[ "$1" != *"$2"* ]]; then _pass=$((_pass + 1)); else fail "${3:-assert_not_contains}: '$2' unexpectedly found in:"$'\n'"$1"; fi
}
assert_file() { if [[ -e "$1" || -L "$1" ]]; then _pass=$((_pass + 1)); else fail "${2:-assert_file}: $1 does not exist"; fi; }
assert_no_file() { if [[ ! -e "$1" && ! -L "$1" ]]; then _pass=$((_pass + 1)); else fail "${2:-assert_no_file}: $1 exists"; fi; }
assert_symlink() { if [[ -L "$1" ]]; then _pass=$((_pass + 1)); else fail "${2:-assert_symlink}: $1 is not a symlink"; fi; }

# Run a command, capture combined output and exit status into OUT / RC.
capture() {
  local rc=0
  OUT=$("$@" 2>&1) || rc=$?
  RC=$rc
}

# Fresh scratch HOME and stub log for a test.
setup_sandbox() {
  SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/arch-dotfiles-test.XXXXXX")
  export HOME="$SANDBOX/home"
  mkdir -p "$HOME"
  export STUB_LOG="$SANDBOX/stub.log"
  : >"$STUB_LOG"
  export STUB_INSTALLED="" STUB_ENABLED="" STUB_MISE_INSTALLED=""
  export DRY_RUN=0 NOCONFIRM=1 PACMAN_SYNCED=0 BACKUP_CONFLICTS=0
  unset GPU_VENDORS SYSFS_PCI_DIR DOTFILES_DIR SKEL_DIR GREETD_CONFIG GREETD_PAM
  export PATH="$STUBS_DIR:$PATH"
  export NO_COLOR=1
}
teardown_sandbox() { [[ -n "${SANDBOX:-}" && -d "$SANDBOX" ]] && rm -rf -- "$SANDBOX"; }

run_tests() {  # run every function named test_* defined in the caller
  local t
  for t in $(declare -F | awk '$3 ~ /^test_/ {print $3}'); do
    _current=$t
    setup_sandbox
    "$t"
    teardown_sandbox
  done
}

report() {
  printf '%s: %d passed, %d failed\n' "${BASH_SOURCE[1]##*/}" "$_pass" "$_fail"
  (( _fail == 0 ))
}

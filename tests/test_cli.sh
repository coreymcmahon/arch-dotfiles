#!/usr/bin/env bash
# install.sh argument parsing and path handling.
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

test_help() {
  capture "$REPO_DIR/install.sh" --help
  assert_eq 0 "$RC" "exit code"
  assert_contains "$OUT" "Usage:"
  assert_contains "$OUT" "--dry-run"
}

test_list_stages_in_order() {
  capture "$REPO_DIR/install.sh" --list
  assert_eq 0 "$RC"
  local names
  names=$(awk '{print $1}' <<<"$OUT" | tr '\n' ' ')
  assert_eq "system aur desktop development dotfiles services optional " "$names" "stage order"
  # every listed script exists
  while read -r _ path _; do assert_file "$path"; done <<<"$OUT"
}

test_unknown_stage_fails() {
  capture "$REPO_DIR/install.sh" --stage bogus --dry-run
  assert_eq 2 "$RC"
  assert_contains "$OUT" "Unknown stage: bogus"
}

test_unknown_option_fails() {
  capture "$REPO_DIR/install.sh" --frobnicate
  assert_eq 2 "$RC"
  assert_contains "$OUT" "Unknown option"
}

test_from_and_stage_conflict() {
  capture "$REPO_DIR/install.sh" --from desktop --stage aur --dry-run
  assert_eq 1 "$RC"
  assert_contains "$OUT" "cannot be combined"
}

test_dry_run_from_other_directory() {
  # Run from an unrelated cwd via a relative path to prove nothing is cwd-dependent.
  local rel
  rel=$(python3 -c 'import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[1]), os.path.realpath(sys.argv[2])))' "$REPO_DIR/install.sh" "$SANDBOX")
  capture bash -c "cd '$SANDBOX' && '$rel' --dry-run --stage system"
  assert_eq 0 "$RC" "exit code: $OUT"
  assert_contains "$OUT" "[dry-run]"
  assert_contains "$OUT" "pacman -Syu"
  assert_contains "$OUT" "Stage: system"
  assert_contains "$OUT" "All selected stages finished"
}

test_dry_run_all_stages_changes_nothing() {
  export GPU_VENDORS=amd
  capture "$REPO_DIR/install.sh" --dry-run
  assert_eq 0 "$RC" "exit code: $OUT"
  for s in system aur desktop development dotfiles services; do
    assert_contains "$OUT" "Stage: $s"
  done
  # Only read-only commands reached the stubs (pacman -T / -Qq, systemctl is-*, mise ls).
  local mutating
  mutating=$(grep -vE '^(pacman -T|pacman -Qq|systemctl( --user)? (is-enabled|is-active|show-environment)|mise ls|yay --version|id )' "$STUB_LOG" || true)
  assert_eq "" "$mutating" "mutating commands executed during dry run"
  # Nothing was written into HOME.
  assert_eq "" "$(find "$HOME" -mindepth 1 | head -n1)" "HOME untouched"
  unset GPU_VENDORS
}

test_from_resumes_at_stage() {
  export GPU_VENDORS=intel
  capture "$REPO_DIR/install.sh" --dry-run --from dotfiles
  assert_eq 0 "$RC" "$OUT"
  assert_not_contains "$OUT" "Stage: system"
  assert_contains "$OUT" "[1/2] Stage: dotfiles"
  assert_contains "$OUT" "[2/2] Stage: services"
  unset GPU_VENDORS
}

test_stage_failure_reports_resume_command() {
  # Point the dotfiles stage at a package that does not exist to force a failure.
  capture "$REPO_DIR/install.sh" --dry-run --stage dotfiles does-not-exist
  assert_eq 1 "$RC"
  assert_contains "$OUT" "Stage 'dotfiles' failed"
  assert_contains "$OUT" "--from dotfiles"
}

run_tests
report

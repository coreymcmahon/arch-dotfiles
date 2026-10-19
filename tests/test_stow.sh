#!/usr/bin/env bash
# dotfiles stage: real GNU Stow against a fixture repo in a scratch HOME.
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

command -v stow >/dev/null 2>&1 || { echo "test_stow.sh: stow not installed, skipping"; exit 0; }

make_fixture() {
  FIXTURE="$SANDBOX/repo"
  mkdir -p "$FIXTURE/packages" "$FIXTURE/bash" "$FIXTURE/app/.config/app" "$FIXTURE/stages" "$FIXTURE/lib"
  printf 'repo bashrc\n' >"$FIXTURE/bash/.bashrc"
  printf 'repo app conf\n' >"$FIXTURE/app/.config/app/app.conf"
  printf 'bash\napp\n' >"$FIXTURE/packages/stow.txt"
  export DOTFILES_DIR="$FIXTURE"
  export SKEL_DIR="$SANDBOX/skel"
  mkdir -p "$SKEL_DIR"; printf 'skel bashrc\n' >"$SKEL_DIR/.bashrc"
}
stage() { "$REPO_DIR/stages/50-dotfiles.sh" "$@"; }

test_stows_into_empty_home_and_is_idempotent() {
  make_fixture
  capture stage
  assert_eq 0 "$RC" "$OUT"
  assert_symlink "$HOME/.bashrc"
  assert_eq "repo bashrc" "$(cat "$HOME/.bashrc")"
  assert_eq "repo app conf" "$(cat "$HOME/.config/app/app.conf")"
  capture stage
  assert_eq 0 "$RC" "rerun: $OUT"
  assert_contains "$OUT" "Stowing bash"
}

test_single_group_selection() {
  make_fixture
  capture stage app
  assert_eq 0 "$RC" "$OUT"
  assert_no_file "$HOME/.bashrc"
  assert_file "$HOME/.config/app/app.conf"
}

test_user_modified_file_is_reported_not_overwritten() {
  make_fixture
  printf 'my precious edits\n' >"$HOME/.bashrc"
  capture stage
  assert_eq 1 "$RC"
  assert_contains "$OUT" "existing files would be overwritten"
  assert_contains "$OUT" "$HOME/.bashrc"
  assert_contains "$OUT" "--backup-conflicts"
  assert_eq "my precious edits" "$(cat "$HOME/.bashrc")"
  [[ -L "$HOME/.bashrc" ]] && fail "conflicting file was replaced by a symlink"
  # The non-conflicting group was still stowed.
  assert_symlink "$HOME/.config/app"
}

test_untouched_skel_default_is_backed_up_automatically() {
  make_fixture
  cp "$SKEL_DIR/.bashrc" "$HOME/.bashrc"
  capture stage bash
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$OUT" "unmodified /etc/skel default"
  assert_symlink "$HOME/.bashrc"
  local backup
  backup=$(find "$HOME/.dotfiles-backup" -name .bashrc)
  assert_file "$backup"
  assert_eq "skel bashrc" "$(cat "$backup")"
}

test_backup_conflicts_flag_moves_user_file() {
  make_fixture
  printf 'my precious edits\n' >"$HOME/.bashrc"
  mkdir -p "$HOME/.config/app"; printf 'local\n' >"$HOME/.config/app/app.conf"
  BACKUP_CONFLICTS=1 capture stage
  assert_eq 0 "$RC" "$OUT"
  assert_symlink "$HOME/.bashrc"
  assert_eq "my precious edits" "$(cat "$(find "$HOME/.dotfiles-backup" -name .bashrc)")"
  assert_eq "local" "$(cat "$(find "$HOME/.dotfiles-backup" -name app.conf)")"
}

test_existing_correct_symlinks_are_not_conflicts() {
  make_fixture
  mkdir -p "$HOME/.config"
  ln -s "$FIXTURE/bash/.bashrc" "$HOME/.bashrc"          # file link
  ln -s "$FIXTURE/app/.config/app" "$HOME/.config/app"   # folded directory link
  source "$REPO_DIR/lib/stow.sh"
  assert_eq "" "$(stow_conflicts bash)"
  assert_eq "" "$(stow_conflicts app)"
}

test_dry_run_changes_nothing() {
  make_fixture
  printf 'my precious edits\n' >"$HOME/.bashrc"
  DRY_RUN=1 BACKUP_CONFLICTS=1 capture stage
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$OUT" "[dry-run] stow --restow"
  assert_eq "my precious edits" "$(cat "$HOME/.bashrc")"
  assert_no_file "$HOME/.config/app"
  assert_no_file "$HOME/.dotfiles-backup"
}

test_unknown_group_fails_clearly() {
  make_fixture
  capture stage nope
  assert_eq 1 "$RC"
  assert_contains "$OUT" "No such stow package: nope"
}

run_tests
report

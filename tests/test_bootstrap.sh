#!/usr/bin/env bash
# bootstrap.sh: HTTPS-style clone (a local path here), no re-clone, hands off to install.sh.
# shellcheck source=tests/helpers.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/helpers.sh"

test_clones_then_reuses_existing_checkout() {
  local origin="$SANDBOX/origin" dest="$SANDBOX/home/Code/coreymcmahon/arch-dotfiles"
  mkdir -p "$origin"
  printf '#!/usr/bin/env bash\necho "install.sh called with: $*"\n' >"$origin/install.sh"
  chmod +x "$origin/install.sh"
  git -C "$origin" init -q && git -C "$origin" add . && git -C "$origin" -c user.email=t@t -c user.name=t commit -qm init

  capture env DOTFILES_REPO="$origin" DOTFILES_DIR="$dest" "$REPO_DIR/bootstrap.sh" --dry-run --stage system
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$OUT" "Cloning"
  assert_contains "$OUT" "install.sh called with: --dry-run --stage system"
  assert_file "$dest/.git"

  capture env DOTFILES_REPO="$origin" DOTFILES_DIR="$dest" "$REPO_DIR/bootstrap.sh"
  assert_eq 0 "$RC" "$OUT"
  assert_contains "$OUT" "already exists; not re-cloning"
}

run_tests
report

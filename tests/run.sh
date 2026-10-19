#!/usr/bin/env bash
# Run the whole test suite plus syntax checks. Needs bash >= 4 and GNU Stow
# (the stow tests are skipped without it). Nothing touches the real $HOME.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." || exit 1

if (( BASH_VERSINFO[0] < 4 )); then
  echo "tests need bash >= 4 (found $BASH_VERSION)" >&2
  exit 1
fi

status=0
echo "==> bash -n syntax check"
for f in install.sh bootstrap.sh lib/*.sh stages/*.sh tests/*.sh tests/stubs/*; do
  bash -n "$f" || { echo "syntax error: $f" >&2; status=1; }
done

if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  shellcheck -x install.sh bootstrap.sh lib/*.sh stages/*.sh tests/*.sh tests/stubs/* || status=1
else
  echo "==> shellcheck not installed; skipping (see README: docker run koalaman/shellcheck)"
fi

for t in tests/test_*.sh; do
  echo "==> $t"
  bash "$t" || status=1
done

(( status == 0 )) && echo "ALL TESTS PASSED" || echo "TESTS FAILED" >&2
exit $status

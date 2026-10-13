#!/bin/bash
# Compile Good.lean and Bad.lean of each case, then elaborate GoodFirst.lean
# and BadFirst.lean against them, once per toolchain. Then do the same for
# the transitive/ test.
# Usage: ./run.sh [toolchain ...]   (names as in ~/.elan/toolchains)
# Each Lean call prints its exit code. Some cases fail on purpose with
# "already contains". If a module that a test imports fails to compile,
# the script skips the test and exits with status 1 at the end.
set -u -o pipefail
cd "$(dirname "$0")"
if [ $# -eq 0 ]; then
  set -- leanprover--lean4---v4.28.0-rc1 leanprover--lean4---v4.31.0 leanprover--lean4---v4.35.0
fi
status=0
ran=0

# compile DIR OUT MODULE: write OUT/MODULE.olean, print the messages.
compile() {
  (cd "$1" && LEAN_PATH="$OLDPWD/$2" "$L" -o "$OLDPWD/$2/$3.olean" "$3.lean" 2>&1) | sed "s/^/  [$3] /"
  local rc=$?
  echo "  [$3] exit $rc"
  if [ $rc -ne 0 ]; then status=1; fi
  return $rc
}

# check DIR OUT MODULE: elaborate MODULE.lean against OUT, print the messages.
check() {
  echo "  $3:"
  (cd "$1" && LEAN_PATH="$OLDPWD/$2" "$L" "$3.lean" 2>&1) | sed 's/^/    /'
  echo "    exit $?"
}

for tc in "$@"; do
  L=~/.elan/toolchains/$tc/bin/lean
  if [ ! -x "$L" ]; then echo "=== $tc: not installed, skipped"; status=1; continue; fi
  echo "=== $($L --version | head -1)"
  ran=1
  for c in cases/*/; do
    c=${c%/}; out=out/$tc/$(basename "$c")
    rm -rf "$out"; mkdir -p "$out"
    echo "--- $(basename "$c")"
    ok=1
    for m in Good Bad; do compile "$c" "$out" $m || ok=0; done
    if [ $ok -eq 0 ]; then echo "  skipped: a module failed to compile"; continue; fi
    for m in GoodFirst BadFirst; do check "$c" "$out" $m; done
  done
  out=out/$tc/transitive
  rm -rf "$out"; mkdir -p "$out"
  echo "--- transitive"
  ok=1
  for m in Clean Shortcut Lib Helpers; do compile transitive "$out" $m || ok=0; done
  if [ $ok -eq 0 ]; then echo "  skipped: a module failed to compile"; continue; fi
  for m in OnlyLib LibFirst HelpersFirst; do check transitive "$out" $m; done
done
if [ $ran -eq 0 ]; then echo "no toolchain ran"; status=1; fi
exit $status

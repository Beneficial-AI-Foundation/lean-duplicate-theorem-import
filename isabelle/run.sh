#!/bin/bash
# Usage: isabelle/run.sh [isabelle]
# Prints the messages of each theory, without the timing lines, then the
# exit code. Warnings start with "###". Warn must print "### control warning". DBC and DCB must succeed. RD must
# fail with "Duplicate fact declaration".
set -o pipefail
cd "$(dirname "$0")"
I=${1:-isabelle}
for t in Warn DBC DCB RD; do
  echo "--- $t"
  $I process -l Pure -o quick_and_dirty -T "$PWD/$t" 2>&1 |
    grep -v -E '^(### theory "|### .* elapsed time|Loading theory)'
  echo "exit $?"
done

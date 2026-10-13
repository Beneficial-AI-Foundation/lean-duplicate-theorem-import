#!/bin/bash
# Usage: rocq/run.sh [coqc]   (tested with Coq 8.20.1)
# The last test must fail with "makes inconsistent assumptions over library A".
set -e
cd "$(dirname "$0")"
C=${1:-coqc}
for m in A B C; do $C -Q . "" $m.v; done
for m in DBC DCB E; do echo "--- $m"; $C -Q . "" $m.v; done
rm -f ./*.vo* ./*.glob ./.*.aux

echo "--- diamond with two compiled versions of A"
d=$(mktemp -d)
echo 'Definition a := 1.' > "$d/A.v"
echo 'Require Import A. Definition b := a.' > "$d/B.v"
echo 'Require Import A. Definition c := a.' > "$d/C.v"
echo 'Require Import B C.' > "$d/D.v"
(cd "$d" && $C -Q . "" A.v && $C -Q . "" B.v &&
  echo 'Definition a := 2.' > A.v && $C -Q . "" A.v && $C -Q . "" C.v &&
  { $C -Q . "" D.v || echo "exit $? (expected)"; })
rm -rf "$d"

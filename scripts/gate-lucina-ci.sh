#!/bin/bash
# Gate "proof inventory and frozen statements". Runs from the repository root with the launcher named by LUCINA_CI (the binary that
# tools/ci/fetch-lucina-ci.sh builds from a pinned commit of the public lucina repository; it is not built from this tree, so a
# change to this repository cannot edit the tool it is checked with).
#   inventory --check: docs/ci/PROOF-MATRIX.md and tools/ci/proof-inventory.tsv are exactly what is on disk, so a proof that is
#                      added, removed or moved changes the list and cannot stay outside CI.
#   spec --check:      no frozen statement of a shipped proof is removed or weakened relative to the base commit (BASE, required: the caller names the
#                      base).
# Stops at the first failing step.
set -euo pipefail
cd "$(dirname "$0")/.."

CI=${LUCINA_CI:?set LUCINA_CI to the lucina-ci binary}
BASE=${BASE:?set BASE to the base commit or ref}

step() {
  local name="$1"
  shift
  echo "gate-lucina-ci: $name"
  if ! "$@"; then
    echo "gate-lucina-ci: $name: FAILED" >&2
    exit 1
  fi
  echo "gate-lucina-ci: $name: ok"
}

step "lucina-ci inventory --check" "$CI" inventory --check
step "lucina-ci spec --check --base $BASE" "$CI" spec --check --base "$BASE"
echo "gate-lucina-ci: all steps ok"

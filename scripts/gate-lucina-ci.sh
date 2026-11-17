#!/bin/bash
# Merge gate "lucina-ci inventory, spec, roles" (.lucina/pipeline.toml). Runs from the repo root on
# the merge candidate. The INSTALLED lucina-ci judges tools/ci/ and docs/ci/, so a branch must not
# edit the tool it is checked with: tools/ci/ is in gate_files and this script names the binary in
# ~/.local/bin, not a path in the tree. Stops at the first failing step.
set -euo pipefail
cd "$(dirname "$0")/.."

CI="$HOME/.local/bin/lucina-ci"

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
step "lucina-ci spec --check --merge-gate" "$CI" spec --check --merge-gate
step "lucina-ci roles --check --merge-gate" "$CI" roles --check --merge-gate
echo "gate-lucina-ci: all steps ok"

#!/usr/bin/env bash
# Runs the proof of src/js/parser/reparse_rules.rs and its mutants. From the repo root on buildhost:
#   verification/reparse/run.sh
# The shipped file and mutants.sh are copied into a directory of their own, so that nothing depends on a path on the machine that
# runs Verus. Verus runs on buildhost2 (`verus-remote`); if buildhost2 does not answer, FALLBACK=1 runs it here under verify-gate.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/reparse-stage.XXXXXX")
trap 'rm -rf "${stage:?}"' EXIT
cp "$root/src/js/parser/reparse_rules.rs" "$root/verification/reparse/mutants.sh" "$stage/"
if [ "${FALLBACK:-0}" = 1 ]; then
    cd "$stage"
    VERUS=$HOME/tools/verus/verus-x86-linux/verus exec "$HOME/.local/bin/verify-gate" -- ./mutants.sh reparse_rules.rs
fi
exec "$HOME/.local/bin/verus-remote" "$stage" ./mutants.sh reparse_rules.rs

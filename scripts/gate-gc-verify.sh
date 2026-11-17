#!/bin/bash
# Merge gate "gc_verify tests" (.lucina/pipeline.toml). Runs from the repo root on the merge
# candidate, debug only: the heap verifier is built for debug assertions and the gate must not
# hide it behind --release.
set -euo pipefail
cd "$(dirname "$0")/.."

BQ="$HOME/.local/bin/bq"
# Every cargo step here is a queued job: the gate can land while the proof and long-suite jobs hold
# the machine. The queue wait counts against timeout_min, so it is bounded by --max-wait.
# CARGO_TARGET_DIR is the caller's when set (agentd does not set it; the shared gate target is then
# used), otherwise the default below.
: "${CARGO_TARGET_DIR:=$HOME/scratch/brim-gate-target}"

step() {
  local label="$1"
  shift
  echo "gate-gc-verify: $label"
  if ! "$BQ" run --class short --max-wait 900 -- env "CARGO_TARGET_DIR=$CARGO_TARGET_DIR" "$@"; then
    echo "gate-gc-verify: $label: FAILED" >&2
    exit 1
  fi
  echo "gate-gc-verify: $label: ok"
}

# Guard 1: the switch this gate exercises lives in the harness; a tree without it would let the gate
# pass while testing nothing.
if ! grep -q BS_GC_VERIFY tests/harness/src/runner.rs; then
  echo "gate would be vacuous: tests/harness/src/runner.rs does not read BS_GC_VERIFY" >&2
  exit 1
fi

# Guard 2: the same for the test262 checkout. The harness indexes the whole test262 suite and loads
# assert.js/sta.js from it for every test it runs, so without the checkout at the pinned commit step
# (c) cannot run at all — and a gate that quietly ran less than it claims proves nothing either.
# The checkout is shared and read-only, outside any worktree; it is gitignored inside the worktree,
# so a per-worktree clone would mean a 375 MB clone per merge. Same commit as install_test262.sh,
# read from the script so the two cannot drift apart.
TEST262_SHA=$(grep -m1 '^TEST262_COMMIT_SHA=' tests/test262/install_test262.sh | cut -d'"' -f2)
TEST262_DIR="${BRIMSTONE_TEST262:-$HOME/opt/test262-$TEST262_SHA}"
if [ ! -d "$TEST262_DIR" ] || [ "$(git -C "$TEST262_DIR" rev-parse HEAD 2>/dev/null || true)" != "$TEST262_SHA" ]; then
  echo "gate would be vacuous: pinned test262 checkout missing or not at the pinned commit" >&2
  echo "  wanted $TEST262_SHA at $TEST262_DIR; see docs/ci/BRIMSTONE-GATE-NOTES.md" >&2
  exit 1
fi

# The harness finds the checkout at the manifest's "test262_repo_path" (tests/test_manifest.jsonc:
# tests/test262/test262, gitignored), so point that path at the shared dir. Created only when
# absent; the shared checkout itself is never written.
if [ ! -e tests/test262/test262 ]; then
  ln -s "$TEST262_DIR" tests/test262/test262
fi

# The verifier's unit tests (src/js/runtime/embed/tests.rs, package brimstone_core); they enable the
# verifier themselves, so they hold in a plain cargo test too — BS_GC_VERIFY is set anyway so the
# run matches the gate's purpose.
step "cargo test -p brimstone_core gc_verify" \
  BS_GC_VERIFY=1 cargo test --quiet -p brimstone_core gc_verify

# (c) The harness over GC-reachable shapes and weak edges, verifier on and a 4096-byte allocation
# window so nearly every allocation crosses a collection. Each entry is the harness filter string,
# a substring of the test path relative to its suite root (tests/harness/src/runner.rs), and with no
# -s it runs that path in every suite that has it: first-party under tests/integration, test262
# under the pinned checkout. The names are the weak-reference and shape-transition directories,
# chosen for what they exercise, not for coverage; measured times are in
# docs/ci/BRIMSTONE-GATE-NOTES.md.
GC_SUBSET=()
# IsHTMLDDA markers: the only objects whose named walk keeps them alive through a transition, and
# the case the weak-edge repair exists for (tests/integration/built-ins/IsHTMLDDA, first-party only).
GC_SUBSET+=("built-ins/IsHTMLDDA")
# First-party regressions, one file per fixed bug: the whole engine under a stress window
# (tests/integration/regression, first-party only).
GC_SUBSET+=("regression")
# Weak map edges: key holds weakly, value strongly; a missed edge frees a live key.
GC_SUBSET+=("built-ins/WeakMap")
# Weak set edges: the value itself is the weak edge.
GC_SUBSET+=("built-ins/WeakSet")
# WeakRef cells: deref/ClearWeakRef, the cells the verifier reports on and repairs.
GC_SUBSET+=("built-ins/WeakRef")
# FinalizationRegistry cells plus the QueuesAsFinalization registry jobs: weak held target with a
# strongly held callback, and the job queue that keeps markers alive.
GC_SUBSET+=("built-ins/FinalizationRegistry")
# Redefining properties: shape and property-table transitions, where the named walks miss edges; the
# largest directory here, so it is also the slowest step.
GC_SUBSET+=("built-ins/Object/defineProperty")

first=1
for filter in "${GC_SUBSET[@]}"; do
  # --reindex on the first run: tests/test_index.json is gitignored and the index has to be built
  # from this tree plus the pinned checkout before the first filter can match anything; it is cheap
  # (~11 s) so it is rebuilt every merge instead of trusted from a stale tree.
  if [ "$first" = 1 ]; then
    first=0
    step "cargo btest --reindex $filter" \
      BS_GC_VERIFY=1 BS_GC_STRESS=4096 cargo btest -- --reindex "$filter"
  else
    step "cargo btest $filter" \
      BS_GC_VERIFY=1 BS_GC_STRESS=4096 cargo btest -- "$filter"
  fi
done

echo "gate-gc-verify: all steps ok ($SECONDS s)"

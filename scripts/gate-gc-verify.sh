#!/bin/bash
# Gate "gc_verify tests". Runs from the repository root, debug only: the heap verifier is built for debug assertions and the gate
# must not hide it behind --release.
set -euo pipefail
cd "$(dirname "$0")/.."

step() {
  local label="$1"
  shift
  echo "gate-gc-verify: $label"
  if ! "$@"; then
    echo "gate-gc-verify: $label: FAILED" >&2
    exit 1
  fi
  echo "gate-gc-verify: $label: ok"
}

# Guard 1: the switch this gate exercises lives in the harness; a tree without it would let the gate pass while testing nothing.
if ! grep -q BS_GC_VERIFY tests/harness/src/runner.rs; then
  echo "gate would be vacuous: tests/harness/src/runner.rs does not read BS_GC_VERIFY" >&2
  exit 1
fi

# Guard 2: the same for the test262 checkout. The harness indexes the whole test262 suite and loads assert.js/sta.js from it for
# every test it runs, so without the checkout at the pinned commit step (c) cannot run at all, and a gate that quietly ran less than
# it claims proves nothing. tools/ci/fetch-test262.sh puts it at tests/test262/test262.
TEST262_SHA=$(grep -m1 '^TEST262_COMMIT_SHA=' tests/test262/install_test262.sh | cut -d'"' -f2)
if [ ! -d tests/test262/test262 ] || [ "$(git -C tests/test262/test262 rev-parse HEAD 2>/dev/null || true)" != "$TEST262_SHA" ]; then
  echo "gate would be vacuous: the test262 checkout is missing or not at the pinned commit" >&2
  echo "  wanted $TEST262_SHA at tests/test262/test262; run tools/ci/fetch-test262.sh" >&2
  exit 1
fi

# The verifier's unit tests (src/js/runtime/embed/tests.rs, package brimstone_core); they enable the verifier themselves, so they
# hold in a plain cargo test too. BS_GC_VERIFY is set anyway so the run matches the gate's purpose.
step "cargo test -p brimstone_core gc_verify" \
  env BS_GC_VERIFY=1 cargo test --quiet -p brimstone_core gc_verify

# (c) The harness over GC-reachable shapes and weak edges, verifier on and a 4096-byte allocation window so nearly every allocation
# crosses a collection. Each entry is the harness filter string, a substring of the test path relative to its suite root
# (tests/harness/src/runner.rs), and with no -s it runs that path in every suite that has it: first-party under tests/integration,
# test262 under the pinned checkout. The names are the weak-reference and shape-transition directories, chosen for what they
# exercise, not for coverage.
GC_SUBSET=()
# IsHTMLDDA markers: the only objects whose named walk keeps them alive through a transition, and the case the weak-edge repair
# exists for (tests/integration/built-ins/IsHTMLDDA, first-party only).
GC_SUBSET+=("built-ins/IsHTMLDDA")
# First-party regressions, one file per fixed bug: the whole engine under a stress window (tests/integration/regression).
GC_SUBSET+=("regression")
# Weak map edges: key holds weakly, value strongly; a missed edge frees a live key.
GC_SUBSET+=("built-ins/WeakMap")
# Weak set edges: the value itself is the weak edge.
GC_SUBSET+=("built-ins/WeakSet")
# WeakRef cells: deref/ClearWeakRef, the cells the verifier reports on and repairs.
GC_SUBSET+=("built-ins/WeakRef")
# FinalizationRegistry cells plus the QueuesAsFinalization registry jobs: weak held target with a strongly held callback, and the
# job queue that keeps markers alive.
GC_SUBSET+=("built-ins/FinalizationRegistry")
# Redefining properties: shape and property-table transitions, where the named walks miss edges; the largest directory here.
GC_SUBSET+=("built-ins/Object/defineProperty")

first=1
for filter in "${GC_SUBSET[@]}"; do
  # --reindex on the first run: tests/test_index.json is not committed and the index has to be built from this tree plus the
  # pinned checkout before the first filter can match anything.
  if [ "$first" = 1 ]; then
    first=0
    step "cargo btest --reindex $filter" \
      env BS_GC_VERIFY=1 BS_GC_STRESS=4096 cargo btest -- --reindex "$filter"
  else
    step "cargo btest $filter" \
      env BS_GC_VERIFY=1 BS_GC_STRESS=4096 cargo btest -- "$filter"
  fi
done

echo "gate-gc-verify: all steps ok ($SECONDS s)"

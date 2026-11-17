#!/usr/bin/env bash
# Puts the test262 suite at the commit pinned in tests/test262/install_test262.sh into tests/test262/test262, where the test
# manifest (tests/test_manifest.jsonc, "test262_repo_path") looks for it. The commit id is read from that file, so the two cannot
# drift apart. A git commit id is a hash of the content it names; HEAD is compared with the pinned id after the checkout, and a
# mismatch fails.
#
#   tools/ci/fetch-test262.sh            (from anywhere inside the repository)
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
sha=$(sed -n 's/^TEST262_COMMIT_SHA="\([0-9a-f]\{40\}\)".*/\1/p' "$root/tests/test262/install_test262.sh" | head -n 1)
[ -n "$sha" ] || { echo "fetch-test262: no TEST262_COMMIT_SHA in tests/test262/install_test262.sh" >&2; exit 2; }
dir="$root/tests/test262/test262"

if [ -d "$dir/.git" ] && [ "$(git -C "$dir" rev-parse HEAD 2>/dev/null || true)" = "$sha" ]; then
    echo "fetch-test262: already at $sha"
    exit 0
fi
rm -rf "$dir"
mkdir -p "$dir"
git -C "$dir" init -q .
git -C "$dir" remote add origin https://github.com/tc39/test262.git
fetched=0
for attempt in 1 2 3 4; do
    # A shallow fetch of exactly the pinned commit; if the server refuses that, fall back to the full history.
    if git -C "$dir" fetch -q --depth 1 origin "$sha" || git -C "$dir" fetch -q origin; then fetched=1; break; fi
    sleep $((attempt * 15))
done
[ "$fetched" = 1 ] || { echo "fetch-test262: could not fetch test262 in 4 attempts" >&2; exit 1; }
git -C "$dir" checkout -q --detach "$sha"
head=$(git -C "$dir" rev-parse HEAD)
[ "$head" = "$sha" ] || { echo "fetch-test262: at $head, wanted $sha" >&2; exit 1; }
echo "fetch-test262: test262 at $sha"

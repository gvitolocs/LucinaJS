#!/usr/bin/env bash
# Builds the proof-CI launcher `lucina-ci` from a pinned commit of the public repository https://github.com/gvitolocs/lucina.
# The launcher is not part of this repository: it plans the proof jobs, runs each proof under a memory cap and a timeout, writes a
# report per proof and judges the reports. It has no dependencies, so it builds in seconds.
#
#   tools/ci/fetch-lucina-ci.sh <full 40-hex commit> <empty-or-missing directory>
#
# The commit is fetched by its full id, so the content is fixed by the id (a branch that moves later changes nothing), and the
# checked-out HEAD is compared with the id before anything is built. Prints the path of the built binary on its last line.
set -euo pipefail

commit=${1:?usage: fetch-lucina-ci.sh <40-hex commit> <directory>}
dest=${2:?usage: fetch-lucina-ci.sh <40-hex commit> <directory>}
case "$commit" in
    *[!0-9a-f]* | "") echo "fetch-lucina-ci: not a full commit id: $commit" >&2; exit 2 ;;
esac
[ "${#commit}" = 40 ] || { echo "fetch-lucina-ci: not a full commit id: $commit" >&2; exit 2; }

rm -rf "$dest"
mkdir -p "$dest"
cd "$dest"
git init -q .
git remote add origin https://github.com/gvitolocs/lucina.git
for attempt in 1 2 3 4; do
    if git fetch -q --depth 1 origin "$commit"; then break; fi
    [ "$attempt" -lt 4 ] || { echo "fetch-lucina-ci: could not fetch $commit in 4 attempts" >&2; exit 1; }
    sleep $((attempt * 15))
done
git checkout -q --detach FETCH_HEAD
head=$(git rev-parse HEAD)
[ "$head" = "$commit" ] || { echo "fetch-lucina-ci: fetched $head, wanted $commit" >&2; exit 1; }
cargo build --release --locked --manifest-path tools/ci/lucina-ci/Cargo.toml >&2
echo "$dest/tools/ci/lucina-ci/target/release/lucina-ci"

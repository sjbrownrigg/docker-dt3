#!/usr/bin/env bash
#
# Build the discogstagger3 image.
#
#   ./build.sh                      # the ref in .env, or the Dockerfile default
#   DT3_REF=some-branch ./build.sh  # a branch, tag or SHA
#
# discogstagger3 is installed from a git ref rather than a local checkout, so
# this repo builds on its own -- nothing needs cloning alongside it. The ref
# must be pushed, since pip fetches it.

set -euo pipefail
cd "$(dirname "$0")"

# A sibling checkout is not required, but if one is here it is worth saying
# whether what you are about to build matches it -- the usual surprise is
# building a tag while iterating on unpushed commits next door.
SRC="${DT3_SRC:-../discogstagger3}"
if [[ -d "$SRC/.git" ]]; then
    local_head="$(git -C "$SRC" rev-parse --short HEAD)"
    if [[ -n "$(git -C "$SRC" status --porcelain)" ]]; then
        echo "note: ${SRC} has uncommitted changes at ${local_head}." >&2
        echo "      They will NOT be in this image -- it builds from a pushed ref." >&2
    fi
    if ! git -C "$SRC" branch -r --contains HEAD >/dev/null 2>&1; then
        echo "note: ${SRC} HEAD (${local_head}) does not appear to be pushed." >&2
    fi
fi

exec docker compose build "$@"

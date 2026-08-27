#!/usr/bin/env bash
#
# Build discogstagger3 from the local checkout, stamping the SHA into the
# image so what went in is recoverable later.

set -euo pipefail
cd "$(dirname "$0")"

DT3_SRC="${DT3_SRC:-../discogstagger3}"

if [[ -n "$(git -C "$DT3_SRC" status --porcelain)" ]]; then
    echo "warning: ${DT3_SRC} has uncommitted changes; the image will include them." >&2
fi

DT3_REF="$(git -C "$DT3_SRC" rev-parse HEAD)"
echo "discogstagger3  ${DT3_REF:0:7}  ($(git -C "$DT3_SRC" describe --tags --always))"

exec docker compose build --build-arg DT3_REF="$DT3_REF" "$@"

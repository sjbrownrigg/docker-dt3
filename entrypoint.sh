#!/usr/bin/env bash
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

CONFIG_DIR="${DISCOGSTAGGER_CONFIG_DIR:-/config}"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# ── Refuse to run without a config the operator has reviewed ─────────────────
#
# Seeding happens first, so by the time this prints, the files it names exist.
# Informational flags need no configuration -- refusing to print --help
# because there is no config yet is unhelpful, and --version is how you check
# what an image contains before configuring it at all.
wants_info_only() {
    for arg in "$@"; do
        case "$arg" in
            -h|--help|--version|--new-config|--force-new-config) return 0 ;;
        esac
    done
    return 1
}

require_config() {
    [ -f "${CONFIG_FILE}" ] && return 0

    cat >&2 <<MSG

No configuration found at ${CONFIG_FILE}

  Create one:

    docker compose run --rm dt3 --new-config

  That writes config.yaml and formats.ini here, from the reference configs
  inside the package itself. It never overwrites anything you have edited.

  Then edit ${CONFIG_DIR}/config.yaml. Nothing in it needs to name another
  file: formats.ini is found because it sits beside it. Set common.source_dir
  to /incoming and common.dest_dir to /sorted.

  Set DISCOGS_USER_TOKEN in .env rather than writing a token into the config.

Refusing to run: tagging renames and moves files, so it will not run
against settings you have not reviewed.

MSG
    exit 78  # EX_CONFIG
}

if [ "$(id -u)" = "0" ]; then
    getent group dt3 >/dev/null 2>&1 \
        && groupmod -o -g "$PGID" dt3 \
        || groupadd -o -g "$PGID" dt3

    id -u dt3 >/dev/null 2>&1 \
        && usermod -o -u "$PUID" -g "$PGID" dt3 \
        || useradd -o -u "$PUID" -g "$PGID" -M -d /app -s /usr/sbin/nologin dt3

    # Not /incoming or /sorted: the container writes there, but a recursive
    # chown across a music library would be slow and is not this container's
    # decision to make.
    #
    # Not /app either: the token, cache and log all live in the state
    # directory, which is /cache here.
    for dir in /config /cache; do
        [ -d "$dir" ] && chown -R dt3:dt3 "$dir" 2>/dev/null || true
    done

    wants_info_only "$@" || require_config
    exec gosu dt3 "$@"
fi
wants_info_only "$@" || require_config
exec "$@"

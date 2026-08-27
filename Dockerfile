# discogstagger3, deployed.
#
# Built from ../discogstagger3 so the local checkout can be iterated on. The
# repo's own docker/Dockerfile stays as the minimal reference build; this one
# adds PUID/PGID handling and /config seeding, which belong to a deployment
# rather than to the source project.

FROM python:3.12-slim

ARG DT3_REF=unknown

LABEL org.opencontainers.image.source="https://github.com/sjbrownrigg/discogstagger3"
LABEL org.opencontainers.image.description="Console audio-file metadata tagger using the Discogs API"
LABEL org.opencontainers.image.revision="${DT3_REF}"

#   ffmpeg    decoding, ReplayGain (r128gain wraps it), CUE splitting
#   shntool   CUE sheet splitting, fallback for non-FLAC
#   flac      FLAC encode/decode
#   gosu      drop from root to PUID/PGID in the entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
        shntool \
        flac \
        gosu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /src/dt3
RUN pip install --no-cache-dir /src/dt3

# No sample files are staged here on purpose.
#
# discogstagger3 ships its reference configs inside the package, and
# `--new-config` writes from those. Staging copies in the image made the
# deployment a second source of truth for something the package already owns,
# and the two could drift.
#
#   docker compose run --rm dt3 --new-config

# Configuration is a directory, which is why there is no -c switch.
ENV DISCOGSTAGGER_CONFIG_DIR=/config

# Mutable runtime state: the OAuth .token, the API cache and the log file.
# Pointing this at /cache is what lets /app stay read-only.
ENV DISCOGSTAGGER_STATE_DIR=/cache

RUN mkdir -p /cache

VOLUME ["/incoming", "/sorted", "/config", "/cache"]

COPY --chmod=0755 --from=deploy entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "discogstagger"]
CMD ["-w"]

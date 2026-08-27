# discogstagger3, deployed.
#
# The build context is this directory, and discogstagger3 is installed from a
# pinned git ref rather than a sibling checkout.
#
# It used to build from ../discogstagger3 with this directory supplied as a
# second build context, so the entrypoint could be copied in. That needed
# `additional_contexts`, which requires Compose v2.17+ and fails outright on
# older ones ("Additional property additional_contexts is not allowed"), and it
# meant the source repo had to be cloned alongside this one. Installing from a
# ref removes both problems: this repo now builds on its own.
#
# To build from a branch or SHA instead of the release tag, set DT3_REF -- it
# has to be pushed, since pip fetches it.

FROM python:3.12-slim

ARG DT3_REF=v4.0.0

LABEL org.opencontainers.image.source="https://github.com/sjbrownrigg/discogstagger3"
LABEL org.opencontainers.image.description="Console audio-file metadata tagger using the Discogs API"
LABEL org.opencontainers.image.revision="${DT3_REF}"

#   git       pip installs from a git+https URL
#   ffmpeg    decoding, ReplayGain (r128gain wraps it), CUE splitting
#   shntool   CUE sheet splitting, fallback for non-FLAC
#   flac      FLAC encode/decode
#   gosu      drop from root to PUID/PGID in the entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ffmpeg \
        shntool \
        flac \
        gosu \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir \
    "discogstagger3 @ git+https://github.com/sjbrownrigg/discogstagger3.git@${DT3_REF}"

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

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh", "discogstagger"]
CMD ["-w"]

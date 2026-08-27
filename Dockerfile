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

# Reference copies of the files a user owns, staged read-only in the image.
# The entrypoint refreshes /config/samples/ from here on every start, so what a
# mounted volume documents always matches the version installed.
#
# Nothing here is loaded at run time -- defaults come from the schema table in
# discogstagger/config_schema.py. They are named for where they are meant to be
# copied to, so the command a user runs is an obvious one.
#
# Templates and the rule tables are deliberately absent: they belong to
# discogstagger3 and ship inside the package.
RUN set -eux; \
    mkdir -p /defaults; \
    cp /src/dt3/discogstagger/conf/config_sample.yaml  /defaults/config.yaml; \
    cp /src/dt3/discogstagger/conf/formats_sample.ini  /defaults/formats.ini

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

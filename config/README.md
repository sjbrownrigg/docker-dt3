# /config

The live discogstagger3 configuration for this deployment, mounted into the
container at `/config`.

```
config.yaml    settings
formats.ini    file and directory naming
samples/       reference copies, refreshed from the image on every start.
               Never edited, never loaded — copy out of here.
```

That is the whole list: this directory holds what *you* own. Mako templates for
`.nfo`/`.m3u` and the tagging rule tables belong to discogstagger3, ship inside
the package, and are deliberately not copied here, so they keep improving with
each upgrade rather than freezing at the version installed on setup day.

## Why nothing here names a path

`config.yaml` does not reference `formats.ini` — it is found because it sits
beside it under that name. Every path *inside* `config.yaml` resolves against
this directory, so `/config` appears nowhere in it. The same directory works
unchanged as a bind mount, a Docker volume, or a plain directory on a laptop.

There is no `-c` switch for the same reason: a configuration is a directory, so
it is selected by pointing `DISCOGSTAGGER_CONFIG_DIR` at one. The container sets
that to `/config`.

## Credentials

`discogs.user_token` is deliberately empty here. `DISCOGS_USER_TOKEN` from
`.env` overrides it, so the token never enters a config file that could be
committed or copied into an image layer.

## Mounts

`/incoming` and `/sorted` are mounted as **separate roots** rather than the
library root, so this container cannot see — let alone rewrite — the rest of
the collection. Both must be writable: discogstagger3 writes its done marker
into the source directory and the tagged copy into the destination.

`/cache` holds runtime state — the OAuth token, the Discogs API cache and the
log — via `DISCOGSTAGGER_STATE_DIR`.

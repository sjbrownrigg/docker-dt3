# docker-dt3

Docker deployment for [discogstagger3](https://github.com/sjbrownrigg/discogstagger3).

Kept out of the discogstagger3 repo deliberately: a deployment is a different
thing from the tool it deploys. It carries host-specific decisions — NAS
addresses, UID/GID, which directories are mounted where — that have no business
being versioned alongside the source, and it changes on a different rhythm.

## Quick start

```bash
cp .env.example .env          # then set DISCOGS_USER_TOKEN
./build.sh
docker compose run --rm dt3 --new-config
```

That writes `config.yaml` and `formats.ini` into `config/`, from the reference
configs inside the package itself. It never overwrites anything you have edited.

Running without a configuration refuses rather than falling back to defaults:
tagging renames and moves files, so it will not run against settings you have
not reviewed.

Set `common.source_dir` to `/incoming` and `common.dest_dir` to `/sorted`, then:

```bash
docker compose up -d          # watch mode
```

## Layout

| Path | Purpose |
|---|---|
| `config/` | Your live configuration, mounted at `/config` |
| `.env` | Credentials and host settings. Never committed |
| `Dockerfile` | Adds PUID/PGID handling and `/config` seeding to the base build |
| `entrypoint.sh` | Seeds samples, drops to PUID/PGID, refuses without a config |
| `build.sh` | Builds from `../discogstagger3`, stamping the SHA into the image |

## Mounts

`/incoming` and `/sorted` are mounted as **separate roots** rather than the
library root, so the container cannot see — let alone rewrite — the rest of the
collection. Both must be writable: discogstagger3 writes its done marker into
the source directory and the tagged copy into the destination.

`/cache` holds runtime state: the Discogs API cache, the OAuth token and the
log, via `DISCOGSTAGGER_STATE_DIR`.

## Configuration

There is no `-c` switch. A configuration is a directory — `config.yaml` and
`formats.ini` resolving relative to each other — so the container points
`DISCOGSTAGGER_CONFIG_DIR` at `/config` and discogstagger3 finds it.

Nothing inside `config.yaml` names `/config`: `formats.ini` is found because it
sits beside it. The same directory works unchanged on a laptop.

Credentials come from `.env` rather than the config file, so a token never
enters a file that could be committed or copied into an image layer.

See [config/README.md](config/README.md) for the full layout.

## WSL2

NFS Docker volumes are blocked by the WSL2 mount syscall restriction. Use bind
mounts onto an already-mounted share instead:

```bash
docker compose -f compose.yaml -f compose.wsl.yaml up -d
```

Note that a read-only library mount will not work here — discogstagger3 writes.

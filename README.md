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

## Moving to another host

Three things need doing on a new host, and the first fails *silently* if you
miss it.

**1. Remove `COMPOSE_FILE` from `.env`.** It is a WSL2 workaround. Carrying it
to a Linux host forces the bind-mount override, whose paths will not exist
there — and Docker's default is to create a missing bind source rather than
complain, so you would get empty directories, nothing to tag, and a container
reporting itself healthy. `compose.wsl.yaml` now sets `create_host_path: false`
so this errors at startup instead, but deleting the line is the actual fix. On
Linux you want the NFS volumes in `compose.yaml`.

**2. Nothing else to clone.** The image is built from a pinned git ref, so this
repo stands on its own:

```bash
git clone https://github.com/sjbrownrigg/docker-dt3.git
cd docker-dt3 && ./build.sh
```

Set `DT3_REF` to build a different branch, tag or SHA — it has to be pushed,
since pip fetches it.

**3. Create the shared network**, which is external and owned by no stack:

```bash
docker network create mozarr-net
```

**4. Install an NFS client.** Docker's local NFS volume driver uses the host
kernel's, so without it the volumes fail to mount:

```bash
sudo apt install nfs-common
```

Then set `NAS_ADDR` and `NAS_MUSIC_PATH` in `.env` and bring it up. Everything
else — `PUID`/`PGID`, the credentials, the config directory — travels unchanged.

## WSL2

NFS Docker volumes fail here with `operation not permitted` — a WSL2 mount
syscall restriction. Use bind mounts onto an already-mounted share instead.

Set this in `.env` and plain `docker compose up` picks up the override, with no
`-f` flags to remember:

```
COMPOSE_FILE=compose.yaml:compose.wsl.yaml
```

**The mounted paths must be writable.** `docker-mozarr` mounts the music share
read-only on purpose — mozarr only reads — but discogstagger3 writes a done marker into
the source directory and the tagged copy into the destination, so a read-only
mount fails partway through a run.

Mount just the working directories read-write, leaving the rest of the library
protected:

```bash
sudo bash bootstrap/mount-writable-wsl.sh incoming sorted
```

Then point `INCOMING_DIR`, `SORTED_DIR` in `.env` at those mount
points. The script prints the exact lines.

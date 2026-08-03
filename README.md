# Project Zomboid Dedicated Server

Docker image and Compose setup for the Project Zomboid Linux dedicated server. The
default Steam `public` branch installs Build 42. Build 41 remains available through
the `legacy41` branch.

The image supports Linux `amd64`/`x86_64`. Project Zomboid does not distribute an
ARM64 dedicated-server binary, so ARM-based Synology models cannot run this image
natively.

## Quick start with Docker Compose

Edit `docker-compose.yml` first and replace
`change-me-before-starting` with a strong admin password. Then run:

```sh
docker-compose build --pull
docker-compose up -d
docker-compose logs --tail=100 -f
```

On systems with Docker Compose v2, use `docker compose` instead of
`docker-compose`.

The first start downloads and validates the dedicated server with SteamCMD, so it
can take several minutes. The server data and configuration remain on the host in:

- `./data/server-file` — Steam dedicated-server files
- `./data/config` — worlds, saves, databases, logs, and server configuration

## Synology DSM 7.0.1

DSM 7.0.1 uses the Synology **Docker** package. Install Docker and Git Server from
Package Center, enable SSH temporarily, then connect to the NAS. First verify that
the NAS is compatible:

```sh
uname -m
docker-compose version
```

`uname -m` must report `x86_64`. Choose a shared folder for Docker projects; this
example uses `/volume1/docker`:

```sh
cd /volume1/docker
git clone --branch codex/build-42-support --single-branch \
  https://github.com/Yzzzed/projectzomboid-server.git
cd projectzomboid-server
id
```

Use the numeric `uid` and `gid` printed by `id` to create a local `.env` file:

```dotenv
PZ_UID=1026
PZ_GID=100
```

The numbers above are examples; use the values from your NAS account. Now edit
`docker-compose.yml`, set the admin password, and build:

```sh
sudo docker-compose build --pull
sudo docker-compose up -d
sudo docker-compose logs --tail=100 -f
```

Press `Ctrl+C` to leave the logs; the container keeps running. Later updates use:

```sh
git pull --ff-only
sudo docker-compose up -d --build
```

If your account is already allowed to access Docker, omit `sudo`.

## Build 41 to Build 42 migration

Build 41 and Build 42 worlds are not interchangeable. Back up the entire
`./data/config` directory before changing branches.

This image records the installed branch in
`/data/config/.projectzomboid-server-branch` and refuses accidental changes after
that marker exists. For data created by an older image, the marker does not exist;
if multiplayer saves are found, `SERVER_BRANCH` must be set explicitly on the first
start with this image.

Common branch values are:

- `public` — current stable release (Build 42)
- `legacy41` — Build 41
- `42.19` — the archived Build 42.19 branch
- `unstable` — unstable testing branch

To intentionally change a recorded branch, back up the data and set both variables
for that one start:

```yaml
environment:
  SERVER_BRANCH: "public"
  ALLOW_BRANCH_CHANGE: "true"
```

After a successful start, remove `ALLOW_BRANCH_CHANGE`; the new branch remains
recorded. `SERVER_UPDATE_ON_START` must be enabled during a branch change.

## Configuration behavior

The server INI is stored at
`./data/config/Server/<SERVER_NAME>.ini`. For a new INI, the entrypoint writes safe
defaults. For an existing INI, it changes an option only when the corresponding
environment variable is explicitly present. This keeps manual INI edits from being
replaced by empty Docker defaults.

For example, omitting `SERVER_PASSWORD` preserves the value already in the INI.
Setting it explicitly to an empty string deliberately clears the password:

```yaml
environment:
  SERVER_PASSWORD: ""
```

The following variables map to INI options:

| Environment variable | INI option | New-server default |
| --- | --- | --- |
| `SERVER_PORT` | `DefaultPort` | `16261` |
| `SERVER_UDP_PORT` | `UDPPort` | `16262` |
| `SERVER_PASSWORD` | `Password` | empty |
| `SERVER_PUBLIC` | `Public` | `false` |
| `SERVER_PUBLIC_NAME` | `PublicName` | `Project Zomboid Docker Server` |
| `SERVER_PUBLIC_DESC` | `PublicDescription` | empty |
| `SERVER_MAX_PLAYER` | `MaxPlayers` | `16` |
| `MOD_NAMES` | `Mods` | empty |
| `MOD_WORKSHOP_IDS` | `WorkshopItems` | empty |
| `RCON_PORT` | `RCONPort` | `27015` |
| `RCON_PASSWORD` | `RCONPassword` | empty |

Other runtime variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SERVER_NAME` | `server` | INI/database name; letters, digits, `.`, `_`, and `-` only |
| `SERVER_ADMIN_PASSWORD` | `pzadmin` | Initial server admin password |
| `SERVER_BRANCH` | recorded branch or `public` | Steam branch to install |
| `SERVER_UPDATE_ON_START` | `true` | Run SteamCMD on every container start |
| `SERVER_VALIDATE` | `true` | Add SteamCMD's `validate` option |
| `ALLOW_BRANCH_CHANGE` | `false` | Permit an intentional recorded-branch change |
| `FORCESTEAMCLIENTSOUPDATE` | `false` | Refresh `steamclient.so` when troubleshooting Workshop updates |
| `PUID` / `PGID` | `1000` / `1000` | Host ownership for mounted files |
| `UID` / `GID` | — | Backward-compatible aliases for `PUID` / `PGID` |

Boolean variables accept `true`/`false`, `1`/`0`, `yes`/`no`, or `on`/`off`.

## Build 42 mods

Build 42 requires each mod name in the `Mods` value to start with a backslash. Use a
single-quoted YAML value so Compose passes those backslashes unchanged:

```yaml
environment:
  MOD_NAMES: '\RainWash;\EasyConfigChucked;\ExpandedHelicopterEvents'
  MOD_WORKSHOP_IDS: '2657661246;2529746725;2458631365'
```

The entrypoint writes INI values without `sed`, preserving the Build 42 backslashes.

## JVM memory

Use one of these forms:

```yaml
environment:
  SERVER_MEMORY: "8g"
```

or:

```yaml
environment:
  SERVER_MIN_MEMORY: "4g"
  SERVER_MAX_MEMORY: "8g"
```

`SERVER_MEMORY` cannot be combined with the min/max form. Values must be positive
megabyte or gigabyte values such as `2048m` or `8g`.

## Ports

- `16261/udp` — game server
- `16262/udp` — direct connection/default additional UDP port
- `27015/tcp` — RCON; publish it in Compose only when RCON is configured

If `SERVER_PORT`, `SERVER_UDP_PORT`, or `RCON_PORT` is changed, update the host-side
Compose port mapping too.

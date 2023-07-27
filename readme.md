# Project Zomboid Server

## Volumes

- `/data/server-file` Project Zomboid server file
- `/data/config` Database and configuration file

## Environment varibles

### Project Zomboid Server

- **SERVER_NAME** Name of your server (for db & ini file). Warning: don't use special characters or spaces.
- **SERVER_PASSWORD** Password of your server used to connect to it
- **SERVER_ADMIN_PASSWORD** Admin password on your server (default: pzadmin)
- **SERVER_PORT** Game server port (default: 16261)
- **SERVER_UDP_PORT** Game server UDP port (default: 16262)
- **SERVER_BRANCH** Name of the beta branch
- **SERVER_PUBLIC** Public server (default: false)
- **SERVER_PUBLIC_NAME** Public name of your server
- **SERVER_PUBLIC_DESC** Public description of your server
- **SERVER_MAX_PLAYER** Maximum number of players on your server (default: 16)

### Mods

- **MOD_NAMES** Workshop Mod Names
- **MOD_WORKSHOP_IDS** Workshop Mod IDs

### RCON

- **RCON_PORT** RCON port (default: 27015)
- **RCON_PASSWORD** RCON password

### System User

- **UID** User ID (default: 1000)
- **GID** Group ID (default: 1000)

# Expose

- 27015 RCON
- 16261 Game server (udp)
- 16262 Game server (udp)

# Docker Compose

Example of docker compose file

```yaml
version: "3.8"

services:
  project-zomboid:
    container_name: pzserver
    image: pepecitron/projectzomboid-server
    restart: unless-stopped
    environment:
      SERVER_ADMIN_PASSWORD: "pzadmin"
      SERVER_PASSWORD: "secretpassword"
    ports:
      - "16261:16261/udp"
      - "16262:16262/udp"
    volumes:
      - ./data/server-file:/data/server-file
      - ./data/config:/data/config
```

# Help

## Server Configuration

The servers configuration can be set via the servers `<SERVER_NAME>.ini` and `<SERVER_NAME>_SandboxVars.lua`, which are located at the path of the mounted config volume. The server needs to be restarted for the changes to take effect. Gameserver updates are applied automatically by restarting the container.

## Mods

Mods can be added by modifying `MOD_NAMES` and `MOD_WORKSHOP_IDS` environment variables. 
```yaml
...
    environment:
      MOD_NAMES: "RainWash,EasyConfigChucked,ExpandedHelicopterEvents"
      MOD_WORKSHOP_IDS: "2657661246,2529746725,2458631365"
...
```
Newly added mods and updates for existing mods are applied automatically by restarting the container.

## Multiple Servers

To avoid problems during server updates, different volumes should be mounted. The new public gameserver port (`16261`, `16262`, etc.) must be used ingame to connect to the new server.

```yaml
version: "3.8"

services:
  server-1:
    container_name: pzserver-server-1
    image: pepecitron/projectzomboid-server
    restart: unless-stopped
    environment:
      SERVER_NAME: "server-1"
    ports:
      - "16261:16261/udp"
      - "16262:16262/udp"
    volumes:
      - ./data/server-file-server-1:/data/server-file
      - ./data/config:/data/config
  server-2:
    container_name: pzserver-server-2
    image: pepecitron/projectzomboid-server
    restart: unless-stopped
    environment:
      SERVER_NAME: "server-2"
    ports:
      - "16263:16261/udp"
      - "16264:16262/udp"
    volumes:
      - ./data/server-file-server-2:/data/server-file
      - ./data/config:/data/config
```
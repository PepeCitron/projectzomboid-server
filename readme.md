# Project Zomboid Server

## Volumes

- `/data/server-file` Project Zomboid server file
- `/data/config` Database and configuration file

## Environment varibles

### Steam

- **STEAMPORT1** Steam port (default: 8766)
- **STEAMPORT2** Steam port (default: 8767)

### Project Zomboid Server

- **SERVER_NAME** Name of your server (for db & ini file). Warning: don't use special characters or spaces.
- **SERVER_PASSWORD** Password of your server used to connect to it
- **SERVER_ADMIN_PASSWORD** Admin password on your server (default: pzadmin)
- **SERVER_PORT** Game server port (default: 16261)
- **SERVER_BRANCH** Name of the beta branch
- **SERVER_PUBLIC** Public server (default: false)
- **SERVER_PUBLIC_NAME** Public name of your server
- **SERVER_PUBLIC_DESC** Public description of your server
- **SERVER_MAX_PLAYER** Maximum number of players on your server (default: 16)

### RCON

- **RCON_PORT** RCON port (default: 27015)
- **RCON_PASSWORD** RCON password

### System User

- **UID** User Id (default: 1000)
- **GID** Group ID (default: 1000)

# Expose

- 8766 Steam port 1 (udp)
- 8767 Steam port 2 (udp)
- 27015 RCON
- 16261 Game server (udp)

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
      - "8766:8766/udp"
      - "8767:8767/udp"
      - "16261:16261/udp"
    volumes:
      - ./data/server-file:/data/server-file
      - ./data/config:/data/config
```

# Help

## Server Configuration

The servers configuration can be set via the servers `<SERVER_NAME>.ini` and `<SERVER_NAME>_SandboxVars.lua`, which are located at the path of the mounted config volume. The server needs to be restarted for the changes to take effect. Gameserver updates are applied automatically by restarting the container.

## Mods

Mods can be added by modifying the properties `WorkshopItems` and `Mods` in the generated `.ini` server file. 
```
# List of Workshop Mods must be separated by semicolon
WorkshopItems=2778991696;2392709985;...

Mods=Hydrocraft;tsarslib;...
```
Newly added mods and updates for existing mods are applied automatically by restarting the container.

## Multiple Servers

Different servers must use different ports, which can be configured individually via the `STEAMPORT1` and `STEAMPORT2` environment variables. These port-configurations must be reflected in the service's `ports` section. To avoid problems during server updates, different volumes should be mounted. The new public gameserver port (`16261`, `16262`, etc.) must be used ingame to connect to the new server.

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
      - "8766:8766/udp"
      - "8767:8767/udp"
      - "16261:16261/udp"
    volumes:
      - ./data/server-file-server-1:/data/server-file
      - ./data/config:/data/config
  server-2:
    container_name: pzserver-server-2
    image: pepecitron/projectzomboid-server
    restart: unless-stopped
    environment:
      SERVER_NAME: "server-2"
      STEAMPORT1: 8768
      STEAMPORT2: 8769
    ports:
      - "8768:8768/udp"
      - "8769:8769/udp"
      - "16262:16261/udp"
    volumes:
      - ./data/server-file-server-2:/data/server-file
      - ./data/config:/data/config
```
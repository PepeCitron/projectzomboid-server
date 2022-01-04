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

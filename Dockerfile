FROM ubuntu:20.04

# Env var
ENV STEAMPORT1="8766" \
    STEAMPORT2="8767" \
    SERVER_NAME="server" \
    SERVER_PASSWORD="" \
    SERVER_ADMIN_PASSWORD="pzadmin" \
    SERVER_PORT="16261" \
    SERVER_BRANCH="" \
    SERVER_PUBLIC="false" \
    SERVER_PUBLIC_NAME="Project Zomboid Docker Server" \
    SERVER_PUBLIC_DESC="" \
    SERVER_MAX_PLAYER="16" \
    RCON_PORT="27015" \
    RCON_PASSWORD=""

# Install dependencies
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        lib32gcc1 \
        curl \
        default-jre \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* 

# Expose ports
EXPOSE $STEAMPORT1/udp
EXPOSE $STEAMPORT2/udp
EXPOSE $SERVER_PORT/udp
EXPOSE ${RCON_PASSWORD}

VOLUME ["/data/server-file", "/data/config"]

COPY entry.sh /data/scripts/entry.sh
CMD ["bash", "/data/scripts/entry.sh"]
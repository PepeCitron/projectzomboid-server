#!/bin/sh

# Install SteamCMD
if [ ! -f /home/steam/steamcmd.sh ]
then
  echo "Downloading SteamCMD..."
  mkdir -p /home/steam/
  cd /home/steam/
  curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
fi

# Install pzserver
echo "Installing Project Zomboid..."
if [ "$BRANCH" == "" ]
then
  /home/steam/steamcmd.sh +force_install_dir /data/server-file +login anonymous +app_update 380870 +quit
else
  /home/steam/steamcmd.sh +force_install_dir /data/server-file +login anonymous +app_update 380870 -beta ${SERVERBRANCH} +quit
fi

# Symlink
if [ ! -d /data/config ]
then
	mkdir -p /data/config
fi
ln -s /data/config /root/Zomboid

# Server Configuration
server_ini="/data/config/Server/${SERVER_NAME}.ini"

if [ -f $server_ini ]
then
    sed -ri "s/^Password=(.*)$/Password=${SERVER_PASSWORD}/" "${server_ini}"
    sed -ri "s/^Public=(.*)$/Public=${SERVER_PUBLIC}/" "${server_ini}"
    sed -ri "s/^PublicName=(.*)$/PublicName=${SERVER_PUBLIC_NAME}/" "${server_ini}"
    sed -ri "s/^PublicDescription=(.*)$/PublicDescription=${SERVER_PUBLIC_DESC}/" "${server_ini}"
    sed -ri "s/^RCONPort=([0-9]+)$/RCONPort=${RCON_PORT}/" "${server_ini}"
    sed -ri "s/^RCONPassword=(.*)$/RCONPassword=${RCON_PASSWORD}/" "${server_ini}"
    sed -ri "s/^MaxPlayers=(.*)$/MaxPlayers=${SERVER_MAX_PLAYER}/" "${server_ini}"
fi

# Start server
echo "Launching server..."
cd /data/server-file
./start-server.sh -servername ${SERVER_NAME}  -steamport1 ${STEAMPORT1} -steamport2 ${STEAMPORT2} -adminpassword ${SERVER_ADMIN_PASSWORD}

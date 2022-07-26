#!/bin/sh

# Handles SIGTERM and SIGINT to gracefully stop the server.
trap sigHandle SIGTERM SIGINT
function sigHandle() {
  echo "Signal Received, sending Quit command."
  su pzombie -s /bin/sh -p -c "/home/pzombie/rcon-cli/rcon -a 127.0.0.1:${RCON_PORT} -t rcon -p ${RCON_PASSWORD} quit"
  echo "Command sent, waiting for process to exit."
  wait $(ps -eo pid,cmd | awk '/su.*start-server.*$/  {print $1; exit}')
  exit 0
}

# Update config in the configuration file
function updateConfigValue() {
  sed -i "s/\(^$1 *= *\).*/\1$2/" $server_ini
}

# Ensure User and Group IDs
if [ ! "$(id -u pzombie)" -eq "$UID" ]; then usermod -o -u "$UID" pzombie ; fi
if [ ! "$(id -g pzombie)" -eq "$GID" ]; then groupmod -o -g "$GID" pzombie ; fi

# Install Rcon-Cli
# RCon Cli - https://github.com/gorcon/rcon-cli
# GitHub Latest Release download script - https://gist.github.com/steinwaywhw/a4cd19cda655b8249d908261a62687f8
if [ ! -f /home/pzombie/rcon-cli/rcon ]
then
  echo "Downloading RCON Cli - (https://github.com/gorcon/rcon-cli)"
  cd /home/pzombie
  curl -s https://api.github.com/repos/gorcon/rcon-cli/releases/latest \
  | grep "browser_download_url.*-amd64_linux.tar.gz" \
  | cut -d : -f 2,3 \
  | tr -d \" \
  | xargs curl -sqL \
  | tar zxvf -
  mv rcon-*-amd64_linux rcon-cli
  chown -R pzombie:pzombie /home/pzombie/rcon-cli
fi

# Install SteamCMD
if [ ! -f /home/steam/steamcmd.sh ]
then
  echo "Downloading SteamCMD..."
  mkdir -p /home/steam/
  cd /home/steam/
  curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
  chown -R pzombie:pzombie /home/steam
  chown -R pzombie:pzombie /data/server-file
fi

# Update pzserver
echo "Updating Project Zomboid..."
if [ "$BRANCH" == "" ]
then
  su pzombie -s /bin/sh -p -c "/home/steam/steamcmd.sh +force_install_dir /data/server-file +login anonymous +app_update 380870 +quit"
else
  su pzombie -s /bin/sh -p -c "/home/steam/steamcmd.sh +force_install_dir /data/server-file +login anonymous +app_update 380870 -beta ${SERVERBRANCH} +quit"
fi

# Symlink
echo "Creating symlink for config folder..."
if [ ! -d /data/config ]
then
  mkdir -p /data/config
fi
su pzombie -s /bin/sh -p -c "ln -s /data/config /home/pzombie/Zomboid"

# Generate a Random RCON Password
# if none is set, needed for the
# RCON Cli
if [[ -z "$RCON_PASSWORD" ]]; then
   RCON_PASSWORD=$(echo $RANDOM | md5sum | head -c 20)
   echo "Random RCON Password Generated: ${RCON_PASSWORD}"
fi

# Apply server connfiguration
server_ini="/data/config/Server/${SERVER_NAME}.ini"

if [ ! -f $server_ini ]
then
  echo "Updating ${SERVER_NAME}.ini..."
  mkdir -p /data/config/Server
  touch ${server_ini}

  echo "DefaultPort=${SERVER_PORT}" >> ${server_ini}
  echo "Password=${SERVER_PASSWORD}" >> ${server_ini}
  echo "Public=${SERVER_PUBLIC}" >> ${server_ini}
  echo "PublicName=${SERVER_PUBLIC_NAME}" >> ${server_ini}
  echo "PublicDescription=${SERVER_PUBLIC_DESC}" >> ${server_ini}
  echo "RCONPort=${RCON_PORT}" >> ${server_ini}
  echo "RCONPassword=${RCON_PASSWORD}" >> ${server_ini}
  echo "MaxPlayers=${SERVER_MAX_PLAYER}" >> ${server_ini}
else
  # Ensure config
  updateConfigValue "DefaultPort" ${SERVER_PORT}
  updateConfigValue "Password" ${SERVER_PASSWORD}
  updateConfigValue "Public" ${SERVER_PUBLIC}
  updateConfigValue "PublicName" ${SERVER_PUBLIC_NAME}
  updateConfigValue "PublicDescription" ${SERVER_PUBLIC_DESC}
  updateConfigValue "RCONPort" ${RCON_PORT}
  updateConfigValue "RCONPassword" ${RCON_PASSWORD}
  updateConfigValue "MaxPlayers" ${SERVER_MAX_PLAYER}
fi

chown -R pzombie:pzombie /data/config/

# Start server
echo "Launching server..."
cd /data/server-file
su pzombie -s /bin/sh -p -c "./start-server.sh -servername ${SERVER_NAME}  -steamport1 ${STEAMPORT1} -steamport2 ${STEAMPORT2} -adminpassword ${SERVER_ADMIN_PASSWORD}" & wait $!

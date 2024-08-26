#!/bin/sh

# Update config in the configuration file
function updateConfigValue() {
  sed -i "s/\(^$1 *= *\).*/\1${2//&/\\&}/" $server_ini
}

# Ensure User and Group IDs
if [ ! "$(id -u pzombie)" -eq "$UID" ]; then usermod -o -u "$UID" pzombie ; fi
if [ ! "$(id -g pzombie)" -eq "$GID" ]; then groupmod -o -g "$GID" pzombie ; fi

# Install SteamCMD
if [ ! -f /home/steam/steamcmd.sh ]
then
  echo "Downloading SteamCMD..."
  mkdir -p /home/steam/
  cd /home/steam/
  curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
fi

# Update pzserver
echo "Updating Project Zomboid..."
if [ "$SERVER_BRANCH" -eq "" ]
then
  su root -s /bin/sh -p -c "/home/steam/steamcmd.sh +force_install_dir /data/server-file +login anonymous +app_update 380870 +quit"
else
  su root -s /bin/sh -p -c "/home/steam/steamcmd.sh +force_install_dir /data/server-file +login anonymous +app_update 380870 -beta ${SERVER_BRANCH} +quit"
fi

# Permissions
chown -R pzombie:pzombie /home/steam
chown -R pzombie:pzombie /data/server-file

# Symlink
echo "Creating symlink for config folder..."
if [ ! -d /data/config ]
then
  mkdir -p /data/config
fi
su pzombie -s /bin/sh -p -c "ln -s /data/config /home/pzombie/Zomboid"

# Apply server connfiguration
server_ini="/data/config/Server/${SERVER_NAME}.ini"

if [ ! -f $server_ini ]
then
  echo "Updating ${SERVER_NAME}.ini..."
  mkdir -p /data/config/Server
  touch ${server_ini}

  echo "DefaultPort=${SERVER_PORT}" >> ${server_ini}
  echo "UDPPort=${SERVER_UDP_PORT}" >> ${server_ini}
  echo "Password=${SERVER_PASSWORD}" >> ${server_ini}
  echo "Public=${SERVER_PUBLIC}" >> ${server_ini}
  echo "PublicName=${SERVER_PUBLIC_NAME}" >> ${server_ini}
  echo "PublicDescription=${SERVER_PUBLIC_DESC}" >> ${server_ini}
  echo "RCONPort=${RCON_PORT}" >> ${server_ini}
  echo "RCONPassword=${RCON_PASSWORD}" >> ${server_ini}
  echo "MaxPlayers=${SERVER_MAX_PLAYER}" >> ${server_ini}
  echo "Mods=${MOD_NAMES}" >> ${server_ini}
  echo "WorkshopItems=${MOD_WORKSHOP_IDS}" >> ${server_ini}
else
  updateConfigValue "DefaultPort" ${SERVER_PORT}
  updateConfigValue "UDPPort" ${SERVER_UDP_PORT}
  updateConfigValue "Password" ${SERVER_PASSWORD}
  updateConfigValue "Public" ${SERVER_PUBLIC}
  updateConfigValue "PublicName" "${SERVER_PUBLIC_NAME}"
  updateConfigValue "PublicDescription" "${SERVER_PUBLIC_DESC}"
  updateConfigValue "RCONPort" ${RCON_PORT}
  updateConfigValue "RCONPassword" ${RCON_PASSWORD}
  updateConfigValue "MaxPlayers" ${SERVER_MAX_PLAYER}
  updateConfigValue "Mods" "${MOD_NAMES}"
  updateConfigValue "WorkshopItems" "${MOD_WORKSHOP_IDS}"
fi

chown -R pzombie:pzombie /data/config/

# Copy default spawn locations file to server config folder
if [ ! -f /data/config/${SERVER_NAME^}/server_spawnregions.lua ]
then
  cp /data/server_spawnregions.lua /data/config/${SERVER_NAME^}/server_spawnregions.lua
fi

# Start server
echo "Launching server..."
cd /data/server-file
su pzombie -s /bin/sh -p -c "./start-server.sh -servername ${SERVER_NAME} -adminpassword ${SERVER_ADMIN_PASSWORD}"
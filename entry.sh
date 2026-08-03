#!/usr/bin/env bash

set -Eeuo pipefail

readonly STEAMCMD_DIR="/home/steam"
readonly SERVER_DIR="/data/server-file"
readonly CONFIG_DIR="/data/config"
readonly PZ_HOME="/home/pzombie"
readonly BRANCH_MARKER="${CONFIG_DIR}/.projectzomboid-server-branch"
readonly SAVE_DIR="${CONFIG_DIR}/Saves/Multiplayer"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

is_true() {
  case "$1" in
    1|true|TRUE|True|yes|YES|Yes|on|ON|On) return 0 ;;
    *) return 1 ;;
  esac
}

is_false() {
  case "$1" in
    ""|0|false|FALSE|False|no|NO|No|off|OFF|Off) return 0 ;;
    *) return 1 ;;
  esac
}

require_boolean() {
  local name="$1"
  local value="$2"

  is_true "$value" || is_false "$value" || \
    die "${name} must be one of true/false, 1/0, yes/no, or on/off (got: ${value})."
}

normalize_branch() {
  local branch="${1:-public}"

  case "$branch" in
    public|PUBLIC|Public|stable|STABLE|Stable) printf 'public\n' ;;
    *) printf '%s\n' "$branch" ;;
  esac
}

directory_has_entries() {
  local directory="$1"
  local first_entry=""

  [[ -d "$directory" ]] || return 1
  first_entry="$(find "$directory" -mindepth 1 -maxdepth 1 -print -quit)"
  [[ -n "$first_entry" ]]
}

RECORDED_SERVER_BRANCH=""
RESOLVED_SERVER_BRANCH=""
BRANCH_MARKER_NEEDS_UPDATE=0

resolve_server_branch() {
  local requested_branch="$1"
  local branch_was_set="$2"
  local marker_file="$3"
  local save_directory="$4"
  local allow_branch_change="$5"

  RECORDED_SERVER_BRANCH=""
  RESOLVED_SERVER_BRANCH=""
  BRANCH_MARKER_NEEDS_UPDATE=0

  if [[ -f "$marker_file" ]]; then
    IFS= read -r RECORDED_SERVER_BRANCH < "$marker_file" || true
    RECORDED_SERVER_BRANCH="$(normalize_branch "$RECORDED_SERVER_BRANCH")"
  fi

  if [[ "$branch_was_set" == "1" ]]; then
    RESOLVED_SERVER_BRANCH="$(normalize_branch "$requested_branch")"
  elif [[ -n "$RECORDED_SERVER_BRANCH" ]]; then
    RESOLVED_SERVER_BRANCH="$RECORDED_SERVER_BRANCH"
  elif directory_has_entries "$save_directory"; then
    die "Existing multiplayer saves were found, but no server branch has been recorded. Set SERVER_BRANCH explicitly to public, legacy41, 42.19, unstable, or another valid Steam branch before starting."
  else
    RESOLVED_SERVER_BRANCH="public"
  fi

  [[ "$RESOLVED_SERVER_BRANCH" =~ ^[A-Za-z0-9._-]+$ ]] || \
    die "SERVER_BRANCH contains unsupported characters: ${RESOLVED_SERVER_BRANCH}"

  if [[ -n "$RECORDED_SERVER_BRANCH" && "$RESOLVED_SERVER_BRANCH" != "$RECORDED_SERVER_BRANCH" ]]; then
    is_true "$allow_branch_change" || \
      die "Changing SERVER_BRANCH from ${RECORDED_SERVER_BRANCH} to ${RESOLVED_SERVER_BRANCH} may make saves incompatible. Back up /data/config, then set ALLOW_BRANCH_CHANGE=true for the branch-changing start."
  fi

  if [[ "$RESOLVED_SERVER_BRANCH" != "$RECORDED_SERVER_BRANCH" ]]; then
    BRANCH_MARKER_NEEDS_UPDATE=1
  fi
}

write_branch_marker() {
  local branch="$1"
  local marker_file="$2"
  local marker_directory
  local temporary_file

  marker_directory="$(dirname "$marker_file")"
  mkdir -p "$marker_directory"
  temporary_file="$(mktemp "${marker_file}.tmp.XXXXXX")"
  printf '%s\n' "$branch" > "$temporary_file"
  chmod 0644 "$temporary_file"
  mv -f "$temporary_file" "$marker_file"
}

set_ini_option() {
  local file="$1"
  local key="$2"
  local value="$3"
  local temporary_file
  local line
  local found=0

  [[ "$key" =~ ^[A-Za-z0-9]+$ ]] || die "Invalid INI key: ${key}"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || \
    die "INI value for ${key} must be a single line."

  mkdir -p "$(dirname "$file")"
  touch "$file"
  temporary_file="$(mktemp "${file}.tmp.XXXXXX")"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^${key}[[:space:]]*= ]]; then
      if [[ "$found" == "0" ]]; then
        printf '%s=%s\n' "$key" "$value" >> "$temporary_file"
        found=1
      fi
    else
      printf '%s\n' "$line" >> "$temporary_file"
    fi
  done < "$file"

  if [[ "$found" == "0" ]]; then
    printf '%s=%s\n' "$key" "$value" >> "$temporary_file"
  fi

  chmod 0644 "$temporary_file"
  mv -f "$temporary_file" "$file"
}

should_apply_config() {
  local is_new_file="$1"
  local environment_was_set="$2"
  [[ "$is_new_file" == "1" || "$environment_was_set" == "1" ]]
}

STEAMCMD_COMMAND=()

build_steamcmd_command() {
  local branch="$1"
  local validate="$2"

  STEAMCMD_COMMAND=(
    "${STEAMCMD_DIR}/steamcmd.sh"
    +force_install_dir "$SERVER_DIR"
    +login anonymous
    +app_update 380870
  )

  if [[ "$branch" != "public" ]]; then
    STEAMCMD_COMMAND+=(-beta "$branch")
  fi

  if is_true "$validate"; then
    STEAMCMD_COMMAND+=(validate)
  fi

  STEAMCMD_COMMAND+=(+quit)
}

START_ARGUMENTS=()

validate_memory_value() {
  local name="$1"
  local value="$2"

  [[ -z "$value" || "$value" =~ ^[1-9][0-9]*[mMgG]$ ]] || \
    die "${name} must use a positive m or g value, for example 2048m or 8g (got: ${value})."
}

build_start_arguments() {
  local server_name="$1"
  local admin_password="$2"
  local memory="$3"
  local minimum_memory="$4"
  local maximum_memory="$5"
  local has_jvm_arguments=0

  START_ARGUMENTS=()

  if [[ -n "$memory" && ( -n "$minimum_memory" || -n "$maximum_memory" ) ]]; then
    die "SERVER_MEMORY cannot be combined with SERVER_MIN_MEMORY or SERVER_MAX_MEMORY."
  fi

  validate_memory_value "SERVER_MEMORY" "$memory"
  validate_memory_value "SERVER_MIN_MEMORY" "$minimum_memory"
  validate_memory_value "SERVER_MAX_MEMORY" "$maximum_memory"

  if [[ -n "$memory" ]]; then
    START_ARGUMENTS+=("-Xms${memory}" "-Xmx${memory}")
    has_jvm_arguments=1
  else
    if [[ -n "$minimum_memory" ]]; then
      START_ARGUMENTS+=("-Xms${minimum_memory}")
      has_jvm_arguments=1
    fi
    if [[ -n "$maximum_memory" ]]; then
      START_ARGUMENTS+=("-Xmx${maximum_memory}")
      has_jvm_arguments=1
    fi
  fi

  if [[ "$has_jvm_arguments" == "1" ]]; then
    START_ARGUMENTS+=(--)
  fi

  START_ARGUMENTS+=(-servername "$server_name" -adminpassword "$admin_password")
}

install_steamcmd() {
  if [[ -x "${STEAMCMD_DIR}/steamcmd.sh" ]]; then
    return
  fi

  printf 'Downloading SteamCMD...\n'
  mkdir -p "$STEAMCMD_DIR"
  curl --fail --silent --show-error --location \
    "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
    | tar -xz -C "$STEAMCMD_DIR"
}

ensure_config_symlink() {
  local link_path="${PZ_HOME}/Zomboid"
  local current_target=""

  mkdir -p "$CONFIG_DIR"

  if [[ -L "$link_path" ]]; then
    current_target="$(readlink "$link_path")"
    if [[ "$current_target" != "$CONFIG_DIR" ]]; then
      rm -- "$link_path"
      ln -s "$CONFIG_DIR" "$link_path"
    fi
  elif [[ -e "$link_path" ]]; then
    die "${link_path} exists and is not a symlink. Move its data into ${CONFIG_DIR} before starting."
  else
    ln -s "$CONFIG_DIR" "$link_path"
  fi
}

configure_runtime_user() {
  local target_uid="$1"
  local target_gid="$2"

  [[ "$target_uid" =~ ^[0-9]+$ ]] || die "UID must be numeric (got: ${target_uid})."
  [[ "$target_gid" =~ ^[0-9]+$ ]] || die "GID must be numeric (got: ${target_gid})."

  if [[ "$(id -g pzombie)" != "$target_gid" ]]; then
    groupmod -o -g "$target_gid" pzombie
  fi
  if [[ "$(id -u pzombie)" != "$target_uid" ]]; then
    usermod -o -u "$target_uid" pzombie
  fi
}

main() {
  local server_password_was_set=0
  local server_port_was_set=0
  local server_udp_port_was_set=0
  local server_public_was_set=0
  local server_public_name_was_set=0
  local server_public_desc_was_set=0
  local server_max_player_was_set=0
  local mod_names_was_set=0
  local mod_workshop_ids_was_set=0
  local rcon_port_was_set=0
  local rcon_password_was_set=0
  local server_branch_was_set=0
  local server_ini
  local new_server_ini=0
  local target_uid
  local target_gid

  [[ -n "${SERVER_PASSWORD+x}" ]] && server_password_was_set=1
  [[ -n "${SERVER_PORT+x}" ]] && server_port_was_set=1
  [[ -n "${SERVER_UDP_PORT+x}" ]] && server_udp_port_was_set=1
  [[ -n "${SERVER_PUBLIC+x}" ]] && server_public_was_set=1
  [[ -n "${SERVER_PUBLIC_NAME+x}" ]] && server_public_name_was_set=1
  [[ -n "${SERVER_PUBLIC_DESC+x}" ]] && server_public_desc_was_set=1
  [[ -n "${SERVER_MAX_PLAYER+x}" ]] && server_max_player_was_set=1
  [[ -n "${MOD_NAMES+x}" ]] && mod_names_was_set=1
  [[ -n "${MOD_WORKSHOP_IDS+x}" ]] && mod_workshop_ids_was_set=1
  [[ -n "${RCON_PORT+x}" ]] && rcon_port_was_set=1
  [[ -n "${RCON_PASSWORD+x}" ]] && rcon_password_was_set=1
  [[ -n "${SERVER_BRANCH+x}" ]] && server_branch_was_set=1

  local server_name="${SERVER_NAME:-server}"
  local server_password="${SERVER_PASSWORD-}"
  local server_admin_password="${SERVER_ADMIN_PASSWORD:-pzadmin}"
  local server_port="${SERVER_PORT:-16261}"
  local server_udp_port="${SERVER_UDP_PORT:-16262}"
  local requested_server_branch="${SERVER_BRANCH-}"
  local server_public="${SERVER_PUBLIC:-false}"
  local server_public_name="${SERVER_PUBLIC_NAME-Project Zomboid Docker Server}"
  local server_public_desc="${SERVER_PUBLIC_DESC-}"
  local server_max_player="${SERVER_MAX_PLAYER:-16}"
  local mod_names="${MOD_NAMES-}"
  local mod_workshop_ids="${MOD_WORKSHOP_IDS-}"
  local rcon_port="${RCON_PORT:-27015}"
  local rcon_password="${RCON_PASSWORD-}"
  local update_on_start="${SERVER_UPDATE_ON_START:-true}"
  local validate_server_files="${SERVER_VALIDATE:-true}"
  local allow_branch_change="${ALLOW_BRANCH_CHANGE:-false}"
  local force_steamclient_update="${FORCESTEAMCLIENTSOUPDATE:-false}"
  local server_memory="${SERVER_MEMORY-}"
  local server_min_memory="${SERVER_MIN_MEMORY-}"
  local server_max_memory="${SERVER_MAX_MEMORY-}"

  target_uid="${PUID:-${UID:-1000}}"
  target_gid="${PGID:-${GID:-1000}}"

  [[ "$server_name" =~ ^[A-Za-z0-9._-]+$ ]] || \
    die "SERVER_NAME may contain only letters, numbers, dots, underscores, and hyphens."
  [[ "$server_port" =~ ^[0-9]+$ ]] || die "SERVER_PORT must be numeric."
  [[ "$server_udp_port" =~ ^[0-9]+$ ]] || die "SERVER_UDP_PORT must be numeric."
  [[ "$rcon_port" =~ ^[0-9]+$ ]] || die "RCON_PORT must be numeric."
  [[ "$server_max_player" =~ ^[0-9]+$ ]] || die "SERVER_MAX_PLAYER must be numeric."
  [[ "$server_admin_password" != *$'\n'* && "$server_admin_password" != *$'\r'* ]] || \
    die "SERVER_ADMIN_PASSWORD must be a single line."

  require_boolean "SERVER_PUBLIC" "$server_public"
  require_boolean "SERVER_UPDATE_ON_START" "$update_on_start"
  require_boolean "SERVER_VALIDATE" "$validate_server_files"
  require_boolean "ALLOW_BRANCH_CHANGE" "$allow_branch_change"
  require_boolean "FORCESTEAMCLIENTSOUPDATE" "$force_steamclient_update"

  if is_true "$server_public"; then
    server_public="true"
  else
    server_public="false"
  fi

  configure_runtime_user "$target_uid" "$target_gid"
  mkdir -p "$STEAMCMD_DIR" "$SERVER_DIR" "$CONFIG_DIR" "$PZ_HOME"
  ensure_config_symlink

  resolve_server_branch \
    "$requested_server_branch" \
    "$server_branch_was_set" \
    "$BRANCH_MARKER" \
    "$SAVE_DIR" \
    "$allow_branch_change"

  if [[ -n "$RECORDED_SERVER_BRANCH" \
        && "$RESOLVED_SERVER_BRANCH" != "$RECORDED_SERVER_BRANCH" ]]; then
    is_true "$update_on_start" || \
      die "SERVER_UPDATE_ON_START must be true while changing SERVER_BRANCH."
  fi

  if is_true "$update_on_start"; then
    install_steamcmd
    build_steamcmd_command "$RESOLVED_SERVER_BRANCH" "$validate_server_files"
    printf 'Updating Project Zomboid from Steam branch: %s\n' "$RESOLVED_SERVER_BRANCH"
    "${STEAMCMD_COMMAND[@]}"
  fi

  [[ -x "${SERVER_DIR}/start-server.sh" ]] || \
    die "${SERVER_DIR}/start-server.sh is missing. Enable SERVER_UPDATE_ON_START for the first installation or inspect the SteamCMD output."

  if [[ "$BRANCH_MARKER_NEEDS_UPDATE" == "1" ]]; then
    write_branch_marker "$RESOLVED_SERVER_BRANCH" "$BRANCH_MARKER"
  fi

  if is_true "$force_steamclient_update"; then
    install_steamcmd
    printf 'Updating steamclient.so in the Project Zomboid server...\n'
    cp "${STEAMCMD_DIR}/linux64/steamclient.so" "${SERVER_DIR}/linux64/steamclient.so"
    cp "${STEAMCMD_DIR}/linux32/steamclient.so" "${SERVER_DIR}/steamclient.so"
  fi

  server_ini="${CONFIG_DIR}/Server/${server_name}.ini"
  if [[ ! -f "$server_ini" ]]; then
    mkdir -p "$(dirname "$server_ini")"
    touch "$server_ini"
    new_server_ini=1
  fi

  should_apply_config "$new_server_ini" "$server_port_was_set" && \
    set_ini_option "$server_ini" "DefaultPort" "$server_port"
  should_apply_config "$new_server_ini" "$server_udp_port_was_set" && \
    set_ini_option "$server_ini" "UDPPort" "$server_udp_port"
  should_apply_config "$new_server_ini" "$server_password_was_set" && \
    set_ini_option "$server_ini" "Password" "$server_password"
  should_apply_config "$new_server_ini" "$server_public_was_set" && \
    set_ini_option "$server_ini" "Public" "$server_public"
  should_apply_config "$new_server_ini" "$server_public_name_was_set" && \
    set_ini_option "$server_ini" "PublicName" "$server_public_name"
  should_apply_config "$new_server_ini" "$server_public_desc_was_set" && \
    set_ini_option "$server_ini" "PublicDescription" "$server_public_desc"
  should_apply_config "$new_server_ini" "$rcon_port_was_set" && \
    set_ini_option "$server_ini" "RCONPort" "$rcon_port"
  should_apply_config "$new_server_ini" "$rcon_password_was_set" && \
    set_ini_option "$server_ini" "RCONPassword" "$rcon_password"
  should_apply_config "$new_server_ini" "$server_max_player_was_set" && \
    set_ini_option "$server_ini" "MaxPlayers" "$server_max_player"
  should_apply_config "$new_server_ini" "$mod_names_was_set" && \
    set_ini_option "$server_ini" "Mods" "$mod_names"
  should_apply_config "$new_server_ini" "$mod_workshop_ids_was_set" && \
    set_ini_option "$server_ini" "WorkshopItems" "$mod_workshop_ids"

  chown -R pzombie:pzombie "$STEAMCMD_DIR" "$SERVER_DIR" "$CONFIG_DIR" "$PZ_HOME"

  build_start_arguments \
    "$server_name" \
    "$server_admin_password" \
    "$server_memory" \
    "$server_min_memory" \
    "$server_max_memory"

  printf 'Launching Project Zomboid server: %s\n' "$server_name"
  cd "$SERVER_DIR"
  exec runuser -u pzombie -- env HOME="$PZ_HOME" ./start-server.sh "${START_ARGUMENTS[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

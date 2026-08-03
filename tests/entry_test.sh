#!/usr/bin/env bash

set -Eeuo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_DIRECTORY
REPOSITORY_DIRECTORY="$(cd "${TEST_DIRECTORY}/.." && pwd)"
readonly REPOSITORY_DIRECTORY

# The repository path is calculated at runtime so the test works from any directory.
# shellcheck disable=SC1091
source "${REPOSITORY_DIRECTORY}/entry.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/pz-entry-test.XXXXXX")"
readonly TEST_ROOT

cleanup() {
  case "$TEST_ROOT" in
    "${TMPDIR:-/tmp}"/pz-entry-test.*) rm -rf -- "$TEST_ROOT" ;;
    *) printf 'Refusing to remove unexpected test directory: %s\n' "$TEST_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  [[ "$actual" == "$expected" ]] || \
    fail "${message}: expected '${expected}', got '${actual}'"
}

assert_file_line() {
  local expected="$1"
  local file="$2"

  grep -Fqx -- "$expected" "$file" || \
    fail "Missing exact line '${expected}' in ${file}"
}

assert_fails() {
  local message="$1"
  shift

  if ("$@" >/dev/null 2>&1); then
    fail "${message}: command unexpectedly succeeded"
  fi
}

test_ini_writer_preserves_build_42_mod_names() {
  local ini_file="${TEST_ROOT}/server.ini"
  local mod_names='\RainWash;\EasyConfigChucked;\ExpandedHelicopterEvents'

  printf '%s\n' \
    'Public=true' \
    'Mods=old-value' \
    'Mods=duplicate-value' > "$ini_file"

  set_ini_option "$ini_file" "Mods" "$mod_names"

  assert_file_line "Mods=${mod_names}" "$ini_file"
  assert_equal "1" "$(grep -c '^Mods=' "$ini_file")" \
    "INI writer should collapse duplicate keys"

  set_ini_option "$ini_file" "Password" ""
  assert_file_line "Password=" "$ini_file"
}

test_existing_config_is_only_overridden_explicitly() {
  should_apply_config 1 0 || fail "New INI should receive defaults"
  should_apply_config 0 1 || fail "Explicit environment values should be applied"
  assert_fails "Existing INI should preserve manual values" should_apply_config 0 0
}

test_branch_migration_guard() {
  local marker="${TEST_ROOT}/branch-marker"
  local saves="${TEST_ROOT}/saves"

  mkdir -p "$saves"
  resolve_server_branch "" 0 "$marker" "$saves" false
  assert_equal "public" "$RESOLVED_SERVER_BRANCH" "Fresh install branch"
  assert_equal "1" "$BRANCH_MARKER_NEEDS_UPDATE" "Fresh install marker state"

  mkdir -p "${saves}/existing-world"
  assert_fails "Unmarked existing saves need an explicit branch" \
    resolve_server_branch "" 0 "$marker" "$saves" false

  resolve_server_branch "legacy41" 1 "$marker" "$saves" false
  assert_equal "legacy41" "$RESOLVED_SERVER_BRANCH" "Explicit migration branch"

  write_branch_marker "public" "$marker"
  assert_fails "Recorded branch changes need explicit approval" \
    resolve_server_branch "legacy41" 1 "$marker" "$saves" false

  resolve_server_branch "legacy41" 1 "$marker" "$saves" true
  assert_equal "public" "$RECORDED_SERVER_BRANCH" "Recorded branch"
  assert_equal "legacy41" "$RESOLVED_SERVER_BRANCH" "Approved branch change"
  assert_equal "1" "$BRANCH_MARKER_NEEDS_UPDATE" "Changed branch marker state"
}

test_steamcmd_arguments() {
  build_steamcmd_command "42.19" true

  assert_equal "${STEAMCMD_DIR}/steamcmd.sh" "${STEAMCMD_COMMAND[0]}" "SteamCMD path"
  assert_equal "-beta" "${STEAMCMD_COMMAND[7]}" "Steam beta option"
  assert_equal "42.19" "${STEAMCMD_COMMAND[8]}" "Steam beta branch"
  assert_equal "validate" "${STEAMCMD_COMMAND[9]}" "Steam validation option"
  assert_equal "+quit" "${STEAMCMD_COMMAND[10]}" "SteamCMD quit option"

  build_steamcmd_command "public" false
  assert_equal "+quit" "${STEAMCMD_COMMAND[7]}" "Public branch has no beta args"
  assert_equal "8" "${#STEAMCMD_COMMAND[@]}" "Public SteamCMD argument count"
}

test_jvm_memory_arguments() {
  build_start_arguments "server" "admin-password" "8g" "" ""

  assert_equal "-Xms8g" "${START_ARGUMENTS[0]}" "JVM minimum heap"
  assert_equal "-Xmx8g" "${START_ARGUMENTS[1]}" "JVM maximum heap"
  assert_equal "--" "${START_ARGUMENTS[2]}" "JVM argument separator"
  assert_equal "-servername" "${START_ARGUMENTS[3]}" "Server option"
  assert_equal "server" "${START_ARGUMENTS[4]}" "Server name"

  assert_fails "Invalid memory values should fail" \
    build_start_arguments "server" "password" "eight" "" ""
  assert_fails "Combined memory modes should fail" \
    build_start_arguments "server" "password" "8g" "2g" "8g"
}

test_ini_writer_preserves_build_42_mod_names
test_existing_config_is_only_overridden_explicitly
test_branch_migration_guard
test_steamcmd_arguments
test_jvm_memory_arguments

printf 'All entrypoint tests passed.\n'

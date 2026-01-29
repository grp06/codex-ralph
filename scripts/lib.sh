#!/usr/bin/env bash
set -euo pipefail

log_info() { printf "[INFO] %s\n" "$*"; }
log_warn() { printf "[WARN] %s\n" "$*"; }
log_error() { printf "[ERR] %s\n" "$*" >&2; }

read_config_value() {
  local key="$1"
  local config_path="$2"
  if [[ ! -f "$config_path" ]]; then
    return 0
  fi
  awk -F= -v k="$key" '
    $1 ~ "^[[:space:]]*" k "[[:space:]]*$" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      gsub(/^\"|\"$/, "", $2)
      print $2
      exit
    }
  ' "$config_path"
}

expand_path() {
  local path="$1"
  if [[ "$path" == "~"* ]]; then
    printf "%s" "${path/#\~/$HOME}"
  else
    printf "%s" "$path"
  fi
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is required."
    exit 1
  fi
}

require_docker_compose() {
  if ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose v2 is required (docker compose)."
    exit 1
  fi
}

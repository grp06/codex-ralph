#!/usr/bin/env bash
set -euo pipefail

if [[ "${RALPH_LOG_COLOR:-}" == "1" && -t 1 ]]; then
  C_RESET="\033[0m"
  C_RED="\033[0;31m"
  C_GREEN="\033[0;32m"
  C_YELLOW="\033[0;33m"
  C_BLUE="\033[0;34m"
  C_MAGENTA="\033[0;35m"
  C_CYAN="\033[0;36m"
else
  C_RESET=""
  C_RED=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_MAGENTA=""
  C_CYAN=""
fi

log_info() { printf "%b[INFO]%b %s\n" "$C_BLUE" "$C_RESET" "$*"; }
log_step() { printf "%b[STEP]%b %s\n" "$C_CYAN" "$C_RESET" "$*"; }
log_success() { printf "%b[OK]%b %s\n" "$C_GREEN" "$C_RESET" "$*"; }
log_warn() { printf "%b[WARN]%b %s\n" "$C_YELLOW" "$C_RESET" "$*"; }
log_error() { printf "%b[ERR]%b %s\n" "$C_RED" "$C_RESET" "$*" >&2; }

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

resolve_target_repo() {
  local arg_path="$1"
  local config_path="$2"
  local usage_fn="${3:-}"
  local project_path="$arg_path"

  if [[ -z "${project_path:-}" ]]; then
    project_path="$(read_config_value "target_repo_path" "$config_path")"
    project_path="$(expand_path "$project_path")"
    if [[ -z "${project_path:-}" ]]; then
      if [[ -n "$usage_fn" ]]; then
        "$usage_fn"
      fi
      log_error "Missing project path. Pass it as an argument or set target_repo_path in ralph.config.toml."
      exit 1
    fi
  fi

  if [[ ! -d "$project_path" ]]; then
    log_error "Project path does not exist: $project_path"
    exit 1
  fi

  if [[ ! -d "$project_path/.git" ]]; then
    log_error "Target project must be a git repo."
    exit 1
  fi

  printf "%s" "$project_path"
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

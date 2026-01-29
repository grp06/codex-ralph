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

require_file() {
  local path="$1"
  local message="$2"
  local hint="${3:-}"
  if [[ ! -f "$path" ]]; then
    log_error "$message"
    if [[ -n "$hint" ]]; then
      log_error "$hint"
    fi
    exit 1
  fi
}

preflight_deps() {
  if [[ "$#" -lt 2 ]]; then
    log_error "Usage: preflight-deps.sh <target-dir> <run-dir>"
    exit 1
  fi
  local target_dir="$1"
  local run_dir="$2"

  if [[ ! -d "$target_dir" ]]; then
    log_error "Target dir missing: $target_dir"
    exit 1
  fi

  local stamp_dir="$run_dir/.ralph"
  local stamp_path="$stamp_dir/deps-stamp"
  mkdir -p "$stamp_dir"

  local files=()
  [[ -f "$target_dir/package.json" ]] && files+=("$target_dir/package.json")
  [[ -f "$target_dir/package-lock.json" ]] && files+=("$target_dir/package-lock.json")
  [[ -f "$target_dir/pnpm-lock.yaml" ]] && files+=("$target_dir/pnpm-lock.yaml")
  [[ -f "$target_dir/yarn.lock" ]] && files+=("$target_dir/yarn.lock")
  [[ -f "$target_dir/.yarnrc.yml" ]] && files+=("$target_dir/.yarnrc.yml")

  if [[ "${#files[@]}" -eq 0 ]]; then
    exit 0
  fi

  local hash_cmd="sha256sum"
  if ! command -v sha256sum >/dev/null 2>&1; then
    hash_cmd="shasum -a 256"
  fi

  local hash
  hash="$({
    printf '%s\0' "${files[@]}"
    cat "${files[@]}"
  } | $hash_cmd | awk '{print $1}')"

  if [[ -f "$stamp_path" ]]; then
    local prev_hash prev_manager
    read -r prev_hash prev_manager < "$stamp_path" || true
    if [[ "$prev_hash" == "$hash" ]]; then
      exit 0
    fi
  fi

  local manager=""
  if [[ -f "$target_dir/pnpm-lock.yaml" ]]; then
    manager="pnpm"
  elif [[ -f "$target_dir/yarn.lock" ]]; then
    manager="yarn"
  elif [[ -f "$target_dir/package-lock.json" ]]; then
    manager="npm-ci"
  elif [[ -f "$target_dir/package.json" ]]; then
    manager="npm"
  fi

  if [[ -z "$manager" ]]; then
    exit 0
  fi

  cd "$target_dir"
  log_info "Installing dependencies ($manager)."

  case "$manager" in
    pnpm)
      if ! command -v pnpm >/dev/null 2>&1; then
        if command -v corepack >/dev/null 2>&1; then
          corepack enable
          corepack prepare pnpm@latest --activate
        fi
      fi
      if ! command -v pnpm >/dev/null 2>&1; then
        log_error "pnpm not available. Install pnpm or enable corepack."
        exit 1
      fi
      pnpm install --frozen-lockfile
      ;;
    yarn)
      if ! command -v yarn >/dev/null 2>&1; then
        if command -v corepack >/dev/null 2>&1; then
          corepack enable
          corepack prepare yarn@stable --activate
        fi
      fi
      if ! command -v yarn >/dev/null 2>&1; then
        log_error "yarn not available. Install yarn or enable corepack."
        exit 1
      fi
      if [[ -f .yarnrc.yml ]]; then
        yarn install --immutable
      else
        yarn install --frozen-lockfile
      fi
      ;;
    npm-ci)
      npm ci
      ;;
    npm)
      npm install
      ;;
    *)
      log_warn "No supported dependency manager found."
      exit 0
      ;;
  esac

  printf "%s %s\n" "$hash" "$manager" > "$stamp_path"
}

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

resolve_project_path() {
  local runner_root="$1"
  local arg_path="$2"
  local usage_fn="${3:-}"
  local config_path="$runner_root/ralph.config.toml"
  local project_path="$arg_path"

  if [[ -z "${project_path:-}" ]]; then
    project_path="$(read_config_value "target_repo_path" "$config_path")"
    if [[ "$project_path" == "~"* ]]; then
      project_path="${project_path/#\~/$HOME}"
    fi
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

docker_compose_checked() {
  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker is required."
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose v2 is required (docker compose)."
    exit 1
  fi

  docker compose "$@"
}

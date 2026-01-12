#!/usr/bin/env bash
set -euo pipefail

log_info() { printf "[INFO] %s\n" "$*"; }
log_error() { printf "[ERR] %s\n" "$*" >&2; }

usage() {
  printf "Usage:\n  %s [project-path] [iterations]\n" "$0"
}

runner_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_path="$runner_root/ralph.config.toml"

read_config_value() {
  local key="$1"
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

if [[ "$#" -lt 1 ]]; then
  project_path="$(read_config_value "target_repo_path")"
  project_path="$(expand_path "$project_path")"
  if [[ -z "${project_path:-}" ]]; then
    usage
    log_error "Missing project path. Pass it as an argument or set target_repo_path in ralph.config.toml."
    exit 1
  fi
else
  project_path="$1"
  shift
fi

if [[ ! -d "$project_path" ]]; then
  log_error "Project path does not exist: $project_path"
  exit 1
fi

if [[ ! -d "$project_path/.git" ]]; then
  log_error "Target project must be a git repo."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  log_error "Docker is required."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  log_error "Docker Compose v2 is required (docker compose)."
  exit 1
fi

project_abs="$(cd "$project_path" && pwd)"
project_name="${RALPH_PROJECT_NAME:-$(basename "$project_abs")}"
run_dir="$runner_root/runs/$project_name"
plans_path="$project_abs/.agent/PLANS.md"
plan_path="$project_abs/.agent/execplans/execplan.md"

mkdir -p "$run_dir"
mkdir -p "$run_dir/.ralph/logs"

if [[ ! -f "$plans_path" ]]; then
  log_error "Missing target rules: $plans_path"
  log_error "Run ./init-project.sh \"$project_abs\" first."
  exit 1
fi

if [[ ! -f "$plan_path" ]]; then
  log_error "Missing target plan: $plan_path"
  log_error "Run ./init-project.sh \"$project_abs\" first."
  exit 1
fi

cmd=("/workspace/afk-ralph.sh")
if [[ -n "${1:-}" ]]; then
  cmd+=("$1")
fi

docker compose run --rm \
  -e RALPH_IN_DOCKER=1 \
  -e RALPH_PLAN="/work/.agent/execplans/execplan.md" \
  -e RALPH_RULES="/work/.agent/PLANS.md" \
  -e RALPH_SCHEMA="/workspace/ralph.schema.json" \
  -e RALPH_OUTPUT="/workspace/runs/$project_name/.ralph/last.json" \
  -e RALPH_LOG_DIR="/workspace/runs/$project_name/.ralph/logs" \
  -e RALPH_RUN_DIR="/workspace/runs/$project_name" \
  -e RALPH_TARGET_DIR="/work" \
  -e RALPH_CONFIG="/workspace/ralph.config.toml" \
  -v "$project_abs:/work" \
  -w /work \
  ralph \
  "${cmd[@]}"

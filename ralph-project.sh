#!/usr/bin/env bash
set -euo pipefail

log_info() { printf "[INFO] %s\n" "$*"; }
log_error() { printf "[ERR] %s\n" "$*" >&2; }

usage() {
  printf "Usage:\n  %s <project-path> [iterations]\n" "$0"
}

if [[ "$#" -lt 1 ]]; then
  usage
  exit 1
fi

project_path="$1"
shift

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

runner_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_abs="$(cd "$project_path" && pwd)"
project_name="${RALPH_PROJECT_NAME:-$(basename "$project_abs")}"
run_dir="$runner_root/runs/$project_name"
plan_path="$run_dir/EXECPLAN.md"

mkdir -p "$run_dir"
mkdir -p "$run_dir/.ralph/logs"

if [[ ! -f "$plan_path" ]]; then
  template="$runner_root/templates/EXECPLAN.md"
  if [[ ! -f "$template" ]]; then
    log_error "Template missing: $template"
    exit 1
  fi
  cp "$template" "$plan_path"
  log_info "Created plan at $plan_path"
  log_info "Edit the plan, then re-run."
  exit 0
fi

cmd=("/workspace/afk-ralph.sh")
if [[ -n "${1:-}" ]]; then
  cmd+=("$1")
fi

docker compose run --rm \
  -e RALPH_IN_DOCKER=1 \
  -e RALPH_PLAN="/workspace/runs/$project_name/EXECPLAN.md" \
  -e RALPH_RULES="/workspace/.agent/PLANS.md" \
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

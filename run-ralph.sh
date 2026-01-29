#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

usage() {
  printf "Usage:\n  %s [project-path] [iterations]\n" "$0"
}

runner_root="$SCRIPT_DIR"

arg_path=""
if [[ "$#" -ge 1 ]]; then
  arg_path="$1"
  shift
fi
project_path="$(resolve_project_path "$runner_root" "$arg_path" usage)"

project_abs="$(cd "$project_path" && pwd)"
project_name="${RALPH_PROJECT_NAME:-$(basename "$project_abs")}"
run_dir="$runner_root/runs/$project_name"
plans_path="$project_abs/.agent/PLANS.md"
plan_path="$project_abs/.agent/execplans/execplan.md"

mkdir -p "$run_dir"
mkdir -p "$run_dir/.ralph/logs"

require_file_with_hint "$plans_path" "Missing target rules: $plans_path" "Run ./init-project.sh \"$project_abs\" first."
require_file_with_hint "$plan_path" "Missing target plan: $plan_path" "Run ./init-project.sh \"$project_abs\" first."

cmd=("/workspace/afk-ralph.sh")
if [[ -n "${1:-}" ]]; then
  cmd+=("$1")
fi

docker_compose_checked run --rm \
  -e RALPH_IN_DOCKER=1 \
  -e RALPH_PLAN="/work/.agent/execplans/execplan.md" \
  -e RALPH_RULES="/work/.agent/PLANS.md" \
  -e RALPH_SCHEMA="/workspace/ralph.schema.json" \
  -e RALPH_OUTPUT="/workspace/runs/$project_name/.ralph/last.json" \
  -e RALPH_LOG_DIR="/workspace/runs/$project_name/.ralph/logs" \
  -e RALPH_RUN_DIR="/workspace/runs/$project_name" \
  -e RALPH_HOST_RUN_DIR="$run_dir" \
  -e RALPH_TARGET_DIR="/work" \
  -e RALPH_CONFIG="/workspace/ralph.config.toml" \
  -v "$project_abs:/work" \
  -w /work \
  ralph \
  "${cmd[@]}"

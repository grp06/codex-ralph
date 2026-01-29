#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

usage() {
  printf "Usage:\n  %s [project-path]\n" "$0"
}

runner_root="$SCRIPT_DIR"

arg_path=""
if [[ "$#" -ge 1 ]]; then
  arg_path="$1"
fi
project_path="$(resolve_project_path "$runner_root" "$arg_path" usage)"

project_abs="$(cd "$project_path" && pwd)"

plans_src="$runner_root/templates/PLANS.md"

if [[ ! -f "$plans_src" ]]; then
  log_error "Missing template: $plans_src"
  exit 1
fi


agent_dir="$project_abs/.agent"
execplans_dir="$agent_dir/execplans"
plans_dest="$agent_dir/PLANS.md"
plan_dest="$execplans_dir/execplan.md"

mkdir -p "$execplans_dir"

if [[ -f "$plans_dest" ]]; then
  log_info "PLANS.md already exists at $plans_dest"
else
  cp "$plans_src" "$plans_dest"
  log_info "Created $plans_dest"
fi

if [[ -f "$plan_dest" ]]; then
  log_info "ExecPlan already exists at $plan_dest"
else
  cat > "$plan_dest" <<'EOF'
# <Project goal>

Maintained according to: .agent/PLANS.md
EOF
  log_info "Created $plan_dest"
fi

log_info "Edit the ExecPlan, then run ./run-ralph.sh \"$project_abs\""

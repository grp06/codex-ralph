#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

usage() {
  printf "Usage:\n  %s [project-path]\n" "$0"
}

runner_root="$SCRIPT_DIR"
config_path="$runner_root/ralph.config.toml"

if [[ "$#" -lt 1 ]]; then
  project_path="$(read_config_value "target_repo_path" "$config_path")"
  project_path="$(expand_path "$project_path")"
  if [[ -z "${project_path:-}" ]]; then
    usage
    log_error "Missing project path. Pass it as an argument or set target_repo_path in ralph.config.toml."
    exit 1
  fi
else
  project_path="$1"
fi

if [[ ! -d "$project_path" ]]; then
  log_error "Project path does not exist: $project_path"
  exit 1
fi

if [[ ! -d "$project_path/.git" ]]; then
  log_error "Target project must be a git repo."
  exit 1
fi

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

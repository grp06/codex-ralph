#!/usr/bin/env bash
set -euo pipefail

is_tty=0
if [[ -t 1 ]]; then
  is_tty=1
fi

if [[ "$is_tty" -eq 1 ]]; then
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
log_error() { printf "%b[ERR]%b %s\n" "$C_RED" "$C_RESET" "$*"; }

mkdir -p .ralph
mkdir -p .ralph/logs
mkdir -p .ralph/pnpm-cache .ralph/pnpm-store .ralph/pnpm-home .ralph/cache
timestamp="$(date +%Y%m%d-%H%M%S)"
log_file=".ralph/logs/ralph-once-$timestamp.log"
exec > >(tee -a "$log_file") 2>&1

log_info "Logging to $log_file"

log_step "Starting Ralph loop (one iteration)"
log_info "Plan: EXECPLAN.md"
log_info "Rules: .agent/PLANS.md"
log_info "Schema: ralph.schema.json"
log_info "Output: ./.ralph/last.json"

export XDG_CACHE_HOME="$PWD/.ralph/cache"
export PNPM_STORE_DIR="$PWD/.ralph/pnpm-store"
export PNPM_CACHE_DIR="$PWD/.ralph/pnpm-cache"
export PNPM_HOME="$PWD/.ralph/pnpm-home"
export NPM_CONFIG_CACHE="$PWD/.ralph/pnpm-cache"

codex exec \
  --model gpt-5.2-codex \
  --sandbox danger-full-access \
  -c 'shell_environment_policy.include_only=["PATH","HOME","TERM","SSH_AUTH_SOCK","XDG_CACHE_HOME","PNPM_STORE_DIR","PNPM_CACHE_DIR","PNPM_HOME","NPM_CONFIG_CACHE"]' \
  -c 'approval_policy="on-request"' \
  --output-schema ./ralph.schema.json \
  -o ./.ralph/last.json \
  - <<'PROMPT'
You are running a Ralph loop iteration.

Read these files:
- .agent/PLANS.md (ExecPlan rules)
- EXECPLAN.md (the plan you must follow)

Do EXACTLY ONE unit of work:
1) Find the next unchecked item in EXECPLAN.md > Progress.
   - If it is too big, split it into smaller items and complete only the first new item.
2) Implement the change.
3) Run the Validation commands listed in EXECPLAN.md.
4) Make exactly one git commit with a clear message.
5) Update EXECPLAN.md:
   - Check the Progress item you completed (add date/timestamp in the checkbox line).
   - Update Surprises & Discoveries / Decision Log if relevant.

If all Progress items are complete, do not change code; just return status COMPLETE.

Return ONLY a JSON object matching the output schema.
PROMPT

cat ./.ralph/last.json
log_success "Ralph iteration complete"

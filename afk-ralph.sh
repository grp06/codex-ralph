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

iters="${1:-}"
if [[ -z "$iters" ]]; then
  iters="forever"
  log_warn "No iteration cap set; will run until COMPLETE or BLOCKED."
fi

mkdir -p .ralph/logs
mkdir -p .ralph/pnpm-cache .ralph/pnpm-store .ralph/pnpm-home .ralph/cache
timestamp="$(date +%Y%m%d-%H%M%S)"
log_file=".ralph/logs/afk-ralph-$timestamp.log"
exec > >(tee -a "$log_file") 2>&1

log_info "Logging to $log_file"

export XDG_CACHE_HOME="$PWD/.ralph/cache"
export PNPM_STORE_DIR="$PWD/.ralph/pnpm-store"
export PNPM_CACHE_DIR="$PWD/.ralph/pnpm-cache"
export PNPM_HOME="$PWD/.ralph/pnpm-home"
export NPM_CONFIG_CACHE="$PWD/.ralph/pnpm-cache"

progress_remaining() {
  awk '
    /^##[[:space:]]+Progress/ { in_progress=1; next }
    /^##[[:space:]]+/ { if (in_progress) exit }
    {
      if (in_progress && $0 ~ /^- \[ \]/) count++
    }
    END { print count + 0 }
  ' EXECPLAN.md
}

for ((i=1; ; i++)); do
  if [[ "$iters" == "forever" ]]; then
    log_step "Ralph iteration $i"
  else
    log_step "Ralph iteration $i/$iters"
  fi
  log_info "Plan: EXECPLAN.md"
  log_info "Rules: .agent/PLANS.md"
  log_info "Schema: ralph.schema.json"
  log_info "Output: ./.ralph/last.json"

  codex exec \
    --model gpt-5.2-codex \
    --sandbox danger-full-access \
    -c 'shell_environment_policy.include_only=["PATH","HOME","TERM","SSH_AUTH_SOCK","XDG_CACHE_HOME","PNPM_STORE_DIR","PNPM_CACHE_DIR","PNPM_HOME","NPM_CONFIG_CACHE"]' \
    -c 'approval_policy="never"' \
    --output-schema ./ralph.schema.json \
    -o ./.ralph/last.json \
    - <<'PROMPT'
Ralph loop iteration.

Read .agent/PLANS.md and EXECPLAN.md.
Do exactly ONE unchecked Progress item (or split and do the first slice).
Implement, validate, commit once, update EXECPLAN.md.

Return ONLY JSON matching the output schema:
- status = COMPLETE if Progress is fully done.
- status = BLOCKED if you cannot proceed without human input.
PROMPT

  status="$(jq -r .status ./.ralph/last.json)"
  log_info "status=$status"

  remaining="$(progress_remaining)"
  if [[ "$remaining" -eq 0 ]]; then
    log_success "Progress complete after $i iterations."
    exit 0
  fi

  if [[ "$status" == "COMPLETE" && "$remaining" -gt 0 ]]; then
    log_warn "Agent reported COMPLETE but Progress still has $remaining open item(s). Continuing."
  fi

  if [[ "$status" == "BLOCKED" ]]; then
    log_warn "Blocked on iteration $i. See ./.ralph/last.json"
    exit 2
  fi

  if [[ "$iters" != "forever" && "$i" -ge "$iters" ]]; then
    break
  fi
done

if [[ "$iters" == "forever" ]]; then
  log_warn "Stopped (unexpected exit without COMPLETE/BLOCKED)."
else
  log_warn "Stopped after $iters iterations (cap reached)."
fi

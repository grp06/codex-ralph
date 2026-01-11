#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${RALPH_IN_DOCKER:-}" ]]; then
  ./docker/run.sh ./afk-ralph.sh "$@"
  exit $?
fi

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

PLAN_PATH="${RALPH_PLAN:-EXECPLAN.md}"
RULES_PATH="${RALPH_RULES:-.agent/PLANS.md}"
SCHEMA_PATH="${RALPH_SCHEMA:-ralph.schema.json}"
OUTPUT_PATH="${RALPH_OUTPUT:-./.ralph/last.json}"
RUN_DIR="${RALPH_RUN_DIR:-$PWD}"
LOG_DIR="${RALPH_LOG_DIR:-$RUN_DIR/.ralph/logs}"
TARGET_DIR="${RALPH_TARGET_DIR:-$PWD}"
CONFIG_PATH="${RALPH_CONFIG:-$PWD/ralph.config.toml}"

if [[ -n "${RALPH_CONFIG:-}" && ! -f "$CONFIG_PATH" ]]; then
  log_error "Missing config: $CONFIG_PATH"
  exit 1
fi

REASONING_EFFORT="medium"
if [[ -f "$CONFIG_PATH" ]]; then
  parsed_effort="$(awk -F= '/^[[:space:]]*model_reasoning_effort[[:space:]]*=/{print $2; exit}' "$CONFIG_PATH" | tr -d ' \"')"
  if [[ -n "$parsed_effort" ]]; then
    REASONING_EFFORT="$parsed_effort"
  fi
fi

case "$REASONING_EFFORT" in
  minimal|low|medium|high|xhigh) ;;
  *)
    log_error "Invalid model_reasoning_effort: $REASONING_EFFORT (expected minimal|low|medium|high|xhigh)"
    exit 1
    ;;
esac

if [[ ! -f "$PLAN_PATH" ]]; then
  log_error "Missing plan: $PLAN_PATH"
  exit 1
fi

if [[ ! -f "$RULES_PATH" ]]; then
  log_error "Missing rules: $RULES_PATH"
  exit 1
fi

if [[ ! -f "$SCHEMA_PATH" ]]; then
  log_error "Missing schema: $SCHEMA_PATH"
  exit 1
fi

iters="${1:-}"
if [[ -z "$iters" ]]; then
  iters="forever"
  log_warn "No iteration cap set; will run until COMPLETE or BLOCKED."
fi

mkdir -p "$RUN_DIR/.ralph/logs"
mkdir -p "$LOG_DIR"
mkdir -p "$RUN_DIR/.ralph/pnpm-cache" "$RUN_DIR/.ralph/pnpm-store" "$RUN_DIR/.ralph/pnpm-home" "$RUN_DIR/.ralph/cache"

export XDG_CACHE_HOME="$RUN_DIR/.ralph/cache"
export PNPM_STORE_DIR="$RUN_DIR/.ralph/pnpm-store"
export PNPM_CACHE_DIR="$RUN_DIR/.ralph/pnpm-cache"
export PNPM_HOME="$RUN_DIR/.ralph/pnpm-home"
export NPM_CONFIG_CACHE="$RUN_DIR/.ralph/pnpm-cache"

progress_remaining() {
  awk '
    /^##[[:space:]]+Progress/ { in_progress=1; next }
    /^##[[:space:]]+/ { if (in_progress) exit }
    {
      if (in_progress && $0 ~ /^- \[ \]/) count++
    }
    END { print count + 0 }
  ' "$PLAN_PATH"
}

cd "$TARGET_DIR"

exec 3>&1 4>&2
restore_io() { exec 1>&3 2>&4; }

for ((i=1; ; i++)); do
  timestamp="$(date +%Y%m%d-%H%M%S)"
  log_file="$LOG_DIR/afk-ralph-$timestamp-iter-$i.log"
  exec > >(tee -a "$log_file") 2>&1
  log_info "Logging to $log_file"
  if [[ "$iters" == "forever" ]]; then
    log_step "Ralph iteration $i"
  else
    log_step "Ralph iteration $i/$iters"
  fi
  log_info "Plan: $PLAN_PATH"
  log_info "Rules: $RULES_PATH"
  log_info "Schema: $SCHEMA_PATH"
  log_info "Output: $OUTPUT_PATH"

  codex exec \
    --model gpt-5.2-codex \
    --sandbox danger-full-access \
    -c 'shell_environment_policy.include_only=["PATH","HOME","TERM","SSH_AUTH_SOCK","XDG_CACHE_HOME","PNPM_STORE_DIR","PNPM_CACHE_DIR","PNPM_HOME","NPM_CONFIG_CACHE"]' \
    -c "model_reasoning_effort=\"$REASONING_EFFORT\"" \
    -c 'approval_policy="never"' \
    --output-schema "$SCHEMA_PATH" \
    -o "$OUTPUT_PATH" \
    - <<PROMPT
Ralph loop iteration.

Read these files:
- $RULES_PATH
- $PLAN_PATH
Do exactly ONE unchecked Progress item (or split and do the first slice).
Implement, validate, commit once, update the plan.

Return ONLY JSON matching the output schema:
- status = COMPLETE if Progress is fully done.
- status = BLOCKED if you cannot proceed without human input.
PROMPT

  status="$(jq -r .status "$OUTPUT_PATH")"
  log_info "status=$status"

  remaining="$(progress_remaining)"
  if [[ "$remaining" -eq 0 ]]; then
    log_success "Progress complete after $i iterations."
    restore_io
    exit 0
  fi

  if [[ "$status" == "COMPLETE" && "$remaining" -gt 0 ]]; then
    log_warn "Agent reported COMPLETE but Progress still has $remaining open item(s). Continuing."
  fi

  if [[ "$status" == "BLOCKED" ]]; then
    log_warn "Blocked on iteration $i. See $OUTPUT_PATH"
    restore_io
    exit 2
  fi

  if [[ "$iters" != "forever" && "$i" -ge "$iters" ]]; then
    restore_io
    break
  fi

  restore_io
done

if [[ "$iters" == "forever" ]]; then
  log_warn "Stopped (unexpected exit without COMPLETE/BLOCKED)."
else
  log_warn "Stopped after $iters iterations (cap reached)."
fi

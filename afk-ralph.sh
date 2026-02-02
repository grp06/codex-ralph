#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${RALPH_IN_DOCKER:-}" ]]; then
  source "$SCRIPT_DIR/scripts/lib.sh"
  log_error "afk-ralph.sh must be run inside Docker. Use ./run-ralph.sh <project-path>."
  exit 1
fi

: "${RALPH_LOG_COLOR:=1}"
source "$SCRIPT_DIR/scripts/lib.sh"

PLAN_PATH="${RALPH_PLAN:-EXECPLAN.md}"
RULES_PATH="${RALPH_RULES:-.agent/PLANS.md}"
SCHEMA_PATH="${RALPH_SCHEMA:-ralph.schema.json}"
OUTPUT_PATH="${RALPH_OUTPUT:-./.ralph/last.json}"
RUN_DIR="${RALPH_RUN_DIR:-$PWD}"
LOG_DIR="${RALPH_LOG_DIR:-$RUN_DIR/.ralph/logs}"
TARGET_DIR="${RALPH_TARGET_DIR:-$PWD}"
CONFIG_PATH="${RALPH_CONFIG:-$PWD/ralph.config.toml}"
HOST_RUN_DIR="${RALPH_HOST_RUN_DIR:-}"
HOST_LOG_DIR=""
if [[ -n "$HOST_RUN_DIR" ]]; then
  HOST_LOG_DIR="$HOST_RUN_DIR/.ralph/logs"
fi

if [[ -n "${RALPH_CONFIG:-}" ]]; then
  require_file "$CONFIG_PATH" "Missing config: $CONFIG_PATH"
fi

REASONING_EFFORT="medium"
if [[ -f "$CONFIG_PATH" ]]; then
  parsed_effort="$(read_config_value "model_reasoning_effort" "$CONFIG_PATH")"
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

require_file "$PLAN_PATH" "Missing plan: $PLAN_PATH"

require_file "$RULES_PATH" "Missing rules: $RULES_PATH"

require_file "$SCHEMA_PATH" "Missing schema: $SCHEMA_PATH"

iters="${1:-}"
if [[ -z "$iters" ]]; then
  iters="forever"
  log_warn "No iteration cap set; will run until COMPLETE or BLOCKED."
fi

mkdir -p "$RUN_DIR/.ralph/logs"
mkdir -p "$LOG_DIR"
mkdir -p "$RUN_DIR/.ralph/pnpm-cache" "$RUN_DIR/.ralph/pnpm-store" "$RUN_DIR/.ralph/pnpm-home" "$RUN_DIR/.ralph/cache" "$RUN_DIR/.ralph/yarn-cache"

export XDG_CACHE_HOME="$RUN_DIR/.ralph/cache"
export PNPM_STORE_DIR="$RUN_DIR/.ralph/pnpm-store"
export PNPM_CACHE_DIR="$RUN_DIR/.ralph/pnpm-cache"
export PNPM_HOME="$RUN_DIR/.ralph/pnpm-home"
export NPM_CONFIG_CACHE="$RUN_DIR/.ralph/pnpm-cache"
export YARN_CACHE_FOLDER="$RUN_DIR/.ralph/yarn-cache"
export PATH="$PNPM_HOME:$PATH"

PREFLIGHT="${RALPH_PREFLIGHT:-1}"

normalize_text() {
  tr '\n' ' ' | tr -s ' '
}

ensure_run_logs_line() {
  if grep -q "^Run Logs:" "$PLAN_PATH"; then
    return 0
  fi
  local line="Run Logs: container=$LOG_DIR"
  if [[ -n "$HOST_LOG_DIR" ]]; then
    line="$line; host=$HOST_LOG_DIR"
  fi
  awk -v line="$line" '
    BEGIN { inserted=0 }
    {
      print $0
      if ($0 ~ /^##[[:space:]]+Context[[:space:]]+and[[:space:]]+Orientation/ && inserted==0) {
        print ""
        print line
        inserted=1
      }
    }
    END {
      if (inserted==0) {
        print ""
        print "## Context and Orientation"
        print ""
        print line
      }
    }
  ' "$PLAN_PATH" > "$PLAN_PATH.tmp" && mv "$PLAN_PATH.tmp" "$PLAN_PATH"
}

append_blocker() {
  local log_file="$1"
  if [[ -z "$log_file" ]]; then
    return 0
  fi
  if grep -Fq "$log_file" "$PLAN_PATH"; then
    return 0
  fi
  local did notes next
  did="$(jq -r '.did // ""' "$OUTPUT_PATH" 2>/dev/null | normalize_text)"
  notes="$(jq -r '.notes // ""' "$OUTPUT_PATH" 2>/dev/null | normalize_text)"
  next="$(jq -r '.next // ""' "$OUTPUT_PATH" 2>/dev/null | normalize_text)"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local host_log_file=""
  if [[ -n "$HOST_LOG_DIR" && "$log_file" == "$LOG_DIR"* ]]; then
    host_log_file="${HOST_LOG_DIR}${log_file#$LOG_DIR}"
  fi
  local entry="- Blocker ($ts): ${did:-"(no details)"}"
  local evidence="  Evidence: status=BLOCKED; log=$log_file"
  if [[ -n "$host_log_file" ]]; then
    evidence="$evidence; host_log=$host_log_file"
  fi
  if [[ -n "$notes" && "$notes" != "null" ]]; then
    evidence="$evidence; notes=$notes"
  fi
  if [[ -n "$next" && "$next" != "null" ]]; then
    evidence="$evidence; next=$next"
  fi
  ensure_run_logs_line
  awk -v e1="$entry" -v e2="$evidence" '
    BEGIN { inserted=0 }
    {
      print $0
      if ($0 ~ /^##[[:space:]]+Surprises[[:space:]]+&[[:space:]]+Discoveries/ && inserted==0) {
        print ""
        print e1
        print e2
        inserted=1
      }
    }
    END {
      if (inserted==0) {
        print ""
        print "## Surprises & Discoveries"
        print ""
        print e1
        print e2
      }
    }
  ' "$PLAN_PATH" > "$PLAN_PATH.tmp" && mv "$PLAN_PATH.tmp" "$PLAN_PATH"
}

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
  if [[ "$PREFLIGHT" != "0" ]]; then
    preflight_deps "$TARGET_DIR" "$RUN_DIR"
  fi
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
Run logs:
- container: $LOG_DIR
- host: ${HOST_LOG_DIR:-"(not set)"}
Do exactly ONE unchecked Progress item (or split and do the first slice).
Implement, validate, commit once, update the plan.
Use the target repo at $TARGET_DIR for all code changes and git commands.

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
    append_blocker "$log_file"
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

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib.sh"

if [[ "$#" -eq 0 ]]; then
  log_error "Usage: ./docker/run.sh <command...>"
  exit 1
fi

log_info "Running in Docker."
docker_compose_run_checked -e RALPH_IN_DOCKER=1 ralph "$@"

#!/usr/bin/env bash
set -euo pipefail

log_info() { printf "[INFO] %s\n" "$*"; }
log_error() { printf "[ERR] %s\n" "$*" >&2; }

if [[ "$#" -eq 0 ]]; then
  log_error "Usage: ./docker/run.sh <command...>"
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

log_info "Running in Docker."
docker compose run --rm -e RALPH_IN_DOCKER=1 ralph "$@"

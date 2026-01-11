#!/usr/bin/env bash
set -euo pipefail

log_info() { printf "[INFO] %s\n" "$*"; }
log_error() { printf "[ERR] %s\n" "$*" >&2; }

if ! command -v docker >/dev/null 2>&1; then
  log_error "Docker is required."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  log_error "Docker Compose v2 is required (docker compose)."
  exit 1
fi

log_info "Building Docker image."
docker compose build

log_info "Installing Codex CLI and authenticating."
docker compose run --rm ralph /workspace/docker/codex-setup.sh

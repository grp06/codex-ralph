#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

require_docker_env

log_info "Building Docker image."
docker compose build

log_info "Installing Codex CLI and authenticating."
docker compose run --rm ralph /workspace/docker/codex-setup.sh

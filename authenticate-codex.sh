#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

log_info "Building Docker image."
docker_compose_checked build

log_info "Installing Codex CLI and authenticating."
docker_compose_run_checked ralph /workspace/docker/codex-setup.sh

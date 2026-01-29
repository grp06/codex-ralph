#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/lib.sh"

mkdir -p "$HOME"
mkdir -p "$CODEX_HOME"

if ! command -v npm >/dev/null 2>&1; then
  log_error "npm is required to install Codex CLI."
  exit 1
fi

if ! command -v codex >/dev/null 2>&1; then
  log_info "Installing Codex CLI."
  npm install -g @openai/codex
else
  log_info "Codex CLI already installed."
fi

config_file="$HOME/.codex/config.toml"
mkdir -p "$(dirname "$config_file")"
if [[ ! -f "$config_file" ]]; then
  printf 'cli_auth_credentials_store = "file"\n' > "$config_file"
else
  if grep -q '^cli_auth_credentials_store' "$config_file"; then
    if ! grep -q '^cli_auth_credentials_store = "file"' "$config_file"; then
      sed -i 's/^cli_auth_credentials_store.*/cli_auth_credentials_store = \"file\"/' "$config_file"
    fi
  else
    printf '\ncli_auth_credentials_store = "file"\n' >> "$config_file"
  fi
fi

if codex login status >/dev/null 2>&1; then
  log_info "Codex already authenticated."
  exit 0
fi

printf "Auth method:\n1) ChatGPT login\n2) ChatGPT device login\n3) API key\n> "
read -r choice

case "$choice" in
  1)
    codex login
    ;;
  2|"")
    codex login --device-auth
    ;;
  3)
    read -r -s -p "API key: " api_key
    printf "\n"
    codex login --api-key "$api_key"
    ;;
  *)
    log_error "Invalid choice."
    exit 1
    ;;
esac

codex login status

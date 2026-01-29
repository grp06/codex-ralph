#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

if [[ "$#" -lt 2 ]]; then
  log_error "Usage: preflight-deps.sh <target-dir> <run-dir>"
  exit 1
fi

target_dir="$1"
run_dir="$2"

if [[ ! -d "$target_dir" ]]; then
  log_error "Target dir missing: $target_dir"
  exit 1
fi

stamp_dir="$run_dir/.ralph"
stamp_path="$stamp_dir/deps-stamp"
mkdir -p "$stamp_dir"

files=()
[[ -f "$target_dir/package.json" ]] && files+=("$target_dir/package.json")
[[ -f "$target_dir/package-lock.json" ]] && files+=("$target_dir/package-lock.json")
[[ -f "$target_dir/pnpm-lock.yaml" ]] && files+=("$target_dir/pnpm-lock.yaml")
[[ -f "$target_dir/yarn.lock" ]] && files+=("$target_dir/yarn.lock")
[[ -f "$target_dir/.yarnrc.yml" ]] && files+=("$target_dir/.yarnrc.yml")

if [[ "${#files[@]}" -eq 0 ]]; then
  exit 0
fi

hash_cmd="sha256sum"
if ! command -v sha256sum >/dev/null 2>&1; then
  hash_cmd="shasum -a 256"
fi

hash="$({
  printf '%s\0' "${files[@]}"
  cat "${files[@]}"
} | $hash_cmd | awk '{print $1}')"

if [[ -f "$stamp_path" ]]; then
  read -r prev_hash prev_manager < "$stamp_path" || true
  if [[ "$prev_hash" == "$hash" ]]; then
    exit 0
  fi
fi

manager=""
if [[ -f "$target_dir/pnpm-lock.yaml" ]]; then
  manager="pnpm"
elif [[ -f "$target_dir/yarn.lock" ]]; then
  manager="yarn"
elif [[ -f "$target_dir/package-lock.json" ]]; then
  manager="npm-ci"
elif [[ -f "$target_dir/package.json" ]]; then
  manager="npm"
fi

if [[ -z "$manager" ]]; then
  exit 0
fi

cd "$target_dir"
log_info "Installing dependencies ($manager)."

case "$manager" in
  pnpm)
    if ! command -v pnpm >/dev/null 2>&1; then
      if command -v corepack >/dev/null 2>&1; then
        corepack enable
        corepack prepare pnpm@latest --activate
      fi
    fi
    if ! command -v pnpm >/dev/null 2>&1; then
      log_error "pnpm not available. Install pnpm or enable corepack."
      exit 1
    fi
    pnpm install --frozen-lockfile
    ;;
  yarn)
    if ! command -v yarn >/dev/null 2>&1; then
      if command -v corepack >/dev/null 2>&1; then
        corepack enable
        corepack prepare yarn@stable --activate
      fi
    fi
    if ! command -v yarn >/dev/null 2>&1; then
      log_error "yarn not available. Install yarn or enable corepack."
      exit 1
    fi
    if [[ -f .yarnrc.yml ]]; then
      yarn install --immutable
    else
      yarn install --frozen-lockfile
    fi
    ;;
  npm-ci)
    npm ci
    ;;
  npm)
    npm install
    ;;
  *)
    log_warn "No supported dependency manager found."
    exit 0
    ;;
esac

printf "%s %s\n" "$hash" "$manager" > "$stamp_path"

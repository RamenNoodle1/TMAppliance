#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s %s\n' "$(date --iso-8601=seconds)" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "This script must run as root."
  fi
}

retry() {
  local attempts="$1"
  shift
  local delay_seconds="$1"
  shift
  local attempt=1

  until "$@"; do
    if (( attempt >= attempts )); then
      return 1
    fi

    log "Command failed (attempt ${attempt}/${attempts}): $*"
    sleep "${delay_seconds}"
    attempt=$((attempt + 1))
  done
}

wait_for_network() {
  local target="${1:-8.8.8.8}"
  local timeout_seconds="${2:-300}"
  local waited=0

  until ping -c 1 "${target}" >/dev/null 2>&1; do
    if (( waited >= timeout_seconds )); then
      return 1
    fi

    log "Waiting for network connectivity to ${target}..."
    sleep 5
    waited=$((waited + 5))
  done
}

load_env() {
  local env_file="${1:-/etc/techmarvel/appliance.env}"

  if [[ ! -f "${env_file}" ]]; then
    fail "Missing configuration file: ${env_file}"
  fi

  set -a
  # shellcheck disable=SC1090
  . "${env_file}"
  set +a
}

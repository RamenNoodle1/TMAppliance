#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/docker-common.sh"

main() {
  require_root

  if ! command -v tailscale >/dev/null 2>&1; then
    log "Tailscale is not installed. Nothing to do."
    return
  fi

  log "Logging out of Tailscale..."
  tailscale logout || true

  log "Stopping and disabling tailscaled..."
  systemctl stop tailscaled || true
  systemctl disable tailscaled || true

  log "Removing Tailscale packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get remove -y tailscale || true
  rm -f /etc/apt/sources.list.d/tailscale.list
  apt-get autoremove -y || true

  log "Tailscale removed."
}

main "$@"

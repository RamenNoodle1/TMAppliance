#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/docker-common.sh"

# Optional: set TAILSCALE_AUTH_KEY to authenticate automatically.
# If unset, the machine will appear in the Tailscale admin console as pending.

main() {
  require_root

  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale is already installed ($(tailscale --version | head -1))."
    systemctl enable tailscaled >/dev/null 2>&1 || true
    systemctl start tailscaled
  else
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    systemctl enable tailscaled
    systemctl start tailscaled
    log "Tailscale installed successfully."
  fi

  if tailscale status >/dev/null 2>&1; then
    log "Tailscale is already authenticated."
    return
  fi

  if [[ -n "${TAILSCALE_AUTH_KEY:-}" ]]; then
    log "Authenticating Tailscale with provided auth key..."
    tailscale up --authkey="${TAILSCALE_AUTH_KEY}" --accept-routes
    log "Tailscale authenticated. Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'pending')"
  else
    log "TAILSCALE_AUTH_KEY not set — machine will appear as pending in the Tailscale admin console."
    log "Run: tailscale up --authkey=<key> to authenticate manually."
  fi
}

main "$@"

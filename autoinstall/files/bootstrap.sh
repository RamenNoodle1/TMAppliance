#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_LOG="/var/log/techmarvel-bootstrap.log"
mkdir -p "$(dirname "${BOOTSTRAP_LOG}")"
exec >> "${BOOTSTRAP_LOG}" 2>&1

source /opt/techmarvel/bin/common.sh

main() {
  require_root
  load_env

  mkdir -p /var/lib/techmarvel

  if [[ -f /var/lib/techmarvel/bootstrap-complete ]]; then
    log "Bootstrap already completed. Nothing to do."
    exit 0
  fi

  export DEBIAN_FRONTEND=noninteractive

  log "Starting first-boot bootstrap."

  wait_for_network "${BOOTSTRAP_PING_TARGET:-8.8.8.8}" "${NETWORK_WAIT_TIMEOUT_SECONDS:-300}" \
    || fail "Network did not become ready within the configured timeout."

  log "Refreshing apt metadata..."
  retry 3 15 apt-get update

  if [[ "${APPLY_APT_UPGRADES:-true}" == "true" ]]; then
    log "Applying package upgrades..."
    retry 3 15 apt-get -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confold" \
      upgrade
  else
    log "Skipping package upgrades because APPLY_APT_UPGRADES=false."
  fi

  /opt/techmarvel/bin/install-syncro.sh

  touch /var/lib/techmarvel/bootstrap-complete
  log "Bootstrap completed successfully."
}

main "$@"

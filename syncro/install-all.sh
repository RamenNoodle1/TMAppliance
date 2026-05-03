#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DEVICE_ROLE="${DEVICE_ROLE:-standard}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Applying role: ${DEVICE_ROLE}"

case "${DEVICE_ROLE}" in
  standard)
    "${SCRIPT_DIR}/docker/install-docker.sh"
    "${SCRIPT_DIR}/tailscale/install.sh"
    "${SCRIPT_DIR}/containers/domotz/install.sh"
    "${SCRIPT_DIR}/containers/uptime-kuma/install.sh"
    "${SCRIPT_DIR}/containers/openspeedtest/install.sh"
    "${SCRIPT_DIR}/containers/speedtest-tracker/install.sh"
    "${SCRIPT_DIR}/containers/homepage/install.sh"
    ;;
  # To add a role: copy the 'standard' block above, change the label,
  # and include only the installers that role needs.
  *)
    echo "ERROR: Unknown DEVICE_ROLE '${DEVICE_ROLE}'. Aborting." >&2
    exit 1
    ;;
esac

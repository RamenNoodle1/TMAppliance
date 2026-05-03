#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"${SCRIPT_DIR}/docker/install-docker.sh"
"${SCRIPT_DIR}/containers/domotz/install.sh"
"${SCRIPT_DIR}/containers/uptime-kuma/install.sh"
"${SCRIPT_DIR}/containers/openspeedtest/install.sh"
"${SCRIPT_DIR}/containers/speedtest-tracker/install.sh"
"${SCRIPT_DIR}/containers/homepage/install.sh"

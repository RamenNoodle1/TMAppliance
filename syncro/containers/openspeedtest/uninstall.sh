#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../common/docker-common.sh"

main() {
  require_root

  local app_dir="/opt/techmarvel/apps/openspeedtest"
  if [[ -f "${app_dir}/compose.yaml" ]]; then
    ensure_docker_ready
    compose_down "${app_dir}"
  fi

  maybe_purge_dir "${app_dir}"
  log "OpenSpeedTest removed. Data preserved unless PURGE_DATA=true."
}

main "$@"

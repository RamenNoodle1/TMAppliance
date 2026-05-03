#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../common/docker-common.sh"

main() {
  require_root
  ensure_docker_ready

  local app_dir="/opt/techmarvel/apps/openspeedtest"
  ensure_dir "${app_dir}"

  copy_file "${SCRIPT_DIR}/compose.yaml" "${app_dir}/compose.yaml" 0644

  compose_up "${app_dir}"
  log "OpenSpeedTest deployed in ${app_dir}."
}

main "$@"

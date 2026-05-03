#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../common/docker-common.sh"

generate_app_key() {
  printf 'base64:%s\n' "$(head -c 32 /dev/urandom | base64 | tr -d '\n')"
}

main() {
  require_root
  ensure_docker_ready

  local app_dir="/opt/techmarvel/apps/speedtest-tracker"
  local host_ip app_url app_key

  host_ip="${APPLIANCE_HOST:-$(detect_primary_ip)}"
  app_url="${SPEEDTEST_TRACKER_APP_URL:-http://${host_ip}:8982}"
  app_key="${SPEEDTEST_TRACKER_APP_KEY:-$(generate_app_key)}"

  ensure_dir "${app_dir}/config"

  copy_file "${SCRIPT_DIR}/compose.yaml" "${app_dir}/compose.yaml" 0644
  render_template \
    "${SCRIPT_DIR}/.env.template" \
    "${app_dir}/.env" \
    "__APP_KEY__=${app_key}" \
    "__APP_URL__=${app_url}" \
    "__APP_TIMEZONE__=${APP_TIMEZONE:-America/New_York}" \
    "__DISPLAY_TIMEZONE__=${DISPLAY_TIMEZONE:-America/New_York}" \
    "__SPEEDTEST_SCHEDULE__=${SPEEDTEST_SCHEDULE:-0 */2 * * *}"

  if [[ ! -f "${app_dir}/.env.initialized" ]]; then
    cp "${app_dir}/.env" "${app_dir}/.env.initialized"
  fi

  compose_up "${app_dir}"
  log "Speedtest Tracker deployed in ${app_dir}."
}

main "$@"

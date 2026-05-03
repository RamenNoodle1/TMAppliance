#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../common/docker-common.sh"

main() {
  require_root
  ensure_docker_ready

  local app_dir="/opt/techmarvel/apps/homepage"
  local host_ip allowed_hosts brand_logo

  host_ip="${APPLIANCE_HOST:-$(detect_primary_ip)}"
  allowed_hosts="${HOMEPAGE_ALLOWED_HOSTS:-127.0.0.1,localhost,${host_ip}:3005}"
  brand_logo="${BRAND_LOGO_URL:-https://www.tech-marvel.com/files/2025/10/2025-10-03-TechMarvel-Logo.png}"

  ensure_dir "${app_dir}/config"

  copy_file "${SCRIPT_DIR}/config/custom.css" "${app_dir}/config/custom.css" 0644
  copy_file "${SCRIPT_DIR}/config/docker.yaml" "${app_dir}/config/docker.yaml" 0644
  copy_file "${SCRIPT_DIR}/config/widgets.yaml" "${app_dir}/config/widgets.yaml" 0644

  render_template \
    "${SCRIPT_DIR}/config/services.template.yaml" \
    "${app_dir}/config/services.yaml" \
    "__APPLIANCE_HOST__=${host_ip}" \
    "__BRAND_LOGO_URL__=${brand_logo}"

  render_template \
    "${SCRIPT_DIR}/config/settings.template.yaml" \
    "${app_dir}/config/settings.yaml" \
    "__BRAND_LOGO_URL__=${brand_logo}"

  render_template \
    "${SCRIPT_DIR}/compose.yaml" \
    "${app_dir}/compose.yaml" \
    "__HOMEPAGE_ALLOWED_HOSTS__=${allowed_hosts}"

  compose_up "${app_dir}"
  log "Homepage deployed in ${app_dir}."
}

main "$@"

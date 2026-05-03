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

ensure_dir() {
  local path="$1"
  local mode="${2:-}"
  mkdir -p "${path}"
  if [[ -n "${mode}" ]]; then
    chmod "${mode}" "${path}"
  fi
}

copy_file() {
  local source="$1"
  local destination="$2"
  local mode="${3:-}"
  install -D -m "${mode:-0644}" "${source}" "${destination}"
}

copy_if_missing() {
  local source="$1"
  local destination="$2"
  local mode="${3:-0644}"
  if [[ ! -f "${destination}" ]]; then
    install -D -m "${mode}" "${source}" "${destination}"
  fi
}

detect_primary_ip() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  if [[ -z "${ip}" ]]; then
    fail "Unable to detect a primary IP address. Set APPLIANCE_HOST explicitly."
  fi
  printf '%s\n' "${ip}"
}

docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi

  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi

  fail "Docker Compose is not available."
}

ensure_docker_ready() {
  command -v docker >/dev/null 2>&1 || fail "Docker is not installed. Run syncro/docker/install-docker.sh first."
  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker
  docker info >/dev/null 2>&1 || fail "Docker daemon is not responding."
  docker_compose version >/dev/null 2>&1 || fail "Docker Compose plugin is not available."
}

compose_up() {
  local app_dir="$1"
  local compose_file="${2:-compose.yaml}"

  (
    cd "${app_dir}"
    docker_compose -f "${compose_file}" pull
    docker_compose -f "${compose_file}" up -d
  )
}

compose_down() {
  local app_dir="$1"
  local compose_file="${2:-compose.yaml}"

  (
    cd "${app_dir}"
    docker_compose -f "${compose_file}" down --remove-orphans
  )
}

escape_sed_replacement() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

render_template() {
  local source="$1"
  local destination="$2"
  shift 2

  local content
  content="$(cat "${source}")"

  local pair token value escaped
  for pair in "$@"; do
    token="${pair%%=*}"
    value="${pair#*=}"
    escaped="$(escape_sed_replacement "${value}")"
    content="$(printf '%s' "${content}" | sed "s|${token}|${escaped}|g")"
  done

  printf '%s' "${content}" > "${destination}"
}

maybe_purge_dir() {
  local path="$1"
  if [[ "${PURGE_DATA:-false}" == "true" ]]; then
    rm -rf "${path}"
  fi
}

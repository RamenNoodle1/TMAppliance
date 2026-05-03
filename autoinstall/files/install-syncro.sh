#!/usr/bin/env bash
set -euo pipefail

source /opt/techmarvel/bin/common.sh

detect_arch() {
  case "$(uname -m)" in
    x86_64)
      echo "x64"
      ;;
    aarch64 | arm64)
      echo "arm64"
      ;;
    *)
      fail "Unsupported architecture: $(uname -m)"
      ;;
  esac
}

download_installer() {
  local url="$1"
  local workdir="$2"

  if command -v curl >/dev/null 2>&1; then
    (
      cd "${workdir}"
      retry 3 10 curl -fsSLOJ -L "${url}"
    )
  elif command -v wget >/dev/null 2>&1; then
    (
      cd "${workdir}"
      retry 3 10 wget --content-disposition "${url}"
    )
  else
    fail "Neither curl nor wget is available."
  fi
}

main() {
  require_root
  load_env

  local detected_arch
  detected_arch="$(detect_arch)"

  if [[ -n "${SYNCRO_EXPECTED_ARCH:-}" ]] && [[ "${SYNCRO_EXPECTED_ARCH}" != "${detected_arch}" ]]; then
    fail "Configured architecture ${SYNCRO_EXPECTED_ARCH} does not match detected architecture ${detected_arch}."
  fi

  if [[ -z "${SYNCRO_INSTALLER_URL:-}" ]]; then
    fail "SYNCRO_INSTALLER_URL is not set."
  fi

  local temp_dir
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT

  log "Downloading Syncro Linux installer for ${detected_arch}..."
  download_installer "${SYNCRO_INSTALLER_URL}" "${temp_dir}"

  local installer_path
  installer_path="$(find "${temp_dir}" -maxdepth 1 -type f -name 'SyncroInstallerLinux-*.run' | head -n 1)"

  if [[ -z "${installer_path}" ]]; then
    fail "Syncro installer download completed, but no installer file was found."
  fi

  if [[ -n "${SYNCRO_INSTALLER_SHA256:-}" ]]; then
    log "Verifying Syncro installer checksum..."
    printf '%s  %s\n' "${SYNCRO_INSTALLER_SHA256}" "${installer_path}" | sha256sum -c -
  fi

  chmod 0755 "${installer_path}"

  log "Running Syncro installer $(basename "${installer_path}")..."
  "${installer_path}"

  if command -v syncro >/dev/null 2>&1; then
    log "Syncro CLI detected after installation."
  else
    log "Syncro installer completed. Validate the service and asset check-in from Syncro."
  fi
}

main "$@"

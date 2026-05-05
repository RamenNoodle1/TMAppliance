#!/usr/bin/env bash
# =============================================================================
# SYNCRO SCRIPT LIBRARY — store this script in Syncro, not in GitHub.
# All secrets are passed as Syncro script variables (set in the Syncro UI).
#
# Required Syncro script variables:
#   VERSION          Release tag to deploy, e.g. "v1.0.0"
#   GITHUB_TOKEN     PAT with repo read scope for the private GitHub repo
#   TAILSCALE_AUTH_KEY  Reusable Tailscale auth key
#
# Optional Syncro script variables:
#   DEVICE_ROLE      Build role to apply (default: standard)
#   EXPECTED_SHA256  If set, the downloaded zip is verified before execution
#   GITHUB_REPO      Override repo path (default: TechMarvel/Appliance)
# =============================================================================
set -euo pipefail

GITHUB_REPO="${GITHUB_REPO:-RamenNoodle1/TMAppliance}"
DEVICE_ROLE="${DEVICE_ROLE:-standard}"
WORK_DIR="/tmp/tm-bootstrap-$$"

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
fail() { log "ERROR: $*" >&2; exit 1; }

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

# --- Validate required variables ---
[[ -z "${VERSION:-}"           ]] && fail "VERSION is not set. Set it as a Syncro script variable."
[[ -z "${GITHUB_TOKEN:-}"      ]] && fail "GITHUB_TOKEN is not set. Set it as a Syncro script variable."
[[ -z "${TAILSCALE_AUTH_KEY:-}" ]] && fail "TAILSCALE_AUTH_KEY is not set. Set it as a Syncro script variable."

log "Starting Tech Marvel appliance bootstrap."
log "  Repo:    ${GITHUB_REPO}"
log "  Version: ${VERSION}"
log "  Role:    ${DEVICE_ROLE}"

mkdir -p "${WORK_DIR}"
ZIP_PATH="${WORK_DIR}/appliance.zip"

# --- Download versioned release zip ---
log "Downloading release ${VERSION}..."
curl -fsSL \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${GITHUB_REPO}/zipball/refs/tags/${VERSION}" \
  -o "${ZIP_PATH}" \
  || fail "Download failed. Check VERSION, GITHUB_TOKEN, and repo name."

# --- Verify SHA256 if provided ---
if [[ -n "${EXPECTED_SHA256:-}" ]]; then
  log "Verifying SHA256..."
  echo "${EXPECTED_SHA256}  ${ZIP_PATH}" | sha256sum -c - \
    || fail "SHA256 mismatch — aborting. Update EXPECTED_SHA256 in Syncro to match ${VERSION}."
  log "SHA256 verified."
else
  log "EXPECTED_SHA256 not set — skipping checksum verification."
fi

# --- Extract ---
log "Extracting..."
unzip -q "${ZIP_PATH}" -d "${WORK_DIR}/extracted"

EXTRACTED_DIR=$(ls "${WORK_DIR}/extracted/" | head -1)
SYNCRO_DIR="${WORK_DIR}/extracted/${EXTRACTED_DIR}/syncro"

[[ -d "${SYNCRO_DIR}" ]] || fail "Expected syncro/ directory not found in release zip."
[[ -f "${SYNCRO_DIR}/install-all.sh" ]] || fail "install-all.sh not found in syncro/."

# --- Copy to permanent location so temp dir cleanup doesn't break systemd-run ---
INSTALL_DIR="/opt/techmarvel/setup"
log "Installing scripts to ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
cp -r "${SYNCRO_DIR}" "${INSTALL_DIR}"
find "${INSTALL_DIR}" -name "*.sh" -exec chmod +x {} \;

# --- Clear any previous run of the transient unit ---
systemctl stop techmarvel-install 2>/dev/null || true
systemctl reset-failed techmarvel-install 2>/dev/null || true

# --- Hand off to systemd so install survives Syncro script exit ---
INSTALL_LOG="/var/log/techmarvel-install.log"
log "Handing off install-all.sh to systemd (role: ${DEVICE_ROLE}). Follow progress: tail -f ${INSTALL_LOG}"

systemd-run \
  --unit=techmarvel-install \
  --description="Tech Marvel service installation" \
  --property=StandardOutput=append:${INSTALL_LOG} \
  --property=StandardError=append:${INSTALL_LOG} \
  --setenv=TAILSCALE_AUTH_KEY="${TAILSCALE_AUTH_KEY}" \
  --setenv=DEVICE_ROLE="${DEVICE_ROLE}" \
  "${INSTALL_DIR}/install-all.sh"

log "Handed off to systemd. Syncro script exiting. Installation continues independently."

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SourceIso,                                      # Path to original Ubuntu Server ISO
    [string]$OutputIso = 'C:\HyperV\ubuntu-autoinstall.iso' # Output path (outside OneDrive)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Verify inputs ---
if (-not (Test-Path -LiteralPath $SourceIso)) {
    Write-Error "Source ISO not found: $SourceIso"
    exit 1
}

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Error "WSL is not available."
    exit 1
}

# --- Ensure xorriso is installed in WSL ---
Write-Host "Checking for xorriso in WSL..."
wsl -- which xorriso 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Installing xorriso..."
    wsl -- sudo apt-get install -y xorriso | Out-Null
}

# --- Convert Windows paths to WSL paths ---
function ConvertTo-WslPath([string]$winPath) {
    return (wsl -- wslpath ($winPath.Replace('\', '/'))) .Trim()
}

$wslSource = ConvertTo-WslPath $SourceIso
$wslOutput = ConvertTo-WslPath $OutputIso

# Ensure output directory exists
$outputDir = Split-Path -Parent $OutputIso
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$wslTemp = '/tmp/tm-iso-patch'

Write-Host "Extracting boot configs from ISO..."

# Extract grub.cfg (UEFI / Hyper-V Gen 2)
wsl -- bash -c "
  rm -rf $wslTemp && mkdir -p $wslTemp
  xorriso -indev '$wslSource' -osirrox on -extract /boot/grub/grub.cfg $wslTemp/grub.cfg 2>/dev/null
"

# Extract isolinux txt.cfg (BIOS / Hyper-V Gen 1) — may not exist on newer ISOs
wsl -- bash -c "
  xorriso -indev '$wslSource' -osirrox on -extract /isolinux/txt.cfg $wslTemp/txt.cfg 2>/dev/null || true
"

# --- Patch grub.cfg: add 'autoinstall ds=nocloud' to all kernel lines ---
Write-Host "Patching GRUB config..."
wsl -- bash -c "
  sed 's|/casper/vmlinuz|/casper/vmlinuz autoinstall ds=nocloud|g' \
    $wslTemp/grub.cfg > $wslTemp/grub-patched.cfg
  echo '--- Patched grub.cfg entries ---'
  grep 'linux' $wslTemp/grub-patched.cfg
"

# --- Patch isolinux txt.cfg if it was extracted ---
wsl -- bash -c "
  if [ -f $wslTemp/txt.cfg ]; then
    sed 's|/casper/vmlinuz|/casper/vmlinuz autoinstall ds=nocloud|g' \
      $wslTemp/txt.cfg > $wslTemp/txt-patched.cfg
    echo '--- Patched isolinux entries ---'
    grep 'kernel\|append' $wslTemp/txt-patched.cfg
  fi
"

# --- Build patched ISO ---
Write-Host "Building patched ISO (this may take a minute)..."
wsl -- bash -c "
  # Start with indev/outdev — preserves all boot sectors exactly
  XORRISO_CMD='xorriso -indev $wslSource -outdev $wslOutput'
  XORRISO_CMD+=' -update $wslTemp/grub-patched.cfg /boot/grub/grub.cfg'

  if [ -f $wslTemp/txt-patched.cfg ]; then
    XORRISO_CMD+=' -update $wslTemp/txt-patched.cfg /isolinux/txt.cfg'
  fi

  XORRISO_CMD+=' -boot_image any replay'
  eval \$XORRISO_CMD
"

if ($LASTEXITCODE -ne 0) {
    Write-Error "xorriso failed. Check the output above for details."
    exit 1
}

# --- Cleanup ---
wsl -- rm -rf $wslTemp

Write-Host ""
Write-Host "Autoinstall ISO written to $OutputIso"
Write-Host ""
Write-Host "In Hyper-V:"
Write-Host "  1. VM Settings -> DVD Drive -> point to: $OutputIso"
Write-Host "  2. Attach cidata.vhd as a SCSI hard disk"
Write-Host "  3. Boot — fully unattended, no GRUB editing needed"

[CmdletBinding()]
param(
    [string]$UserDataPath = (Join-Path $PSScriptRoot 'dist\user-data.yaml'),
    [string]$OutputPath   = 'C:\temp\cidata\cidata.vhd'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Verify inputs ---
if (-not (Test-Path -LiteralPath $UserDataPath)) {
    Write-Error "user-data.yaml not found at $UserDataPath. Run render-user-data.ps1 first."
    exit 1
}

if (-not (Get-Command New-VHD -ErrorAction SilentlyContinue)) {
    Write-Error "Hyper-V PowerShell module not available. Run: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell"
    exit 1
}

# --- Ensure output directory exists ---
$outputDir = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# --- Dismount and remove stale VHD if present ---
if (Test-Path -LiteralPath $OutputPath) {
    Write-Host "Removing previous VHD..."
    Dismount-VHD -Path $OutputPath -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $OutputPath -Force
}

Write-Host "Creating CIDATA VHD..."
New-VHD -Path $OutputPath -SizeBytes 64MB -Fixed | Out-Null

$mounted = $null
try {
    $mounted = Mount-VHD -Path $OutputPath -PassThru
    $diskNumber = $mounted.DiskNumber

    Write-Host "Initializing disk $diskNumber..."
    Initialize-Disk -Number $diskNumber -PartitionStyle MBR -PassThru | Out-Null

    $partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -AssignDriveLetter
    Start-Sleep -Milliseconds 500

    Write-Host "Formatting FAT32..."
    Format-Volume -Partition $partition -FileSystem FAT32 -NewFileSystemLabel 'CIDATA' -Confirm:$false | Out-Null

    $driveLetter = (Get-Partition -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber).DriveLetter
    if (-not $driveLetter) {
        throw "Drive letter was not assigned. Try running as Administrator."
    }

    Write-Host "Copying cloud-init files to ${driveLetter}:..."
    Copy-Item -LiteralPath $UserDataPath -Destination "${driveLetter}:\user-data" -Force
    Set-Content -Path "${driveLetter}:\meta-data" -Value '' -NoNewline

    Write-Host ""
    Write-Host "CIDATA VHD written to $OutputPath"
    Write-Host ""
    Write-Host "In Hyper-V:"
    Write-Host "  1. VM Settings -> SCSI Controller -> Hard Drive -> Add"
    Write-Host "  2. Set Virtual hard disk to: $OutputPath"
    Write-Host "  3. Boot from the Ubuntu Server ISO"
}
finally {
    if ($mounted) {
        Dismount-VHD -Path $OutputPath -ErrorAction SilentlyContinue
    }
}

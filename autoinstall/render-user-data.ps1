[CmdletBinding()]
param(
    [string]$VarsPath = (Join-Path $PSScriptRoot 'config\appliance.vars.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'dist\user-data.yaml')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [object]$Config,

        [Parameter(Mandatory)]
        [string]$Name,

        [switch]$Required,

        [object]$Default = $null
    )

    $property = $Config.PSObject.Properties[$Name]

    if ($null -eq $property) {
        if ($Required) {
            throw "Missing required property '$Name' in $VarsPath."
        }

        return $Default
    }

    $value = $property.Value

    if ($Required -and [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Property '$Name' in $VarsPath cannot be empty."
    }

    return $value
}

function Convert-ToIndentedBlock {
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [Parameter(Mandatory)]
        [int]$Indent
    )

    $padding = ' ' * $Indent
    $lines = $Text -split "`r?`n"
    $nonEmptyLines = $lines | Where-Object { $_ -match '\S' }
    $minimumIndent = 0

    if ($nonEmptyLines.Count -gt 0) {
        $minimumIndent = ($nonEmptyLines | ForEach-Object {
            ([regex]::Match($_, '^[ ]*')).Value.Length
        } | Measure-Object -Minimum).Minimum
    }

    return ($lines | ForEach-Object {
        if ($_ -match '\S') {
            $padding + $_.Substring($minimumIndent)
        }
        else {
            $padding
        }
    }) -join "`n"
}

function Convert-ToShellSingleQuoted {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        $Value = ''
    }

    return "'" + ($Value -replace "'", "'`"`'`"`'") + "'"
}

function Convert-ToBase64Utf8 {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Text))
}

function New-WriteFileEntry {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Permissions,

        [string]$SourcePath,

        [string]$Content
    )

    if ($SourcePath) {
        $Content = Get-Content -Raw -LiteralPath $SourcePath
    }

    if ($null -eq $Content) {
        throw "No content was provided for write_files entry '$Path'."
    }

    $encoded = Convert-ToBase64Utf8 -Text $Content

    @"
      - path: $Path
        permissions: "$Permissions"
        encoding: b64
        content: $encoded
"@
}

function New-EnvFileContent {
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    $lines = @(
        "SYNCRO_INSTALLER_URL=$(Convert-ToShellSingleQuoted -Value ([string](Get-ConfigValue -Config $Config -Name 'syncroInstallerUrl' -Required)))"
        "SYNCRO_INSTALLER_SHA256=$(Convert-ToShellSingleQuoted -Value ([string](Get-ConfigValue -Config $Config -Name 'syncroInstallerSha256' -Default '')))"
        "SYNCRO_EXPECTED_ARCH=$(Convert-ToShellSingleQuoted -Value ([string](Get-ConfigValue -Config $Config -Name 'syncroExpectedArch' -Default '')))"
        "APPLY_APT_UPGRADES=$(([bool](Get-ConfigValue -Config $Config -Name 'applyAptUpgrades' -Default $true)).ToString().ToLowerInvariant())"
        "NETWORK_WAIT_TIMEOUT_SECONDS=$([int](Get-ConfigValue -Config $Config -Name 'networkWaitTimeoutSeconds' -Default 300))"
        "BOOTSTRAP_PING_TARGET=$(Convert-ToShellSingleQuoted -Value ([string](Get-ConfigValue -Config $Config -Name 'bootstrapPingTarget' -Default '8.8.8.8')))"
        "SYNCRO_TOKEN=$(Convert-ToShellSingleQuoted -Value ([string](Get-ConfigValue -Config $Config -Name 'syncroToken' -Required)))"
    )

    return ($lines -join "`n") + "`n"
}

$templatePath = Join-Path $PSScriptRoot 'templates\user-data.tpl.yaml'
$filesRoot = Join-Path $PSScriptRoot 'files'

if (-not (Test-Path -LiteralPath $VarsPath)) {
    throw "Configuration file not found: $VarsPath"
}

$config = Get-Content -Raw -LiteralPath $VarsPath | ConvertFrom-Json
$template = Get-Content -Raw -LiteralPath $templatePath

$sshKeys = @(Get-ConfigValue -Config $config -Name 'sshAuthorizedKeys' -Required)
if ($sshKeys.Count -eq 0) {
    throw "At least one SSH authorized key is required."
}

$sshKeyBlock = ($sshKeys | ForEach-Object { '      - "' + [string]$_ + '"' }) -join "`n"

$networkYaml = [string](Get-ConfigValue -Config $config -Name 'networkYaml' -Required)
$networkBlock = Convert-ToIndentedBlock -Text $networkYaml -Indent 4

$writeFiles = @(
    (New-WriteFileEntry -Path '/etc/techmarvel/appliance.env' -Permissions '0600' -Content (New-EnvFileContent -Config $config)),
    (New-WriteFileEntry -Path '/opt/techmarvel/bin/common.sh' -Permissions '0755' -SourcePath (Join-Path $filesRoot 'common.sh')),
    (New-WriteFileEntry -Path '/opt/techmarvel/bin/install-syncro.sh' -Permissions '0755' -SourcePath (Join-Path $filesRoot 'install-syncro.sh')),
    (New-WriteFileEntry -Path '/opt/techmarvel/bin/bootstrap.sh' -Permissions '0755' -SourcePath (Join-Path $filesRoot 'bootstrap.sh')),
    (New-WriteFileEntry -Path '/etc/systemd/system/techmarvel-bootstrap.service' -Permissions '0644' -SourcePath (Join-Path $filesRoot 'techmarvel-bootstrap.service'))
)

$replacements = @{
    '__HOSTNAME__' = [string](Get-ConfigValue -Config $config -Name 'hostname' -Required)
    '__USERNAME__' = [string](Get-ConfigValue -Config $config -Name 'username' -Required)
    '__PASSWORD_HASH__' = [string](Get-ConfigValue -Config $config -Name 'passwordHash' -Required)
    '__TIMEZONE__' = [string](Get-ConfigValue -Config $config -Name 'timezone' -Required)
    '__LOCALE__' = [string](Get-ConfigValue -Config $config -Name 'locale' -Required)
    '__SSH_ALLOW_PASSWORD__' = ([bool](Get-ConfigValue -Config $config -Name 'sshAllowPassword' -Default $false)).ToString().ToLowerInvariant()
    '__SSH_AUTHORIZED_KEYS__' = $sshKeyBlock
    '__NETWORK_CONFIG__' = $networkBlock
    '__WRITE_FILES__' = ($writeFiles -join "`n")
}

foreach ($key in $replacements.Keys) {
    $template = $template.Replace($key, $replacements[$key])
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

Set-Content -LiteralPath $OutputPath -Value $template -NoNewline
Write-Host "Rendered autoinstall file to $OutputPath"

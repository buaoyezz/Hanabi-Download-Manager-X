[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PluginDir,

    [string]$OutputPath,

    [string]$BaseDownloadUrl
)

$ErrorActionPreference = 'Stop'

function Require-Value {
    param(
        [string]$Name,
        [object]$Value
    )

    if ($null -eq $Value) {
        throw "plugin.json missing required field: $Name"
    }

    $text = $Value.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "plugin.json missing required field: $Name"
    }

    return $text
}

$resolvedPluginDir = (Resolve-Path -LiteralPath $PluginDir).Path
$pluginJsonPath = Join-Path $resolvedPluginDir 'plugin.json'
if (-not (Test-Path -LiteralPath $pluginJsonPath)) {
    throw "plugin.json not found: $pluginJsonPath"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$validatorPath = Join-Path $repoRoot 'tool\validate_plugin.dart'
$dartCommand = Get-Command dart -ErrorAction SilentlyContinue
if ($null -ne $dartCommand -and (Test-Path -LiteralPath $validatorPath)) {
    Push-Location $repoRoot
    try {
        & $dartCommand.Source run 'tool\validate_plugin.dart' $resolvedPluginDir
        if ($LASTEXITCODE -ne 0) {
            throw "plugin validation failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Warning 'Dart SDK or plugin validator not found; only basic package validation will run.'
}

$manifest = Get-Content -LiteralPath $pluginJsonPath -Encoding UTF8 -Raw | ConvertFrom-Json
$pluginId = Require-Value 'id' $manifest.id
$pluginName = Require-Value 'name' $manifest.name
$pluginVersion = Require-Value 'version' $manifest.version
$pluginAuthor = Require-Value 'author' $manifest.author
$pluginEntry = Require-Value 'entry' $manifest.entry

if (-not (Test-Path -LiteralPath (Join-Path $resolvedPluginDir $pluginEntry))) {
    throw "plugin entry not found: $pluginEntry"
}

$capabilities = @($manifest.capabilities)
if ($capabilities.Count -eq 0) {
    throw 'plugin.json missing required field: capabilities'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $distDir = Join-Path (Get-Location).Path 'dist\plugins'
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
    $OutputPath = Join-Path $distDir "$pluginId-$pluginVersion.hanabi-plugin.zip"
}

$resolvedOutputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($resolvedOutputDir)) {
    New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
}

$stagingRoot = Join-Path $env:TEMP ("hanabi_plugin_pack_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
$stagingPluginDir = Join-Path $stagingRoot $pluginId

try {
    New-Item -ItemType Directory -Path $stagingPluginDir -Force | Out-Null
    Get-ChildItem -LiteralPath $resolvedPluginDir -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stagingPluginDir -Recurse -Force
    }

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    Compress-Archive -LiteralPath $stagingPluginDir -DestinationPath $OutputPath -Force

    $hash = (Get-FileHash -LiteralPath $OutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $packageFileName = Split-Path -Leaf $OutputPath
    $downloadUrl = if ([string]::IsNullOrWhiteSpace($BaseDownloadUrl)) {
        "./$packageFileName"
    } else {
        ($BaseDownloadUrl.TrimEnd('/') + '/' + $packageFileName)
    }

    $entry = [ordered]@{
        manifestVersion = if ($null -eq $manifest.manifestVersion) { 1 } else { [int]$manifest.manifestVersion }
        apiVersion = if ([string]::IsNullOrWhiteSpace($manifest.apiVersion)) { '1.0' } else { $manifest.apiVersion.ToString() }
        id = $pluginId
        name = $pluginName
        version = $pluginVersion
        description = ($manifest.description | ForEach-Object { $_.ToString() }) -join ''
        author = $pluginAuthor
        downloadUrl = $downloadUrl
        hash = "sha256:$hash"
        channel = 'stable'
        capabilities = $capabilities
        reviewStatus = 'published'
    }

    $minAppVersion = ($manifest.minAppVersion | ForEach-Object { $_.ToString() }) -join ''
    if (-not [string]::IsNullOrWhiteSpace($minAppVersion)) {
        $entry.minAppVersion = $minAppVersion
    }

    $maxAppVersion = if ($null -eq $manifest.maxAppVersion) {
        ''
    }
    else {
        $manifest.maxAppVersion.ToString()
    }
    if (-not [string]::IsNullOrWhiteSpace($maxAppVersion)) {
        $entry.maxAppVersion = $maxAppVersion
    }

    $intentSchemes = @($manifest.intentSchemes | Where-Object {
        $null -ne $_ -and -not [string]::IsNullOrWhiteSpace($_.ToString())
    })
    if ($intentSchemes.Count -gt 0) {
        $entry.intentSchemes = $intentSchemes
    }

    $permissionsProperty = $manifest.PSObject.Properties['permissions']
    $hasPermissions = $null -ne $permissionsProperty -and $null -ne $manifest.permissions
    if ($hasPermissions -and $manifest.permissions -is [System.Array]) {
        $hasPermissions = $manifest.permissions.Count -gt 0
    }
    if ($hasPermissions) {
        $entry.permissions = $manifest.permissions
    }

    Write-Host ''
    Write-Host 'Plugin package created.'
    Write-Host "  PluginDir : $resolvedPluginDir"
    Write-Host "  Output    : $OutputPath"
    Write-Host "  SHA256    : $hash"
    Write-Host ''
    Write-Host 'Store index entry:'
    $entry | ConvertTo-Json -Depth 8
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}

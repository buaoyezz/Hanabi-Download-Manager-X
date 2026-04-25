[CmdletBinding()]
param(
    [string]$PluginsDataDir = ".\.plugin-market\plugins-data",
    [string]$OutputDir = ".\dist\plugins"
)

$ErrorActionPreference = 'Stop'

$resolvedPluginsDataDir = (Resolve-Path -LiteralPath $PluginsDataDir).Path
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

$packageScriptPath = Join-Path $PSScriptRoot 'package-plugin.ps1'

$pluginDirs = Get-ChildItem -LiteralPath $resolvedPluginsDataDir -Directory |
    Sort-Object Name

if ($pluginDirs.Count -eq 0) {
    Write-Host "No synced plugin directories found in $resolvedPluginsDataDir"
    exit 0
}

foreach ($pluginDir in $pluginDirs) {
    $manifestPath = Join-Path $pluginDir.FullName 'plugin.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        throw "plugin.json not found in $($pluginDir.FullName)"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $pluginId = $manifest.id.ToString().Trim()
    $pluginVersion = $manifest.version.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($pluginId) -or [string]::IsNullOrWhiteSpace($pluginVersion)) {
        throw "Invalid plugin.json in $($pluginDir.FullName)"
    }

    $outputPath = Join-Path $resolvedOutputDir "$pluginId-$pluginVersion.hanabi-plugin.zip"
    Write-Host "Packaging $pluginId v$pluginVersion"

    & powershell -ExecutionPolicy Bypass -File $packageScriptPath `
        -PluginDir $pluginDir.FullName `
        -OutputPath $outputPath | Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to package plugin: $pluginId"
    }
}

Write-Host ''
Write-Host "Plugin packages created in: $resolvedOutputDir"

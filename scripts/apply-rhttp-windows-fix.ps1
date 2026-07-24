<#
.SYNOPSIS
Applies the local Windows fixes required by the cached rhttp package.

.DESCRIPTION
The script reads .dart_tool/package_config.json to locate the resolved rhttp
package in Pub Cache, then applies two idempotent patches:
1. Add -Force to resolve_symlinks.ps1 so hidden AppData segments can be read.
2. Add a dart fallback to run_build_tool.cmd when FLUTTER_ROOT is not set.

Run this after `flutter pub get` whenever Pub Cache was refreshed.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Content
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Resolve-PackageRootPath {
    param(
        [Parameter(Mandatory)]
        [string] $ConfigPath,

        [Parameter(Mandatory)]
        [string] $RootUri
    )

    $configDir = Split-Path -Path $ConfigPath -Parent

    if ($RootUri -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') {
        $uri = [Uri] $RootUri
        if ($uri.IsFile) {
            return [System.IO.Path]::GetFullPath($uri.LocalPath)
        }

        throw "Unsupported rhttp rootUri scheme: $RootUri"
    }

    return [System.IO.Path]::GetFullPath((Join-Path $configDir $RootUri))
}

function Update-File {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $OldText,

        [Parameter(Mandatory)]
        [string] $NewText,

        [Parameter(Mandatory)]
        [string] $AlreadyPatchedText,

        [Parameter(Mandatory)]
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing $Label file: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    if ($content.Contains($AlreadyPatchedText)) {
        Write-Host "[ok] $Label already patched"
        return $false
    }

    if (-not $content.Contains($OldText)) {
        throw "Could not find the expected text in ${Label}: $Path"
    }

    $updatedContent = $content.Replace($OldText, $NewText)
    Write-Utf8NoBom -Path $Path -Content $updatedContent
    Write-Host "[patch] $Label updated"
    return $true
}

function Update-ResolveSymlinksFile {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing resolve_symlinks.ps1 file: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $updatedContent = $content.
        Replace('Get-Item -Force $realPath -Force', 'Get-Item -Force $realPath').
        Replace('Get-Item $realPath -Force', 'Get-Item -Force $realPath').
        Replace('Get-Item $realPath', 'Get-Item -Force $realPath')

    if ($updatedContent -eq $content) {
        Write-Host "[ok] resolve_symlinks.ps1 already patched"
        return $false
    }

    Write-Utf8NoBom -Path $Path -Content $updatedContent
    Write-Host "[patch] resolve_symlinks.ps1 updated"
    return $true
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$packageConfigPath = Join-Path $repoRoot '.dart_tool\package_config.json'

if (-not (Test-Path -LiteralPath $packageConfigPath)) {
    throw "Missing .dart_tool/package_config.json. Run 'flutter pub get' first."
}

$packageConfig = Get-Content -LiteralPath $packageConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$rhttpPackage = $packageConfig.packages | Where-Object { $_.name -eq 'rhttp' } | Select-Object -First 1

if (-not $rhttpPackage) {
    throw "Could not find package 'rhttp' in .dart_tool/package_config.json."
}

$rhttpRoot = Resolve-PackageRootPath -ConfigPath $packageConfigPath -RootUri $rhttpPackage.rootUri

if (-not (Test-Path -LiteralPath $rhttpRoot)) {
    throw "Resolved rhttp package path does not exist: $rhttpRoot"
}

Write-Host "Using rhttp package at: $rhttpRoot"

$resolveSymlinksPath = Join-Path $rhttpRoot 'cargokit\cmake\resolve_symlinks.ps1'
$runBuildToolPath = Join-Path $rhttpRoot 'cargokit\run_build_tool.cmd'
$dartFallbackBlock = @(
    'if "%FLUTTER_ROOT%"=="" (',
    '    SET DART=dart',
    ') else (',
    '    SET DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart',
    ')'
) -join "`r`n"

$changedFiles = 0

if (Update-ResolveSymlinksFile -Path $resolveSymlinksPath) {
    $changedFiles++
}

if (Update-File `
    -Path $runBuildToolPath `
    -OldText 'SET DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart' `
    -NewText $dartFallbackBlock `
    -AlreadyPatchedText 'SET DART=dart' `
    -Label 'run_build_tool.cmd') {
    $changedFiles++
}

Write-Host "Done. Files changed: $changedFiles"

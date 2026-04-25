[CmdletBinding()]
param(
    [string]$PluginsListDir = ".\plugins-list",
    [string]$OutputDir = ".\.plugin-market\plugins-data"
)

$ErrorActionPreference = 'Stop'

function Require-Text {
    param(
        [string]$Name,
        [object]$Value
    )

    if ($null -eq $Value) {
        throw "Missing required field: $Name"
    }

    $text = $Value.ToString().Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Missing required field: $Name"
    }

    return $text
}

function Normalize-GitHubRepoUrl {
    param(
        [string]$RepoUrl
    )

    $trimmed = $RepoUrl.Trim().TrimEnd('/')
    if ($trimmed.EndsWith('.git')) {
        $trimmed = $trimmed.Substring(0, $trimmed.Length - 4)
    }

    $uri = [Uri]$trimmed
    if ($uri.Host -notin @('github.com', 'www.github.com')) {
        throw "Only GitHub repositories are supported right now: $RepoUrl"
    }

    $segments = $uri.AbsolutePath.Trim('/').Split('/')
    if ($segments.Length -lt 2) {
        throw "Invalid GitHub repository URL: $RepoUrl"
    }

    return "https://github.com/$($segments[0])/$($segments[1])"
}

$resolvedPluginsListDir = (Resolve-Path -LiteralPath $PluginsListDir).Path
$resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)

New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null
Get-ChildItem -LiteralPath $resolvedOutputDir -Force | Remove-Item -Recurse -Force

$sourceFiles = Get-ChildItem -LiteralPath $resolvedPluginsListDir -Filter *.json -File |
    Where-Object { $_.Name -notlike '*.example.json' } |
    Sort-Object Name

if ($sourceFiles.Count -eq 0) {
    Write-Host "No plugin source declarations found in $resolvedPluginsListDir"
    exit 0
}

$tempRoot = Join-Path $env:TEMP ("hanabi_plugin_sync_" + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    foreach ($sourceFile in $sourceFiles) {
        $source = Get-Content -LiteralPath $sourceFile.FullName -Raw | ConvertFrom-Json
        $sourceId = Require-Text 'id' $source.id
        $repo = Normalize-GitHubRepoUrl (Require-Text 'repo' $source.repo)
        $branch = if ([string]::IsNullOrWhiteSpace(($source.branch | ForEach-Object { $_.ToString() }) -join '')) {
            'main'
        } else {
            $source.branch.ToString().Trim()
        }
        $pluginPath = if ([string]::IsNullOrWhiteSpace(($source.pluginPath | ForEach-Object { $_.ToString() }) -join '')) {
            '.'
        } else {
            $source.pluginPath.ToString().Trim()
        }

        Write-Host "Syncing $sourceId from $repo [$branch] path=$pluginPath"

        $cloneDir = Join-Path $tempRoot $sourceId
        & git clone --depth 1 --branch $branch $repo $cloneDir | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clone repository: $repo"
        }

        $resolvedPluginPath = if ($pluginPath -eq '.') {
            $cloneDir
        } else {
            Join-Path $cloneDir $pluginPath
        }

        if (-not (Test-Path -LiteralPath $resolvedPluginPath)) {
            throw "Plugin path not found for $sourceId: $pluginPath"
        }

        $manifestPath = Join-Path $resolvedPluginPath 'plugin.json'
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            throw "plugin.json not found for $sourceId at path: $pluginPath"
        }

        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $manifestId = Require-Text 'plugin.json.id' $manifest.id
        if ($manifestId -ne $sourceId) {
            throw "Plugin id mismatch: source=$sourceId manifest=$manifestId"
        }

        $targetDir = Join-Path $resolvedOutputDir $sourceId
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Get-ChildItem -LiteralPath $resolvedPluginPath -Force | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $targetDir -Recurse -Force
        }

        $sourceMetadata = [ordered]@{
            id = $sourceId
            repo = $repo
            branch = $branch
            pluginPath = $pluginPath
            syncedAt = [DateTime]::UtcNow.ToString('o')
            sourceFile = $sourceFile.Name
        }
        $sourceMetadata | ConvertTo-Json -Depth 8 |
            Set-Content -LiteralPath (Join-Path $targetDir '_source.json') -Encoding UTF8
    }

    Write-Host ''
    Write-Host "Plugin sources synced to: $resolvedOutputDir"
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

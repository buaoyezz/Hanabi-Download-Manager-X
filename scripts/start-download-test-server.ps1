[CmdletBinding()]
param(
    [string]$BindAddress = '127.0.0.1',
    [ValidateRange(0, 65535)]
    [int]$Port = 18080,
    [switch]$AllowRemote,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$serverScript = Join-Path $repoRoot 'tool\download_test_server.dart'

if (-not (Test-Path -LiteralPath $serverScript)) {
    throw "Download test server not found: $serverScript"
}

$dartArgs = @(
    'run',
    $serverScript,
    '--host',
    $BindAddress,
    '--port',
    $Port.ToString()
)
if ($AllowRemote) {
    $dartArgs += '--allow-remote'
}
if ($Quiet) {
    $dartArgs += '--quiet'
}

Push-Location $repoRoot
try {
    & dart @dartArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}

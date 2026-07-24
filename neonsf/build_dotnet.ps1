$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$projectPath = Join-Path $scriptRoot 'dotnet\Hanabi.NeoNSF\Hanabi.NeoNSF.csproj'
$distPath = Join-Path $repoRoot 'build\neonsf\win-x64'
$resolvedRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'build\neonsf'))
$resolvedDist = [System.IO.Path]::GetFullPath($distPath)

if (-not $resolvedDist.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean output outside NeoNSFX: $resolvedDist"
}

if (Test-Path -LiteralPath $distPath) {
    Get-ChildItem -LiteralPath $distPath -Force | Remove-Item -Recurse -Force
}
else {
    New-Item -ItemType Directory -Path $distPath | Out-Null
}

dotnet publish $projectPath `
    -c Release `
    -r win-x64 `
    -o $distPath `
    --self-contained true `
    -p:PublishAot=true `
    -p:DebugType=None `
    -p:DebugSymbols=false

Get-ChildItem -LiteralPath $distPath -Filter *.pdb -File | Remove-Item -Force

$exe = Join-Path $distPath 'HanabiNeoNSF.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    throw 'HanabiNeoNSF.exe was not produced.'
}

$probe = & $exe --probe | ConvertFrom-Json
if (-not $probe.ready -or $probe.protocolVersion -ne 1) {
    throw 'NeoNSFX protocol probe failed.'
}

Write-Host "NeoNSFX $($probe.version) ready: $exe"

param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$rhttpFixScript = Join-Path $repoRoot 'scripts\apply-rhttp-windows-fix.ps1'

$localBypass = '127.0.0.1,localhost'
$env:NO_PROXY = $localBypass
$env:no_proxy = $localBypass

if (Test-Path -LiteralPath $rhttpFixScript) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $rhttpFixScript
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

if (-not $FlutterArgs -or $FlutterArgs.Count -eq 0) {
  $FlutterArgs = @('run', '-d', 'windows')
}

& flutter @FlutterArgs
exit $LASTEXITCODE

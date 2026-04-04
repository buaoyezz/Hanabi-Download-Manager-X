param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

$localBypass = '127.0.0.1,localhost'
$env:NO_PROXY = $localBypass
$env:no_proxy = $localBypass

if (-not $FlutterArgs -or $FlutterArgs.Count -eq 0) {
  $FlutterArgs = @('run', '-d', 'windows')
}

& flutter @FlutterArgs
exit $LASTEXITCODE

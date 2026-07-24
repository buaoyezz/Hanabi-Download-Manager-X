param(
    [string]$BundleDirectory = 'updater\dist',
    [int]$TimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'

$bundle = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $BundleDirectory))
$requiredFiles = @(
    'HanabiUpdater.exe',
    'av_libglesv2.dll',
    'libHarfBuzzSharp.dll',
    'libSkiaSharp.dll'
)

foreach ($fileName in $requiredFiles) {
    $filePath = Join-Path $bundle $fileName
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
        throw "Updater bundle is incomplete: $fileName is missing from $bundle"
    }
}

$updaterPath = Join-Path $bundle 'HanabiUpdater.exe'
$readyFile = Join-Path $bundle ('.launch-probe-{0}.ready' -f [Guid]::NewGuid())
$process = $null

try {
    # Match Dart Process.start(runInShell: false), which uses CreateProcess.
    # Start-Process defaults to ShellExecute for GUI executables and can return
    # ERROR_CANCELLED when Windows reputation UI intercepts a fresh build.
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $updaterPath
    $startInfo.Arguments = '--launch-probe --ready-file "{0}"' -f $readyFile.Replace('"', '\"')
    $startInfo.WorkingDirectory = $bundle
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) {
        throw 'Updater launch probe could not create the updater process.'
    }

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        try { $process.Kill() } catch { }
        throw "Updater launch probe timed out after $TimeoutSeconds seconds."
    }
    if ($process.ExitCode -ne 0) {
        throw "Updater launch probe exited with code $($process.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $readyFile -PathType Leaf)) {
        throw 'Updater exited without writing its ready handshake.'
    }

    $handshake = Get-Content -LiteralPath $readyFile -Raw
    if ($handshake -notmatch '^pid=\d+;ready=') {
        throw "Updater wrote an invalid ready handshake: $handshake"
    }

    Write-Host "[OK] Updater launch probe passed: $updaterPath"
}
finally {
    if ($process -and -not $process.HasExited) {
        try { $process.Kill() } catch { }
    }
    if (Test-Path -LiteralPath $readyFile) {
        Remove-Item -LiteralPath $readyFile -Force
    }
}

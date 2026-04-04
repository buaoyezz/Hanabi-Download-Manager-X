param(
  [Parameter(Mandatory = $true)]
  [string]$ExecutablePath
)

$resolvedTarget = [System.IO.Path]::GetFullPath($ExecutablePath)
$processName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedTarget)

$matchingProcesses = Get-Process -Name $processName -ErrorAction SilentlyContinue |
  Where-Object {
    try {
      $_.Path -and [string]::Equals(
        [System.IO.Path]::GetFullPath($_.Path),
        $resolvedTarget,
        [System.StringComparison]::OrdinalIgnoreCase
      )
    } catch {
      $false
    }
  }

if (-not $matchingProcesses) {
  exit 0
}

foreach ($process in $matchingProcesses) {
  try {
    if ($process.MainWindowHandle -ne 0) {
      [void]$process.CloseMainWindow()
    }
  } catch {
  }
}

$remainingIds = $matchingProcesses.Id | Select-Object -Unique
$deadline = (Get-Date).AddSeconds(5)

do {
  Start-Sleep -Milliseconds 250
  $stillRunning = Get-Process -Id $remainingIds -ErrorAction SilentlyContinue
} while ($stillRunning -and (Get-Date) -lt $deadline)

if ($stillRunning) {
  try {
    $stillRunning | Stop-Process -Force -ErrorAction Stop
  } catch {
    Write-Error "Failed to stop stale bundle instance for $resolvedTarget. $($_.Exception.Message)"
    exit 1
  }
}

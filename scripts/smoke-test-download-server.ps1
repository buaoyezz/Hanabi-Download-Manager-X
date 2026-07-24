[CmdletBinding()]
param(
    [string]$BaseUrl = 'http://127.0.0.1:18080/'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http
$baseUri = [Uri]::new($BaseUrl)
$client = [System.Net.Http.HttpClient]::new()

try {
    $healthUri = [Uri]::new($baseUri, 'health')
    $healthJson = $client.GetStringAsync($healthUri).GetAwaiter().GetResult()
    $health = $healthJson | ConvertFrom-Json
    if (-not $health.ok) {
        throw 'Health API did not return ok=true.'
    }

    $rangeUri = [Uri]::new($baseUri, 'download/normal/1m.bin')
    $request = [System.Net.Http.HttpRequestMessage]::new(
        [System.Net.Http.HttpMethod]::Get,
        $rangeUri
    )
    $request.Headers.Range = [System.Net.Http.Headers.RangeHeaderValue]::new(1024, 4095)
    $response = $client.SendAsync($request).GetAwaiter().GetResult()
    try {
        if ([int]$response.StatusCode -ne 206) {
            throw "Expected HTTP 206, got $([int]$response.StatusCode)."
        }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        if ($bytes.Length -ne 3072) {
            throw "Expected 3072 range bytes, got $($bytes.Length)."
        }
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            $offset = 1024 + $index
            $expected = (($offset * 31) + (($offset -shr 8) * 17) + (7 * 13) + 29) -band 0xff
            if ($bytes[$index] -ne $expected) {
                throw "Pattern mismatch at absolute offset $offset."
            }
        }
    }
    finally {
        $response.Dispose()
        $request.Dispose()
    }

    $statsUri = [Uri]::new($baseUri, 'api/v1/stats')
    $statsJson = $client.GetStringAsync($statsUri).GetAwaiter().GetResult()
    $stats = $statsJson | ConvertFrom-Json
    if ($stats.rangeRequests -lt 1) {
        throw 'Statistics API did not record the range request.'
    }

    Write-Host 'Download test server smoke test passed.' -ForegroundColor Green
    Write-Host "Base URL: $BaseUrl"
    Write-Host "Requests: $($stats.totalRequests), range requests: $($stats.rangeRequests)"
}
finally {
    $client.Dispose()
}

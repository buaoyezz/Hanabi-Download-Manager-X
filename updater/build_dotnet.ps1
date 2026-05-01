$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectPath = Join-Path $scriptRoot 'dotnet\Hanabi.Updater.App\Hanabi.Updater.App.csproj'
$distPath = Join-Path $scriptRoot 'dist'
$standalonePath = Join-Path $scriptRoot 'standalone'
$resolvedScriptRoot = [System.IO.Path]::GetFullPath($scriptRoot)

function Reset-OutputDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedScriptRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean output outside updater directory: $resolvedPath"
    }

    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Force | Remove-Item -Recurse -Force
    }
    else {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

Reset-OutputDirectory -Path $distPath
Reset-OutputDirectory -Path $standalonePath

# Bundle build for the in-app updater. Avalonia still needs native Skia DLLs,
# so the app release copies this whole directory.
dotnet publish $projectPath `
    -c Release `
    -r win-x64 `
    -o $distPath `
    --self-contained true `
    -p:PublishAot=true `
    -p:DebugType=None `
    -p:DebugSymbols=false

Get-ChildItem -LiteralPath $distPath -Filter *.pdb -File | Remove-Item -Force

if (-not (Test-Path -LiteralPath (Join-Path $distPath 'HanabiUpdater.exe'))) {
    throw 'HanabiUpdater.exe was not produced.'
}

# Single-file self-extracting build for standalone installer distribution.
# It embeds Avalonia/Skia native DLLs into the EXE and extracts them at runtime.
dotnet publish $projectPath `
    -c Release `
    -r win-x64 `
    -o $standalonePath `
    --self-contained true `
    -p:PublishAot=false `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false

Get-ChildItem -LiteralPath $standalonePath -Filter *.pdb -File | Remove-Item -Force

$standaloneExe = Join-Path $standalonePath 'HanabiUpdater.exe'
if (-not (Test-Path -LiteralPath $standaloneExe)) {
    throw 'Standalone HanabiUpdater.exe was not produced.'
}

$installerExe = Join-Path $standalonePath 'HanabiDownloadManagerX_Setup.exe'
Move-Item -LiteralPath $standaloneExe -Destination $installerExe -Force

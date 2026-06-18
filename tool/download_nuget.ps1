param(
    [Parameter(Mandatory = $true)]
    [string]$OutDir
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}
$outFile = Join-Path $OutDir 'nuget.exe'
Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe' -OutFile $outFile -UseBasicParsing

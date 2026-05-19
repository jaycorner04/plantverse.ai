param(
  [Parameter(Mandatory = $true)]
  [string]$BackendBaseUrl
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  $flutter = '.\flutter\bin\flutter.bat'
  if (-not (Test-Path -LiteralPath $flutter)) {
    $flutter = 'flutter'
  }

  & $flutter build apk --release --no-pub "--dart-define=BACKEND_BASE_URL=$BackendBaseUrl"

  New-Item -ItemType Directory -Force -Path 'mobile-apk' | Out-Null
  Copy-Item -LiteralPath 'build\app\outputs\flutter-apk\app-release.apk' `
    -Destination 'mobile-apk\PlantVerse-AI-backend-release.apk' -Force

  Write-Host "Built mobile-apk\PlantVerse-AI-backend-release.apk"
} finally {
  Pop-Location
}

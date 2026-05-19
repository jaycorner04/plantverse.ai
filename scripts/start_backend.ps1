Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend'

Push-Location $backend
try {
  npm start
} finally {
  Pop-Location
}

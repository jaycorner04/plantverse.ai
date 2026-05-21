param(
  [string]$BackendUrl = $env:PLANTVERSE_BACKEND_URL,
  [string]$ManifestPath = "test/scan_accuracy/manifest.json",
  [switch]$Strict
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BackendUrl)) {
  $BackendUrl = "https://dj2i5my9uyve1.cloudfront.net"
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$manifestFullPath = Join-Path $root $ManifestPath

if (!(Test-Path -LiteralPath $manifestFullPath)) {
  throw "Manifest not found: $manifestFullPath"
}

function Normalize-PlantText([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
  return ($Text.ToLowerInvariant() -replace "[^a-z0-9]+", " ").Trim()
}

function Read-PlantNames($Result) {
  $names = New-Object System.Collections.Generic.List[string]
  foreach ($key in @("common_name", "scientific_name", "original_common_name", "original_scientific_name")) {
    if ($Result.PSObject.Properties.Name -contains $key) {
      $value = Normalize-PlantText ([string]$Result.$key)
      if ($value) { $names.Add($value) }
    }
  }

  if ($Result.PSObject.Properties.Name -contains "candidate_matches" -and $Result.candidate_matches) {
    foreach ($candidate in $Result.candidate_matches) {
      foreach ($key in @("common_name", "scientific_name")) {
        if ($candidate.PSObject.Properties.Name -contains $key) {
          $value = Normalize-PlantText ([string]$candidate.$key)
          if ($value) { $names.Add($value) }
        }
      }
    }
  }
  return $names
}

$cases = Get-Content -LiteralPath $manifestFullPath -Raw | ConvertFrom-Json
$tested = 0
$skipped = 0
$failures = 0
$results = @()

foreach ($case in $cases) {
  $imagePath = Join-Path $root ([string]$case.image)
  if (!(Test-Path -LiteralPath $imagePath)) {
    $skipped += 1
    $message = "SKIP $($case.id): missing image $($case.image)"
    if ($Strict) {
      Write-Host "FAIL $message" -ForegroundColor Red
      $failures += 1
    } else {
      Write-Host $message -ForegroundColor Yellow
    }
    continue
  }

  $tested += 1
  $bytes = [IO.File]::ReadAllBytes($imagePath)
  $body = @{
    fileName = [IO.Path]::GetFileName($imagePath)
    imageBase64 = [Convert]::ToBase64String($bytes)
  } | ConvertTo-Json -Compress

  try {
    $response = Invoke-WebRequest `
      -Uri "$($BackendUrl.TrimEnd('/'))/api/identify-plant" `
      -Method Post `
      -ContentType "application/json" `
      -Body $body `
      -UseBasicParsing `
      -TimeoutSec 120
    $result = $response.Content | ConvertFrom-Json
  } catch {
    Write-Host "FAIL $($case.id): request failed $($_.Exception.Message)" -ForegroundColor Red
    $failures += 1
    continue
  }

  $names = Read-PlantNames $result
  $expected = @($case.expected_any | ForEach-Object { Normalize-PlantText ([string]$_) })
  $matched = $false
  foreach ($needle in $expected) {
    foreach ($name in $names) {
      if ($name.Contains($needle) -or $needle.Contains($name)) {
        $matched = $true
        break
      }
    }
    if ($matched) { break }
  }

  $confidence = 0.0
  if ($result.PSObject.Properties.Name -contains "confidence") {
    $confidence = [double]$result.confidence
  }
  $minConfidence = if ($case.PSObject.Properties.Name -contains "min_confidence") {
    [double]$case.min_confidence
  } else {
    0.0
  }
  $status = if ($result.PSObject.Properties.Name -contains "identity_status") {
    [string]$result.identity_status
  } else {
    ""
  }
  $statusAllowed = !($case.disallow_unconfirmed -and $status -eq "unconfirmed")
  $passed = $matched -and ($confidence -ge $minConfidence) -and $statusAllowed

  $line = "{0} {1}: {2} / {3} ({4:P0}) status={5}" -f `
    ($(if ($passed) { "PASS" } else { "FAIL" })), `
    $case.id, `
    $result.common_name, `
    $result.scientific_name, `
    $confidence, `
    $status
  Write-Host $line -ForegroundColor ($(if ($passed) { "Green" } else { "Red" }))

  $results += [pscustomobject]@{
    id = $case.id
    passed = $passed
    common_name = $result.common_name
    scientific_name = $result.scientific_name
    confidence = $confidence
    identity_status = $status
  }

  if (!$passed) { $failures += 1 }
}

Write-Host ""
Write-Host "Scan accuracy summary: tested=$tested skipped=$skipped failures=$failures"
$results | Format-Table -AutoSize

if (($Strict -and $tested -eq 0) -or $failures -gt 0) {
  exit 1
}

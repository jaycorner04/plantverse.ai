$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $projectRoot 'assets\data'
$outputPath = Join-Path $outputDir 'plant_taxonomy_10000.json'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$records = New-Object System.Collections.Generic.List[object]
$limit = 1000
$target = 10000

for ($offset = 0; $offset -lt $target; $offset += $limit) {
  $uri = "https://api.gbif.org/v1/species/search?highertaxon_key=7707728&rank=SPECIES&status=ACCEPTED&limit=$limit&offset=$offset"
  Write-Host "Fetching GBIF vascular plant species offset $offset"
  $response = Invoke-RestMethod -Uri $uri

  foreach ($item in $response.results) {
    if ($records.Count -ge $target) { break }

    $commonNames = @()
    if ($item.vernacularNames) {
      $commonNames = @(
        $item.vernacularNames |
          Where-Object { $_.vernacularName -and (!$_.language -or $_.language -eq 'eng') } |
          Select-Object -First 5 |
          ForEach-Object { $_.vernacularName }
      )
    }

    $description = $null
    if ($item.descriptions -and $item.descriptions.Count -gt 0) {
      $description = $item.descriptions[0].description
    }

    $records.Add([ordered]@{
      gbifKey = $item.key
      scientificName = $item.scientificName
      canonicalName = $item.canonicalName
      authorship = $item.authorship
      family = $item.family
      genus = $item.genus
      order = $item.order
      className = $item.class
      phylum = $item.phylum
      commonNames = $commonNames
      description = $description
      source = 'GBIF Backbone Taxonomy'
      sourceUrl = "https://www.gbif.org/species/$($item.key)"
    })
  }
}

$payload = [ordered]@{
  source = 'GBIF Backbone Taxonomy'
  sourceUrl = 'https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c'
  highertaxon = 'Tracheophyta'
  highertaxonKey = 7707728
  rank = 'SPECIES'
  status = 'ACCEPTED'
  generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  count = $records.Count
  records = $records
}

$json = $payload | ConvertTo-Json -Depth 8 -Compress
Set-Content -LiteralPath $outputPath -Value $json -Encoding UTF8
Write-Host "Wrote $($records.Count) plant records to $outputPath"

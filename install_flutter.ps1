$ErrorActionPreference = "Stop"

$url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.6-stable.zip"
$zipPath = "flutter.zip"
$extractPath = ".\"

Write-Host "Downloading Flutter SDK..."
Invoke-WebRequest -Uri $url -OutFile $zipPath

Write-Host "Extracting Flutter SDK... This might take a few minutes."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Write-Host "Removing zip file..."
Remove-Item $zipPath

Write-Host "Flutter SDK downloaded and extracted successfully."

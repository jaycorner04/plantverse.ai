param(
  [string]$Region = '',
  [string]$ServiceName = 'plantverse-ai-backend',
  [string]$RepositoryName = 'plantverse-ai-backend',
  [string]$EnvFile = '',
  [string]$ImageTag = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not $Region) {
  $Region = (& aws configure get region).Trim()
  if (-not $Region) { $Region = 'ap-south-1' }
}
if (-not $EnvFile) {
  $EnvFile = Join-Path $root 'backend\.env'
}
if (-not $ImageTag) {
  $ImageTag = (Get-Date -Format 'yyyyMMddHHmmss')
}

function Read-EnvFile {
  param([string]$Path)
  $result = [ordered]@{}
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing backend env file: $Path"
  }
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#') -or -not $line.Contains('=')) {
      return
    }
    $parts = $line.Split('=', 2)
    $key = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($key -and $value) {
      $result[$key] = $value
    }
  }
  return $result
}

function Aws-Json {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )
  $output = & aws @Args --output json
  if ($LASTEXITCODE -ne 0) {
    throw "AWS CLI command failed: aws $($Args -join ' ')"
  }
  return $output | ConvertFrom-Json
}

Write-Host "Checking AWS credentials in $Region..."
$identity = Aws-Json sts get-caller-identity --region $Region
$accountId = $identity.Account
Write-Host "Using AWS account $accountId"

Write-Host "Checking Docker..."
docker info | Out-Null

$repoUri = "$accountId.dkr.ecr.$Region.amazonaws.com/$RepositoryName"
$imageUri = "${repoUri}:$ImageTag"

Write-Host "Ensuring ECR repository $RepositoryName..."
try {
  Aws-Json ecr describe-repositories --repository-names $RepositoryName --region $Region | Out-Null
} catch {
  Aws-Json ecr create-repository --repository-name $RepositoryName --region $Region | Out-Null
}

Write-Host "Logging in to ECR..."
$password = & aws ecr get-login-password --region $Region
if ($LASTEXITCODE -ne 0 -or -not $password) {
  throw 'Failed to get ECR login password.'
}
$password | docker login --username AWS --password-stdin $repoUri | Out-Null

Write-Host "Building backend Docker image..."
docker build -t "${RepositoryName}:$ImageTag" -f (Join-Path $root 'backend\Dockerfile') (Join-Path $root 'backend')
docker tag "${RepositoryName}:$ImageTag" $imageUri

Write-Host "Pushing image to ECR..."
docker push $imageUri

$roleName = 'PlantVerseAppRunnerEcrAccessRole'
$trustPolicyPath = Join-Path $env:TEMP 'plantverse-apprunner-trust-policy.json'
@'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@ | Set-Content -LiteralPath $trustPolicyPath -Encoding ascii

Write-Host "Ensuring App Runner ECR access role..."
try {
  $role = Aws-Json iam get-role --role-name $roleName --region $Region
} catch {
  $role = Aws-Json iam create-role `
    --role-name $roleName `
    --assume-role-policy-document "file://$trustPolicyPath" `
    --region $Region
}

$roleArn = $role.Role.Arn
aws iam attach-role-policy `
  --role-name $roleName `
  --policy-arn 'arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess' `
  --region $Region | Out-Null

$runtimeEnv = Read-EnvFile -Path $EnvFile
$runtimeEnv['PORT'] = '8787'

$sourceConfigPath = Join-Path $env:TEMP 'plantverse-apprunner-source-config.json'
$sourceConfiguration = [ordered]@{
  ImageRepository = [ordered]@{
    ImageIdentifier = $imageUri
    ImageRepositoryType = 'ECR'
    ImageConfiguration = [ordered]@{
      Port = '8787'
      RuntimeEnvironmentVariables = $runtimeEnv
    }
  }
  AutoDeploymentsEnabled = $false
  AuthenticationConfiguration = [ordered]@{
    AccessRoleArn = $roleArn
  }
}
$sourceConfiguration | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $sourceConfigPath -Encoding UTF8

$serviceArn = $null
$services = Aws-Json apprunner list-services --region $Region
foreach ($service in $services.ServiceSummaryList) {
  if ($service.ServiceName -eq $ServiceName) {
    $serviceArn = $service.ServiceArn
    break
  }
}

if ($serviceArn) {
  Write-Host "Updating App Runner service $ServiceName..."
  Aws-Json apprunner update-service `
    --service-arn $serviceArn `
    --source-configuration "file://$sourceConfigPath" `
    --region $Region | Out-Null
} else {
  Write-Host "Creating App Runner service $ServiceName..."
  $createInputPath = Join-Path $env:TEMP 'plantverse-apprunner-create-service.json'
  [ordered]@{
    ServiceName = $ServiceName
    SourceConfiguration = $sourceConfiguration
    HealthCheckConfiguration = [ordered]@{
      Protocol = 'HTTP'
      Path = '/api/health'
      Interval = 10
      Timeout = 5
      HealthyThreshold = 1
      UnhealthyThreshold = 5
    }
  } | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $createInputPath -Encoding UTF8
  $created = Aws-Json apprunner create-service --cli-input-json "file://$createInputPath" --region $Region
  $serviceArn = $created.Service.ServiceArn
}

Write-Host "Waiting for App Runner service to become RUNNING..."
aws apprunner wait service-running --service-arn $serviceArn --region $Region
if ($LASTEXITCODE -ne 0) {
  throw 'App Runner service did not reach RUNNING state.'
}

$serviceDetails = Aws-Json apprunner describe-service --service-arn $serviceArn --region $Region
$serviceUrl = "https://$($serviceDetails.Service.ServiceUrl)"

Write-Host ''
Write-Host "Backend deployed:"
Write-Host $serviceUrl
Write-Host ''
Write-Host 'Build the public APK with:'
Write-Host ".\scripts\build_backend_apk.ps1 -BackendBaseUrl `"$serviceUrl`""

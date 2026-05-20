param(
  [string]$Region = '',
  [string]$ApplicationName = 'plantverse-ai',
  [string]$EnvironmentName = 'plantverse-ai-prod',
  [string]$EnvFile = '',
  [string]$PublicBaseUrl = '',
  [switch]$CreateCloudFront
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend'
if (-not $Region) {
  $Region = (& aws configure get region).Trim()
  if (-not $Region) { $Region = 'ap-south-1' }
}
if (-not $EnvFile) {
  $EnvFile = Join-Path $backend '.env'
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
  if (-not $output) { return $null }
  return $output | ConvertFrom-Json
}

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [object]$Value,
    [int]$Depth = 8
  )

  $json = $Value | ConvertTo-Json -Depth $Depth
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

function Ensure-IamRole {
  param(
    [string]$RoleName,
    [string]$ServicePrincipal,
    [string[]]$PolicyArns
  )

  $trustPath = Join-Path $env:TEMP "$RoleName-trust.json"
  [ordered]@{
    Version = '2012-10-17'
    Statement = @(
      [ordered]@{
        Effect = 'Allow'
        Principal = [ordered]@{ Service = $ServicePrincipal }
        Action = 'sts:AssumeRole'
      }
    )
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $trustPath -Encoding ascii

  try {
    $role = Aws-Json iam get-role --role-name $RoleName --region $Region
  } catch {
    $role = Aws-Json iam create-role `
      --role-name $RoleName `
      --assume-role-policy-document "file://$trustPath" `
      --region $Region
  }

  foreach ($policyArn in $PolicyArns) {
    aws iam attach-role-policy `
      --role-name $RoleName `
      --policy-arn $policyArn `
      --region $Region | Out-Null
  }

  return $role.Role.Arn
}

function Ensure-InstanceProfile {
  param([string]$RoleName)

  $profile = $null
  try {
    $profile = Aws-Json iam get-instance-profile `
      --instance-profile-name $RoleName `
      --region $Region
  } catch {
    Aws-Json iam create-instance-profile `
      --instance-profile-name $RoleName `
      --region $Region | Out-Null
    Start-Sleep -Seconds 5
    $profile = Aws-Json iam get-instance-profile `
      --instance-profile-name $RoleName `
      --region $Region
  }

  $hasRole = $false
  foreach ($role in $profile.InstanceProfile.Roles) {
    if ($role.RoleName -eq $RoleName) {
      $hasRole = $true
      break
    }
  }

  if (-not $hasRole) {
    Aws-Json iam add-role-to-instance-profile `
      --instance-profile-name $RoleName `
      --role-name $RoleName `
      --region $Region | Out-Null
  }
}

function New-BackendBundle {
  param([string]$VersionLabel)

  $stage = Join-Path $env:TEMP "plantverse-eb-$VersionLabel"
  $zipPath = Join-Path $env:TEMP "plantverse-eb-$VersionLabel.zip"
  if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  Copy-Item -LiteralPath (Join-Path $backend 'package.json') -Destination $stage -Force
  Copy-Item -LiteralPath (Join-Path $backend 'server.mjs') -Destination $stage -Force
  Copy-Item -LiteralPath (Join-Path $backend 'public') -Destination (Join-Path $stage 'public') -Recurse -Force
  'web: npm start' | Set-Content -LiteralPath (Join-Path $stage 'Procfile') -Encoding ascii

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open(
    $zipPath,
    [System.IO.Compression.ZipArchiveMode]::Create
  )
  try {
    Get-ChildItem -LiteralPath $stage -Recurse -File | ForEach-Object {
      $relative = $_.FullName.Substring($stage.Length).TrimStart('\', '/')
      $entryName = $relative -replace '\\', '/'
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip,
        $_.FullName,
        $entryName,
        [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  } finally {
    $zip.Dispose()
  }
  return $zipPath
}

function Select-NodeSolutionStack {
  $stacks = (Aws-Json elasticbeanstalk list-available-solution-stacks --region $Region).SolutionStacks
  $preferred = $stacks |
    Where-Object { $_ -like '*Amazon Linux 2023*' -and $_ -like '*Node.js*' } |
    Sort-Object -Descending |
    Select-Object -First 1
  if (-not $preferred) {
    $preferred = $stacks |
      Where-Object { $_ -like '*Node.js*' } |
      Sort-Object -Descending |
      Select-Object -First 1
  }
  if (-not $preferred) {
    throw 'Could not find an Elastic Beanstalk Node.js solution stack.'
  }
  return $preferred
}

Write-Host "Checking AWS credentials in $Region..."
$identity = Aws-Json sts get-caller-identity --region $Region
$accountId = $identity.Account
Write-Host "Using AWS account $accountId"

$serviceRoleName = 'aws-elasticbeanstalk-service-role'
$ec2RoleName = 'aws-elasticbeanstalk-ec2-role'

Write-Host 'Ensuring Elastic Beanstalk IAM roles...'
Ensure-IamRole `
  -RoleName $serviceRoleName `
  -ServicePrincipal 'elasticbeanstalk.amazonaws.com' `
  -PolicyArns @(
    'arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth',
    'arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy'
  ) | Out-Null

Ensure-IamRole `
  -RoleName $ec2RoleName `
  -ServicePrincipal 'ec2.amazonaws.com' `
  -PolicyArns @(
    'arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier'
  ) | Out-Null
Ensure-InstanceProfile -RoleName $ec2RoleName

$versionLabel = "plantverse-$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))"
$bundlePath = New-BackendBundle -VersionLabel $versionLabel
$bucketName = "plantverse-ai-eb-$accountId-$Region".ToLowerInvariant()
$s3Key = "deployments/$versionLabel.zip"

Write-Host "Ensuring deployment bucket s3://$bucketName..."
try {
  Aws-Json s3api head-bucket --bucket $bucketName --region $Region | Out-Null
} catch {
  if ($Region -eq 'us-east-1') {
    Aws-Json s3api create-bucket --bucket $bucketName --region $Region | Out-Null
  } else {
    Aws-Json s3api create-bucket `
      --bucket $bucketName `
      --region $Region `
      --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
  }
}

Write-Host 'Uploading backend bundle...'
aws s3 cp $bundlePath "s3://$bucketName/$s3Key" --region $Region | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Failed to upload Elastic Beanstalk bundle.'
}

Write-Host "Ensuring Elastic Beanstalk application $ApplicationName..."
$apps = Aws-Json elasticbeanstalk describe-applications `
  --application-names $ApplicationName `
  --region $Region
if ($apps.Applications.Count -eq 0) {
  Aws-Json elasticbeanstalk create-application `
    --application-name $ApplicationName `
    --description 'PlantVerse AI web app and backend API' `
    --region $Region | Out-Null
}

Write-Host "Creating application version $versionLabel..."
Aws-Json elasticbeanstalk create-application-version `
  --application-name $ApplicationName `
  --version-label $versionLabel `
  --source-bundle "S3Bucket=$bucketName,S3Key=$s3Key" `
  --region $Region | Out-Null

$runtimeEnv = Read-EnvFile -Path $EnvFile
$runtimeEnv['PORT'] = '8080'
if (-not $runtimeEnv.Contains('MAX_BODY_BYTES')) {
  $runtimeEnv['MAX_BODY_BYTES'] = '12000000'
}
if (-not $runtimeEnv.Contains('APP_VERSION_NAME')) {
  $runtimeEnv['APP_VERSION_NAME'] = '1.0.2'
}
if (-not $runtimeEnv.Contains('APP_VERSION_CODE')) {
  $runtimeEnv['APP_VERSION_CODE'] = '3'
}
if ($PublicBaseUrl) {
  $runtimeEnv['PUBLIC_BASE_URL'] = $PublicBaseUrl.TrimEnd('/')
}

$optionSettings = @(
  [ordered]@{
    Namespace = 'aws:elasticbeanstalk:environment'
    OptionName = 'EnvironmentType'
    Value = 'SingleInstance'
  },
  [ordered]@{
    Namespace = 'aws:autoscaling:launchconfiguration'
    OptionName = 'IamInstanceProfile'
    Value = $ec2RoleName
  },
  [ordered]@{
    Namespace = 'aws:autoscaling:launchconfiguration'
    OptionName = 'InstanceType'
    Value = 't3.micro'
  }
)

foreach ($entry in $runtimeEnv.GetEnumerator()) {
  $optionSettings += [ordered]@{
    Namespace = 'aws:elasticbeanstalk:application:environment'
    OptionName = $entry.Key
    Value = [string]$entry.Value
  }
}

$optionSettingsPath = Join-Path $env:TEMP 'plantverse-eb-option-settings.json'
Write-JsonFile -Path $optionSettingsPath -Value $optionSettings -Depth 8

$existing = Aws-Json elasticbeanstalk describe-environments `
  --application-name $ApplicationName `
  --environment-names $EnvironmentName `
  --region $Region

if ($existing.Environments.Count -gt 0) {
  Write-Host "Updating Elastic Beanstalk environment $EnvironmentName..."
  Aws-Json elasticbeanstalk update-environment `
    --environment-name $EnvironmentName `
    --version-label $versionLabel `
    --option-settings "file://$optionSettingsPath" `
    --region $Region | Out-Null
} else {
  $solutionStack = Select-NodeSolutionStack
  Write-Host "Creating Elastic Beanstalk environment $EnvironmentName with $solutionStack..."
  Aws-Json elasticbeanstalk create-environment `
    --application-name $ApplicationName `
    --environment-name $EnvironmentName `
    --solution-stack-name $solutionStack `
    --version-label $versionLabel `
    --option-settings "file://$optionSettingsPath" `
    --region $Region | Out-Null
}

Write-Host 'Waiting for Elastic Beanstalk deployment...'
aws elasticbeanstalk wait environment-updated `
  --application-name $ApplicationName `
  --environment-names $EnvironmentName `
  --region $Region
if ($LASTEXITCODE -ne 0) {
  throw 'Elastic Beanstalk environment did not finish updating.'
}

$details = Aws-Json elasticbeanstalk describe-environments `
  --application-name $ApplicationName `
  --environment-names $EnvironmentName `
  --region $Region
$ebCname = $details.Environments[0].CNAME
$ebUrl = "http://$ebCname"

Write-Host ''
Write-Host "Elastic Beanstalk URL:"
Write-Host $ebUrl

if ($CreateCloudFront) {
  $callerReference = "plantverse-$versionLabel"
  $distributionConfigPath = Join-Path $env:TEMP 'plantverse-cloudfront-config.json'
  $distributionConfig = [ordered]@{
    CallerReference = $callerReference
    Comment = "PlantVerse AI $EnvironmentName"
    Enabled = $true
    Origins = [ordered]@{
      Quantity = 1
      Items = @(
        [ordered]@{
          Id = 'plantverse-eb-origin'
          DomainName = $ebCname
          CustomOriginConfig = [ordered]@{
            HTTPPort = 80
            HTTPSPort = 443
            OriginProtocolPolicy = 'http-only'
            OriginSslProtocols = [ordered]@{
              Quantity = 1
              Items = @('TLSv1.2')
            }
          }
        }
      )
    }
    DefaultCacheBehavior = [ordered]@{
      TargetOriginId = 'plantverse-eb-origin'
      ViewerProtocolPolicy = 'redirect-to-https'
      AllowedMethods = [ordered]@{
        Quantity = 7
        Items = @('GET', 'HEAD', 'OPTIONS', 'PUT', 'PATCH', 'POST', 'DELETE')
        CachedMethods = [ordered]@{
          Quantity = 2
          Items = @('GET', 'HEAD')
        }
      }
      Compress = $true
      CachePolicyId = '4135ea2d-6df8-44a3-9df3-4b5a84be39ad'
      OriginRequestPolicyId = 'b689b0a8-53d0-40ab-baf2-68738e2966ac'
    }
    PriceClass = 'PriceClass_100'
    Restrictions = [ordered]@{
      GeoRestriction = [ordered]@{
        RestrictionType = 'none'
        Quantity = 0
      }
    }
    ViewerCertificate = [ordered]@{
      CloudFrontDefaultCertificate = $true
    }
  }
  Write-JsonFile -Path $distributionConfigPath -Value $distributionConfig -Depth 20

  Write-Host 'Creating CloudFront HTTPS distribution...'
  $distribution = Aws-Json cloudfront create-distribution `
    --distribution-config "file://$distributionConfigPath"
  $cloudFrontUrl = "https://$($distribution.Distribution.DomainName)"

  Write-Host ''
  Write-Host 'CloudFront HTTPS URL:'
  Write-Host $cloudFrontUrl
  Write-Host ''
  Write-Host 'CloudFront can take 5-20 minutes to finish deploying.'
  Write-Host "Future deploys can reuse this HTTPS base URL with:"
  Write-Host ".\scripts\deploy_backend_aws_elastic_beanstalk.ps1 -Region $Region -PublicBaseUrl `"$cloudFrontUrl`""
  Write-Host ''
  Write-Host "Build APK with: .\scripts\build_backend_apk.ps1 -BackendBaseUrl `"$cloudFrontUrl`""
} else {
  Write-Host ''
  Write-Host 'For mobile browser camera and APK backend HTTPS, run again with -CreateCloudFront.'
  if ($PublicBaseUrl) {
    Write-Host "Public HTTPS base URL configured: $PublicBaseUrl"
  }
}

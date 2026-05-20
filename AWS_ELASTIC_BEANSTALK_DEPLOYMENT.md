# PlantVerse AI AWS Deployment Without App Runner

This deploys the existing `backend/server.mjs` as a normal Node.js app on
AWS Elastic Beanstalk. It does not use Docker or App Runner.

## What This Creates

- Elastic Beanstalk application: `plantverse-ai`
- Elastic Beanstalk environment: `plantverse-ai-prod`
- Single EC2 instance running Node.js
- S3 deployment bucket for uploaded zip bundles
- Required Elastic Beanstalk IAM roles if they do not exist
- Optional CloudFront distribution for an HTTPS public URL

Use CloudFront for the final public link. Mobile browser camera access needs a
secure HTTPS origin, and APK backend calls should also use HTTPS.

## Before Deploying

AWS credentials must work:

```powershell
aws sts get-caller-identity
```

If this fails with `SignatureDoesNotMatch`, run:

```powershell
aws configure
```

Then enter a matching access key and secret access key.

Your backend keys must exist locally in:

```text
backend/.env
```

Do not commit that file.

## Deploy

From the project root:

```powershell
.\scripts\deploy_backend_aws_elastic_beanstalk.ps1 -Region ap-south-1 -CreateCloudFront
```

The script prints two URLs:

- Elastic Beanstalk HTTP URL
- CloudFront HTTPS URL

Use the CloudFront HTTPS URL as your public app/backend URL.

CloudFront can take 5-20 minutes to finish deploying.

## Build APK Against AWS

After CloudFront is ready:

```powershell
.\scripts\build_backend_apk.ps1 -BackendBaseUrl "https://YOUR_CLOUDFRONT_DOMAIN.cloudfront.net"
```

Then upload/copy the APK if needed.

## Cost Notes

Elastic Beanstalk is not a separate paid service, but the EC2 instance, S3
storage, and CloudFront traffic can cost money. A single `t3.micro` environment
is the smallest practical setup used by the script.

## If You Need To Remove It

Delete the Elastic Beanstalk environment first, then the application, S3 bucket,
and CloudFront distribution if created.

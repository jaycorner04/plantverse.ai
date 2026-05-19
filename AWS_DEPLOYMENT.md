# AWS Backend Deployment

PlantVerse uses `BACKEND_BASE_URL` for public APKs so API keys stay on the server.
The backend is a small Node service in `backend/` and is designed for AWS App Runner.
App Runner gives the backend a public HTTPS URL.

## Prerequisites

- AWS CLI configured with a valid access key and secret key.
- Docker Desktop running.
- `backend/.env` filled with provider keys.
- AWS permissions for ECR, App Runner, and IAM role creation.

## Deploy

From the project root:

```powershell
.\scripts\deploy_backend_aws_apprunner.ps1 -Region ap-south-1
```

The script will:

- Create or reuse an ECR repository named `plantverse-ai-backend`.
- Build and push the backend Docker image.
- Create or update an App Runner service named `plantverse-ai-backend`.
- Set provider keys as App Runner environment variables.
- Print the public backend URL.

## Build Public APK

After the deploy script prints a backend URL, rebuild the APK with:

```powershell
.\scripts\build_backend_apk.ps1 -BackendBaseUrl "https://your-app-runner-url"
```

Share:

```text
mobile-apk\PlantVerse-AI-backend-release.apk
```

## Notes

- Do not commit `backend/.env`.
- AWS may charge for App Runner/ECR usage.
- If you rotate provider keys, update `backend/.env` locally and rerun the deploy script.

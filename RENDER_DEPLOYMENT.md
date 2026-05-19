# Render Backend Deployment

Use this when AWS App Runner is blocked by account activation or billing limits.
Render can host the PlantVerse backend as a free HTTPS web service.

## What You Need

- A Render account: https://render.com
- GitHub connected to Render.
- This repo pushed to GitHub.
- Provider keys copied from local `backend/.env`.

## Deploy From Blueprint

1. Open Render Dashboard.
2. Click **New**.
3. Choose **Blueprint**.
4. Connect GitHub and select `jaycorner04/plantverse.ai`.
5. Render will read `render.yaml`.
6. Choose the free plan when prompted.
7. Fill the secret environment variables:
   - `GEMINI_API_KEY`
   - `GROQ_API_KEY`
   - `OPENROUTER_API_KEY`
   - `PLANTNET_API_KEY`
   - `PLANT_ID_API_KEY`
   - `PERENUAL_API_KEY`
8. Deploy.

When deploy finishes, Render gives a URL like:

```text
https://plantverse-ai-backend.onrender.com
```

Check:

```text
https://plantverse-ai-backend.onrender.com/api/health
```

## Build Public APK

After Render gives the backend URL:

```powershell
.\scripts\build_backend_apk.ps1 -BackendBaseUrl "https://plantverse-ai-backend.onrender.com"
```

Share:

```text
mobile-apk\PlantVerse-AI-backend-release.apk
```

## Free Plan Notes

Render free web services sleep after inactivity. The first request after sleep
can take around a minute, then later requests are faster. This is okay for a
test/beta APK, but a paid always-on service is better for production.

# PlantVerse AI

A modern, AI-powered cross-platform mobile application built with Flutter, Riverpod, and Supabase.

## Overview
PlantVerse AI allows users to identify plants, diagnose diseases, save plants to a personal garden, and chat with an AI botanical assistant. It features a premium Glassmorphism design and smooth animations.

## Setup Instructions

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.0.0+)
- Android Studio or Xcode (for emulation/building)
- A Supabase project

### 2. Install Dependencies
Run the following command in the project root:
```bash
flutter pub get
```

### 3. Backend Setup (Supabase)
1. Go to [Supabase](https://supabase.com/).
2. Create a new project.
3. Open the **SQL Editor** in your Supabase dashboard.
4. Copy the contents of `supabase_schema.sql` from this repository and run it. This will create all necessary tables and Row Level Security (RLS) policies.
5. In your Supabase dashboard, go to **Project Settings -> API** and copy your `URL` and `anon key`.
6. Uncomment the Supabase initialization code in `lib/main.dart` and paste your keys.

### 4. Running the App
To run the app on an emulator or connected device:
```bash
flutter run
```

### 4.1 Free Mode and Optional Live AI

The app works without a Gemini key. In free mode, scans and plant doctor use
an embedded offline catalog for common houseplants, so the APK does not stop
because of API quota. This free mode can show likely plant names, scientific
names, care guidance, toxicity warnings, pet safety, watering, light, humidity,
temperature, and general plant-health steps.

Free mode uses local catalog signals when available. When there is no reliable
offline match, PlantVerse shows conservative general care guidance instead of
forcing a wrong species name. Live Gemini recognition is still more accurate for
exact species ID from photos.

The APK also includes a 10,000-record offline vascular-plant taxonomy index
generated from the GBIF Backbone Taxonomy. This lets free mode remember many
scientific plant names, families, genera, and taxonomy references when a clear
name signal is available. Taxonomy-only matches do not invent care or toxicity:
they show identity/classification and conservative safety guidance until a
source-backed care profile is added.

For personal builds, you can pass Gemini at build/run time without bundling a
`.env` asset:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key
```

You can also pass backup provider keys with `--dart-define`, for example
`--dart-define=PLANTNET_API_KEY=your_key`.

For APKs shared with friends, use the backend proxy instead of compiling API
keys into the APK. Put all provider keys on the server, then build the app with
only the backend URL:

```bash
cd backend
npm start

flutter build apk --release --dart-define=BACKEND_BASE_URL=https://your-backend-url
```

Local backend development runs on `http://127.0.0.1:8787` for web testing. For
testing on a physical Android phone on the same Wi-Fi, build with your computer
LAN address, for example `http://192.168.1.4:8787`. Friends outside your Wi-Fi
need a public hosted HTTPS backend URL from a service such as Render, Railway,
Fly.io, or a VPS. The Flutter app calls `BACKEND_BASE_URL` first; if it is
unavailable, it falls back to the packaged offline catalog instead of exposing
provider keys.

For AWS public deployment, use the App Runner guide in `AWS_DEPLOYMENT.md`.
If AWS account activation blocks App Runner, use the free Render path in
`RENDER_DEPLOYMENT.md`.

When a Gemini key is configured, the app tries live AI first. It automatically
falls back to free offline mode only when the Gemini quota/rate limit is reached.
Other API errors are shown as errors instead of silently switching modes.

Optional backup providers can be configured with your own free/limited keys:

```bash
GEMINI_API_KEY=your_gemini_key
GROQ_API_KEY=your_groq_key
GROQ_VISION_MODEL=meta-llama/llama-4-scout-17b-16e-instruct
OPENROUTER_API_KEY=your_openrouter_key
PLANT_ID_API_KEY=your_plantid_key
PERENUAL_API_KEY=your_perenual_key
```

PlantVerse uses them in this order: Gemini first, then Groq vision, then
OpenRouter vision, then Pl@ntNet, then Plant.id. Plant.id is called through the
v3 identification endpoint first, with a compatibility fallback for accounts
that still answer through the older v2 identify route. Perenual is used to
enrich care data after a backup provider returns a plant name. If all configured
cloud providers are unavailable or out of quota, the app uses the packaged
offline catalog/taxonomy mode.

For exact cloud species recognition and photo-specific diagnosis, add your own
Gemini API key in a local `.env` file:

```bash
GEMINI_API_KEY=your_key_here
GEMINI_MODEL=gemini-2.5-flash
```

After changing `.env`, rebuild/restart the app. Do not commit `.env` or upload
APK/web builds that contain private keys.

### 5. Building for Production

#### Build Android APK
```bash
flutter build apk --release
```
The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

#### Build Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

#### Build iOS (requires macOS)
```bash
flutter build ios --release
```

## Architecture
This project follows a Clean Architecture approach:
- `lib/core/`: Theming, constants, and routing.
- `lib/features/` & `lib/screens/`: UI logic and presentation.
- `lib/services/`: API and database communication.
- `lib/providers/`: State management using Riverpod.
- `lib/widgets/`: Reusable UI components (like `GlassContainer`).

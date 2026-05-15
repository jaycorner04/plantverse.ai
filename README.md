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

### 4.1 Enable Live AI
Create a free Gemini API key in Google AI Studio, then add it in `.env`:
```bash
GEMINI_API_KEY=your_key_here
GEMINI_MODEL=gemini-2.5-flash
```

After changing `.env`, rebuild/restart the app. The scanner, plant doctor, and chatbot use this key for real AI responses. Without it, the app shows a setup message instead of fake answers.

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

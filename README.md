# GradTrack

GradTrack is the Graduate Tracking and Alumni Management System for Bohol
Island State University - Bilar Campus. This repository is organized as a
monorepo containing the Flutter client and Node.js API.

## Repository structure

```text
gradtrack/
|- frontend/   Flutter application for Android, web, and Windows
|- backend/    Node.js API and Firebase deployment configuration
|- docs/       Architecture documentation (see RBAC map below)
|- README.md
`- .gitignore
```

## Architecture documentation

- [`docs/rbac-architecture.md`](docs/rbac-architecture.md) — role model, route
  access matrix, Firestore rules map, and UI enforcement points.

## Frontend

Requirements:

- Flutter SDK compatible with Dart `>=3.3.0 <4.0.0`
- A configured Firebase project

Setup:

```powershell
cd frontend
Copy-Item assets/.env.example assets/.env
flutterfire configure --project=<your-project-id>
flutter pub get
flutter run
```

### Running for Google Sign-In (Fixed Web Port)

Google OAuth requires a fixed origin (e.g. `http://localhost:3000`). To launch Flutter Web with a fixed port:

```powershell
# Option A: PowerShell helper script
.\run_web.ps1 -Port 3000

# Option B: Direct Flutter CLI command
cd frontend
flutter run -d chrome --web-port=3000
```

> **Google OAuth Configuration Checklist:**
> 1. In **Google Cloud Console** -> *APIs & Services* -> *Credentials*, add `http://localhost:3000` under **Authorized JavaScript origins**.
> 2. In **Firebase Console** -> *Authentication* -> *Settings* -> *Authorized domains*, ensure `localhost` is listed.

The FlutterFire command generates the ignored project-specific files,
including `lib/config/firebase_options.dart` and
`android/app/google-services.json`.

Run frontend verification:

```powershell
cd frontend
flutter analyze
flutter test
```

## Backend

Requirements:

- Node.js 20 or newer
- Firebase Admin service-account values for authenticated API routes

Setup:

```powershell
cd backend
Copy-Item .env.example .env
# Populate Firebase Admin credentials for authenticated routes:
# FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY
npm install
npm run dev
```

The API starts on `http://localhost:3000` by default.

Available endpoints:

- `GET /health` - service and Firebase configuration status
- `GET /api` - API metadata
- `GET /api/profile` - authenticated profile lookup
- `PATCH /api/profile` - authenticated profile update

Authenticated endpoints expect a Firebase ID token:

```text
Authorization: Bearer <firebase-id-token>
```

Run backend verification:

```powershell
cd backend
npm test
```

Firebase rules and indexes are deployed from the backend directory:

```powershell
cd backend
Copy-Item .firebaserc.example .firebaserc
firebase deploy --only firestore:rules,firestore:indexes,storage
```

## Security

The following local files are excluded from Git:

- Frontend and backend `.env` files
- FlutterFire-generated Firebase configuration
- `google-services.json` and Apple Firebase plist files
- Firebase CLI project selection
- Service-account JSON files
- Android signing keys and certificates
- Build output, dependency folders, IDE state, and logs

Do not place a Cloudinary API secret in a production Flutter build. Signed
upload operations must be moved behind the backend before production release.
Use the provided `.env.example` files only as templates and never commit real
credential values.

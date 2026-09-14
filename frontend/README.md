# GradTrack Frontend

Flutter client for GradTrack (Android, web, Windows). All data — auth,
profiles, employment, surveys, messaging, content — is served by the
GradTrack MySQL backend over a REST API. There is no Firebase dependency.

```powershell
# 1. Start the backend first (see backend/README / repo README):
#    cd backend; npm install; npm run migrate; npm run seed; npm run dev

# 2. Point the app at it:
Copy-Item assets/.env.example assets/.env
# Edit assets/.env -> BACKEND_API_URL=http://localhost:3000 (or your host)

flutter pub get
flutter run
```

Demo logins (created by `npm run seed` in `backend/`):

- admin  -> admin@gradtrack.edu.ph  / admin123
- alumni -> alumni@gradtrack.edu.ph / alumni123
- Alumni-ID signup -> registry ID `BISU-2024-001` (pending)
- Google -> "Continue with Google" (verified email, auto-provisioned)

Old Firebase-only accounts do not exist in MySQL (password hashes cannot
be migrated): re-register through the Alumni ID flow or ask an admin to
create the account.

Production web bundle (`build/web`, served by Firebase Hosting config):

```powershell
flutter build web --release
```

This repo's release build uses compressed images, tree-shaken icons, the
service worker (repeat-visit caching), and a mobile viewport tag. Measure
with Lighthouse against the **release** build, not `flutter run` (debug
builds are unoptimized and score poorly).

See the repository root `README.md` for the full API map and security guidance.

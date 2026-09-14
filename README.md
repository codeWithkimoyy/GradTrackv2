# GradTrack

GradTrack is the Graduate Tracking and Alumni Management System for Bohol
Island State University - Bilar Campus. This repository is organized as a
monorepo containing the Flutter client and Node.js API.

## Repository structure

```text
gradtrack/
|- frontend/   Flutter application for Android, web, and Windows
|- backend/    Node.js + MySQL API (auth, profiles, tracer data)
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
- The GradTrack backend running (MySQL API, see below)

Setup:

```powershell
cd frontend
Copy-Item assets/.env.example assets/.env
# Edit assets/.env -> BACKEND_API_URL=http://localhost:3000 (or your host)
flutter pub get
flutter run
```

### Sign-in methods

- **Alumni ID + password** — register via Verify Alumni ID (registry-gated).
- **Email + password** — seeded/admin-created accounts.
- **Continue with Google** — Google ID token verified server-side
  (`POST /api/auth/google`) and linked to a MySQL profile by verified
  email (auto-created on first sign-in). No Firebase dependency.

> Google web sign-in requires the origin (e.g. `http://localhost:3000`)
> under **Google Cloud Console → APIs & Services → Credentials →
> Authorized JavaScript origins** for the `GOOGLE_SIGN_IN_CLIENT_ID`
> in `assets/.env`, and the same client ID as
> `GOOGLE_SIGN_IN_CLIENT_ID` in `backend/.env`.

### Running the web app (fixed port)

To launch Flutter Web with a fixed port:

```powershell
# Option A: PowerShell helper script
.\run_web.ps1 -Port 3000

# Option B: Direct Flutter CLI command
cd frontend
flutter run -d chrome --web-port=3000
```

Run frontend verification:

```powershell
cd frontend
flutter analyze
flutter test
```

## Backend

Requirements:

- Node.js 20 or newer
- MySQL 5.7+ / MariaDB reachable with the `SQL_*` credentials in `backend/.env`

Setup:

```powershell
cd backend
Copy-Item .env.example .env
# Populate SQL_HOST / SQL_PORT / SQL_USER / SQL_PASS / SQL_DATABASE
npm install
npm run migrate   # create all tables
npm run seed      # admin + demo alumni accounts
npm run dev       # dev mode (watch); use `npm start` for a plain server
```

> Run the backend with Node.js (`npm start` / `npm run dev`). Do not
> launch `src/server.js` through another program's bundled runtime —
> dropped connections there surface in the app as login failures.

The API starts on `http://localhost:3000` by default.

Available endpoints (all JSON, MySQL-backed):

- `GET /health` - service and database status
- `GET /api` - API metadata
- `POST /api/auth/register` - alumni-ID or email registration
- `POST /api/auth/login` - email/Alumni-ID + password sign-in
- `GET /api/auth/me` - current session profile
- `GET /api/profile` - authenticated profile lookup
- `PATCH /api/profile` - authenticated profile update
- `GET /api/alumni` - alumni directory (auth)
- `GET|POST|PATCH|DELETE /api/employment...` - employment + milestones
- `GET|PUT|DELETE /api/documents...` - resume + certificates
- `GET|POST|PATCH|DELETE /api/surveys...` - tracer surveys + responses
- `GET|POST|PATCH|DELETE /api/notifications...` - bell notifications
- `GET|POST|PATCH /api/conversations...` - alumni/admin messaging
- `GET|POST|PATCH|DELETE /api/content/:collection` - announcements, events, jobs, reports
- `GET /api/stats/...` - dashboard aggregates, batches, approvals
- `GET|POST /api/audit-logs` - admin audit trail
- `GET|PUT /api/settings` - system settings

Authenticated endpoints expect the session token returned by login/register:

```text
Authorization: Bearer <session-token>
```

Run backend verification:

```powershell
cd backend
npm test
```

## Security

The following local files are excluded from Git:

- Frontend and backend `.env` files
- `google-services.json` and Apple plist files (legacy)
- Service-account JSON files
- Android signing keys and certificates
- Build output, dependency folders, IDE state, and logs

Do not place a Cloudinary API secret in a production Flutter build. Signed
upload operations must be moved behind the backend before production release.
Use the provided `.env.example` files only as templates and never commit real
credential values.

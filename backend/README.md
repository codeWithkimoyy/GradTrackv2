# GradTrack Backend

Node.js API for GradTrack. It provides health checks and authenticated profile
operations backed by Firebase Admin.

```powershell
Copy-Item .env.example .env
npm install
npm run dev
```

The server starts without Firebase credentials so `/health` and `/api` can be
used locally. Authenticated routes return `503 firebase_not_configured` until
all Firebase Admin values are set in `backend/.env`.

To enable authenticated backend routes, set these env vars in `backend/.env`:
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Never commit the real `.env`, `.firebaserc`, service-account files, or private
keys.

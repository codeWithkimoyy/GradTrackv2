# GradTrack — Going Live on MySQL (SQLyog host)

The backend stays on **MySQL**. The hosted API connects to the same MySQL
server you already manage in SQLyog. No database is deleted or replaced.

## 0. Pre-flight (in SQLyog)

1. Confirm the database from `backend/.env.example` (`SQL_HOST`, `SQL_USER`,
   `SQL_DATABASE`) is reachable and you can browse the tables.
2. The hosted API connects over the internet, so the MySQL user needs
   **remote access**: its `Host` must be `%` (not `localhost`).
   Check with: `SELECT user, host FROM mysql.user;`
3. Port **3306** must be reachable from the host's outbound IPs
   (shared hosts often restrict this — if the API can't connect, ask your
   MySQL provider to allowlist Render/Railway IPs or use their remote-MySQL
   setting, usually called "Remote MySQL" in cPanel).
4. Back up first: in SQLyog, right-click the database -> **Backup Database**.

## 1. Prepare the schema (from your machine)

```powershell
cd backend
Copy-Item .env.example .env   # fill in SQL_* with your live values
npm install
npm run migrate   # safe to re-run; backfills missing columns + procedures
npm run seed      # admin + demo accounts (skip if live DB already seeded)
npm test          # expect: pass 37, fail 0
```

## 2. Deploy the API

### Option A — Render (blueprint included)

1. Push the repo to GitHub.
2. Render Dashboard -> **New -> Blueprint**, select the repo
   (`backend/render.yaml` is picked up automatically).
3. Fill the `sync: false` values: `SQL_HOST/USER/PASS/DATABASE`,
   `CORS_ORIGINS` (your real frontend origins, no `*`),
   `MESSAGE_ENCRYPTION_KEY` (same key as local — losing it makes stored
   chat history unreadable), plus SMTP/Cloudinary/Google IDs.
4. Deploy. Render runs `node src/server.js` and health-checks `/health`.

### Option B — Railway / any Docker host

```powershell
cd backend
docker build -t gradtrack-backend .
docker run --env-file .env.production -p 3000:3000 gradtrack-backend
```

`backend/Dockerfile` runs as non-root, exposes `3000`, and health-checks
`/health`. Set the same env keys as in `backend/.env.production.example`.

## 3. Verify live

```powershell
curl https://<your-api>/health
# {"status":"ok","service":"gradtrack-backend","dbConfigured":true,"dbKind":"mysql",...}

curl https://<your-api>/api
# {"name":"GradTrack API","version":"2.0.0",...}
```

If `dbConfigured` is `false`, the API is up but MySQL refused the
connection — re-check step 0 (user host, firewall, credentials).

## 4. Point the Flutter app at live

In `frontend/assets/.env`:

```text
BACKEND_API_URL=https://<your-api>
```

Rebuild the web bundle and redeploy it. Google web sign-in needs the
frontend origin added under **Google Cloud Console -> Credentials ->
Authorized JavaScript origins** (see root README).

## 5. Production checklist

- [ ] `CORS_ORIGINS` lists exact origins (no wildcard)
- [ ] `MESSAGE_ENCRYPTION_KEY` set and backed up separately
- [ ] No `.env` / secrets committed (`git status` clean of them)
- [ ] SQLyog backup taken before `migrate`/`seed` against live
- [ ] `/health` returns `dbConfigured: true`
- [ ] Login + one write flow (e.g. log employment) tested against live
- [ ] Rollback plan: previous Render/Railway deployment -> **Rollback**;
      database restores from the SQLyog backup (migrations are additive,
      so app rollback never needs a DB downgrade)

## Note: Neon files in the repo

`backend/src/config/pg.js`, `src/db/migrations.pg.sql`, and
`src/db/migrate.pg.js` are a dormant, opt-in Postgres adapter. They do
nothing unless `DATABASE_URL` is set — with it absent, the app uses MySQL
exactly as before (all 37 tests cover that path).

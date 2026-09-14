# GradTrack Backend

Node.js + Express API for GradTrack, backed by MySQL. It provides session
auth (scrypt password hashing, opaque bearer tokens), user/registry
management, employment, documents, surveys, notifications, messaging,
content, stats, audit logs, and settings endpoints.

```powershell
Copy-Item .env.example .env
# Populate SQL_HOST / SQL_PORT / SQL_USER / SQL_PASS / SQL_DATABASE
npm install
npm run migrate   # create all tables (safe to re-run)
npm run seed      # admin + demo alumni accounts + demo registry entry
npm run dev       # or: npm start
```

The server starts on `http://localhost:3000` by default. `/health` reports
`mysqlConfigured` once the pool connects. Authenticated routes expect:

```text
Authorization: Bearer <session-token>
```

Run verification:

```powershell
npm test
```

Because the hosting MySQL user has no `DELETE` privilege, removals are
soft-deletes (`is_deleted` / `deleted_at` columns); every read filters them
out. `npm run migrate` backfills those columns on older databases.

Never commit the real `.env`, service-account files, or private keys.

# GradTrack Backend

Node.js + Express API for GradTrack, backed by MySQL. It provides session
auth (scrypt password hashing, opaque bearer tokens), user/registry
management, employment, documents, surveys, notifications, messaging,
content, stats, audit logs, and settings endpoints.

```powershell
Copy-Item .env.example .env
# Populate SQL_HOST / SQL_PORT / SQL_USER / SQL_PASS / SQL_DATABASE
# Optional but recommended: MESSAGE_ENCRYPTION_KEY (= long random string)
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

## Chat message encryption at rest

Chat text (`messages.text` and the `conversations.last_message` preview) is
encrypted with AES-256-GCM before it is written to MySQL. The key comes from
`MESSAGE_ENCRYPTION_KEY` in `.env` and is never stored inside the database,
so a database dump or backup does not expose readable chat history. Encrypted
values are stored as `v5:<iv>:<authTag>:<ciphertext>`; the API still hands the
app plain text.

- If `MESSAGE_ENCRYPTION_KEY` is empty the server logs a warning and keeps
  working in plaintext (intended for development only).
- Generate a key with `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`.
- Back it up separately: losing the key makes stored chat history unreadable.
- GCM also detects tampering — an edited chat row fails to decrypt instead of
  being served with changed content.
- To encrypt chat rows created before the key was added, run `npm run encrypt-messages`
  (idempotent, safe to re-run).

Note: the server itself must be able to decrypt messages to serve them, so a
full compromise of the hosting server would still expose chat content.

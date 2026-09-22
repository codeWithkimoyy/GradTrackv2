/* eslint-disable no-console */
// Applies src/db/migrations.pg.sql to Neon Postgres.
// Usage:
//   $env:DATABASE_URL="postgresql://user:pass@ep-xxx.neon.tech/db?sslmode=require"
//   npm run migrate:neon
const fs = require('node:fs');
const path = require('node:path');

const connectionString =
  process.env.DATABASE_URL ||
  process.env.NEON_DATABASE_URL ||
  process.env.POSTGRES_URL ||
  '';

async function main() {
  if (!connectionString) {
    console.error(
      '[migrate:neon] DATABASE_URL is not set. Copy backend/.env.neon.example to .env.neon and export it first.',
    );
    process.exit(1);
  }
  let pg;
  try {
    pg = require('pg');
  } catch (_) {
    console.error('[migrate:neon] missing dependency: run `npm install` first (needs `pg`).');
    process.exit(1);
  }
  const client = new pg.Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 20000,
  });
  await client.connect();
  try {
    const file = path.join(__dirname, 'migrations.pg.sql');
    const sql = fs.readFileSync(file, 'utf8');
    await client.query(sql);
    const tables = await client.query(
      `SELECT count(*)::int AS c FROM information_schema.tables
       WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`,
    );
    console.log(
      `[migrate:neon] schema is up to date (${tables.rows[0].c} tables in public).`,
    );
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('[migrate:neon] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { main };

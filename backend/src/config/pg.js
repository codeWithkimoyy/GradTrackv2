// Neon (Postgres) connection + MySQL-dialect translator.
// Lets the existing `mysql.query(sql, params)` call sites run unmodified
// against Neon by rewriting the small set of MySQL-isms used in routes:
//   - `?` placeholders -> `$1, $2, ...`
//   - backticks -> double quotes
//   - `UPDATE ... LIMIT 1` -> `UPDATE ...` (Postgres has no LIMIT on UPDATE;
//     all such call sites already filter by primary key)
//   - `VALUES(...)` inside ON DUPLICATE KEY UPDATE is handled at the route
//     level (see settings.js / employment.js branches on db.isPostgres).
let Pool = null;
try {
  ({ Pool } = require('pg'));
} catch (_) {
  // `pg` is installed via npm install (see package.json).
}

const connectionString =
  process.env.DATABASE_URL ||
  process.env.NEON_DATABASE_URL ||
  process.env.POSTGRES_URL ||
  '';

let pool = null;
let isConnected = false;

if (Pool && connectionString) {
  pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false }, // Neon requires TLS
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 15000,
  });

  pool
    .query('SELECT 1')
    .then(() => {
      isConnected = true;
      console.log('[Neon] Connected to Postgres (Neon).');
    })
    .catch((err) => {
      isConnected = false;
      console.warn(`[Neon] Connection pending or unavailable: ${err.message}`);
    });

  pool.on('error', (err) => {
    console.warn(`[Neon] Pool notice: ${err.message}`);
  });
}

function translatePlaceholders(sql) {
  let index = 0;
  return sql.replace(/\?/g, () => {
    index += 1;
    return `$${index}`;
  });
}

function translate(sql) {
  let out = sql;
  // Backtick identifiers -> double-quoted identifiers.
  out = out.replace(/`([^`]+)`/g, '"$1"');
  // Postgres has no `UPDATE ... LIMIT n`.
  out = out.replace(/\bUPDATE\b([\s\S]*?)\bLIMIT\s+\d+\s*(;?\s*)$/i, 'UPDATE$1$2');
  return translatePlaceholders(out);
}

async function query(sql, params = []) {
  if (!pool) {
    throw new Error('Neon connection pool is not initialized (DATABASE_URL missing).');
  }
  const text = translate(sql);
  const result = await pool.query(text, params);
  // Match mysql2's `query` shape: routes expect an array of rows.
  if (Array.isArray(result)) return result;
  if (result && Array.isArray(result.rows)) return result.rows;
  return result;
}

async function call() {
  // Neon has no MySQL stored procedures. Callers in routes/middleware already
  // fall back to raw SQL when `call` throws, so fail fast with a clear code.
  const err = new Error('Stored procedures are not available on Neon Postgres; use raw SQL fallback.');
  err.code = 'NEON_NO_PROCEDURES';
  throw err;
}

async function close() {
  if (pool) {
    await pool.end();
    pool = null;
  }
}

module.exports = {
  pool,
  translate,
  get isConnected() {
    return isConnected;
  },
  get configured() {
    return Boolean(Pool && connectionString);
  },
  query,
  call,
  callProcedure: call,
  callRaw: call,
  close,
};

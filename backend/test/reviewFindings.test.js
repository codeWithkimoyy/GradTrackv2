const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { afterEach, test } = require('node:test');

process.env.NODE_ENV = 'test';

const alumniRouter = require('../src/routes/alumni');
const db = require('../src/db/procedures');
const mysql = require('../src/config/mysql');

const originalListAlumni = db.users.listAlumni;
const originalQuery = mysql.query;

afterEach(() => {
  db.users.listAlumni = originalListAlumni;
  mysql.query = originalQuery;
});

function alumniListHandler() {
  const layer = alumniRouter.stack.find(
    (candidate) => candidate.route?.path === '/' && candidate.route.methods.get,
  );
  assert.ok(layer, 'GET / alumni route must exist');
  return layer.route.stack.at(-1).handle;
}

async function invokeAlumniList() {
  let responseBody;
  await alumniListHandler()(
    { query: {} },
    {
      json(value) {
        responseBody = value;
        return this;
      },
    },
    (error) => {
      throw error;
    },
  );
  return responseBody;
}

test('GET /api/alumni returns plain rows from the stored procedure', async () => {
  const rows = [{ id: 'alumni-1' }];
  db.users.listAlumni = async () => rows;

  assert.deepEqual(await invokeAlumniList(), rows);
});

test('GET /api/alumni returns plain rows from the MySQL fallback', async () => {
  const rows = [{ id: 'alumni-2' }];
  db.users.listAlumni = async () => {
    throw new Error('procedure unavailable');
  };
  mysql.query = async () => rows;

  assert.deepEqual(await invokeAlumniList(), rows);
});

test('partial-update procedures preserve omitted date fields', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../src/db/stored_procedures.sql'),
    'utf8',
  );

  assert.match(sql, /opening_date\s*=\s*COALESCE\(p_opening_date, opening_date\)/);
  assert.match(sql, /closing_date\s*=\s*COALESCE\(p_closing_date, closing_date\)/);
  assert.match(sql, /end_date\s*=\s*COALESCE\(p_end_date, end_date\)/g);
  assert.equal(
    [...sql.matchAll(/end_date\s*=\s*COALESCE\(p_end_date, end_date\)/g)].length,
    2,
  );
});

test('Android release configuration keeps secrets out of source control', () => {
  const androidRoot = path.join(__dirname, '../../frontend/android');
  const gradle = fs.readFileSync(
    path.join(androidRoot, 'app/build.gradle.kts'),
    'utf8',
  );
  const gitignore = fs.readFileSync(path.join(androidRoot, '.gitignore'), 'utf8');

  assert.match(gradle, /targetSdk\s*=\s*36/);
  assert.doesNotMatch(gradle, /(?:storePassword|keyPassword)\s*=\s*"[^"$]+"/);
  assert.match(gradle, /key\.properties/);
  assert.match(gitignore, /^\.env$/m);
  assert.match(gitignore, /^!\.env\.example$/m);
  assert.match(gitignore, /^key\.properties$/m);
});

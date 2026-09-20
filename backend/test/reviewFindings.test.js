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
  const procedures = fs.readFileSync(
    path.join(__dirname, '../src/db/procedures.js'),
    'utf8',
  );
  const createProcedure = sql.match(
    /CREATE PROCEDURE sp_surveys_create\([\s\S]*?\nEND;/,
  )?.[0];
  const updateProcedure = sql.match(
    /CREATE PROCEDURE sp_surveys_update\([\s\S]*?\nEND;/,
  )?.[0];

  assert.ok(createProcedure);
  assert.ok(updateProcedure);
  assert.doesNotMatch(createProcedure, /p_clear_/);
  assert.match(updateProcedure, /IN p_clear_opening_date TINYINT/);
  assert.match(updateProcedure, /IN p_clear_closing_date TINYINT/);
  assert.match(updateProcedure, /IN p_clear_visible_batches TINYINT/);
  assert.match(updateProcedure, /opening_date\s*=\s*IF\(p_clear_opening_date=1, NULL, COALESCE\(p_opening_date, opening_date\)\)/);
  assert.match(updateProcedure, /closing_date\s*=\s*IF\(p_clear_closing_date=1, NULL, COALESCE\(p_closing_date, closing_date\)\)/);
  assert.match(updateProcedure, /visible_batches_json\s*=\s*IF\(p_clear_visible_batches=1, NULL, COALESCE\(p_visible_batches_json, visible_batches_json\)\)/);
  assert.match(procedures, /data\.opening_date === null \|\| data\.openingDate === null \? 1 : 0/);
  assert.match(procedures, /data\.closing_date === null \|\| data\.closingDate === null \? 1 : 0/);
  assert.match(procedures, /data\.visible_batches_json === null \|\| data\.visibleBatches === null\s+\? 1\s+: 0/);
  assert.match(sql, /end_date\s*=\s*COALESCE\(p_end_date, end_date\)/g);
  assert.equal(
    [...sql.matchAll(/end_date\s*=\s*COALESCE\(p_end_date, end_date\)/g)].length,
    2,
  );
});

test('clearing current employment preserves the excluded legacy job', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../src/db/stored_procedures.sql'),
    'utf8',
  );
  const route = fs.readFileSync(
    path.join(__dirname, '../src/routes/employment.js'),
    'utf8',
  );

  assert.match(
    sql,
    /UPDATE jobs SET is_current=0 WHERE created_by=p_user_id AND id <> p_exclude_id AND is_deleted=0/,
  );
  assert.match(
    route,
    /UPDATE jobs SET is_current = 0 WHERE created_by = \? AND id <> \? AND is_deleted = 0', \[userId, id\]/,
  );
});

test('bulk alumni notifications retain their recipient role', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../src/db/stored_procedures.sql'),
    'utf8',
  );

  assert.match(
    sql,
    /INSERT INTO notifications \(id, user_id, recipient_role, type, title, description\)\s+SELECT UUID\(\), id, 'alumni', p_type, p_title, p_description/,
  );
});

test('survey batch filters use MariaDB-compatible JSON candidates', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../src/db/stored_procedures.sql'),
    'utf8',
  );
  const compatibleCandidates = sql.match(
    /JSON_CONTAINS\(visible_batches_json, JSON_ARRAY\(p_graduation_year\)\)/g,
  );

  assert.equal(compatibleCandidates?.length, 2);
  assert.doesNotMatch(sql, /CAST\(p_graduation_year AS JSON\)/);
});

test('password reset cleanup removes expired or consumed codes', () => {
  const sql = fs.readFileSync(
    path.join(__dirname, '../src/db/stored_procedures.sql'),
    'utf8',
  );

  assert.match(
    sql,
    /DELETE FROM password_resets WHERE expires_at < NOW\(\) OR used=1/,
  );
});

test('Android release configuration keeps secrets out of source control', () => {
  const androidRoot = path.join(__dirname, '../../frontend/android');
  const gradle = fs.readFileSync(
    path.join(androidRoot, 'app/build.gradle.kts'),
    'utf8',
  );
  const gitignore = fs.readFileSync(path.join(androidRoot, '.gitignore'), 'utf8');
  const manifest = fs.readFileSync(
    path.join(androidRoot, 'app/src/main/AndroidManifest.xml'),
    'utf8',
  );

  assert.match(gradle, /targetSdk\s*=\s*36/);
  assert.doesNotMatch(gradle, /(?:storePassword|keyPassword)\s*=\s*"[^"$]+"/);
  assert.match(gradle, /key\.properties/);
  assert.match(gitignore, /^\.env$/m);
  assert.match(gitignore, /^!\.env\.example$/m);
  assert.match(gitignore, /^key\.properties$/m);
  assert.match(manifest, /tools:replace="android:required"/);
});

test('APK stream failures do not append text to a partial download', () => {
  const server = fs.readFileSync(
    path.join(__dirname, '../../serve_apk.js'),
    'utf8',
  );

  assert.match(server, /if \(res\.headersSent\) \{\s*res\.destroy\(err\);\s*return;/);
  assert.match(
    server,
    /res\.writeHead\(500, \{ 'Content-Type': 'text\/plain; charset=utf-8' \}\)/,
  );
});

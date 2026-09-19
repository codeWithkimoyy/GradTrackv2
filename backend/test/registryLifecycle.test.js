const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

process.env.NODE_ENV = 'test';

const app = require('../src/app');
const mysql = require('../src/config/mysql');

let server;
let baseUrl;
let adminToken;

function uniqueId(prefix = 'TEST-AUTO') {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
}

async function jsonRequest(path, options = {}) {
  const headers = { 'content-type': 'application/json', ...(options.headers ?? {}) };
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers });
  let body = null;
  const text = await response.text();
  if (text) body = JSON.parse(text);
  return { response, body };
}

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', () => {
      const address = server.address();
      baseUrl = `http://127.0.0.1:${address.port}`;
      resolve();
    });
  });
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
  await mysql.close();
});

test('alumni registry life-cycle: delete + re-add resets to pending and allows re-registration', async (t) => {
  // Admin session for the registry admin endpoints. Skipped gracefully when the
  // seed admin is missing from the target database.
  const login = await jsonRequest('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify({ identifier: 'admin@gradtrack.edu.ph', password: 'admin123' }),
  });
  if (login.response.status !== 200) {
    t.skip('seed admin not present; cannot exercise admin registry flow');
    return;
  }
  adminToken = login.body.token;

  const alumniId = uniqueId();
  const created = await jsonRequest('/api/alumni/registry', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ alumniId, fullName: 'Regression Alum', course: 'BS CS' }),
  });
  assert.equal(created.response.status, 201, JSON.stringify(created.body));
  assert.equal(created.body.status, 'pending');

  // Register -> the ID becomes active with a users row.
  const registered = await jsonRequest('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({ alumniId, password: 'secret123' }),
  });
  assert.equal(registered.response.status, 201, JSON.stringify(registered.body));

  // Admin deletes the record, then re-adds the same ID (as staff would after a
  // data-entry mistake). The restored entry must be Pending again so the alumni
  // can register a fresh account.
  const deleted = await jsonRequest(`/api/alumni/registry/${alumniId}`, {
    method: 'DELETE',
    headers: { authorization: `Bearer ${adminToken}` },
  });
  assert.equal(deleted.response.status, 200, JSON.stringify(deleted.body));
  // The admin "delete record" flow also disables the linked user account
  // (frontend: updateUser(disabled: true)); reproduce that here.
  await mysql.query(
    'UPDATE users SET disabled = 1 WHERE alumni_id = ?',
    [alumniId],
  );

  const restored = await jsonRequest('/api/alumni/registry', {
    method: 'POST',
    headers: { authorization: `Bearer ${adminToken}` },
    body: JSON.stringify({ alumniId, fullName: 'Regression Alum', course: 'BS CS' }),
  });
  assert.equal(restored.response.status, 201, JSON.stringify(restored.body));
  assert.equal(
    restored.body.status,
    'pending',
    're-adding a previously-registered ID must not leave it Active',
  );

  // The prior users row is soft-deleted, so a brand-new registration works.
  const reRegistered = await jsonRequest('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify({ alumniId, password: 'secret456' }),
  });
  assert.equal(reRegistered.response.status, 201, JSON.stringify(reRegistered.body));

  // Cleanup: remove the test traces from the registry and users tables.
  await mysql.query(
    'UPDATE alumni_registry SET is_deleted = 1, deleted_at = ? WHERE id = ?',
    [new Date().toISOString().slice(0, 19).replace('T', ' '), alumniId],
  );
  await mysql.query(
    'UPDATE users SET is_deleted = 1, deleted_at = ? WHERE alumni_id = ?',
    [new Date().toISOString().slice(0, 19).replace('T', ' '), alumniId],
  );
});
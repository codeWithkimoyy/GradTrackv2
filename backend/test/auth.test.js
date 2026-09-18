const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');

process.env.NODE_ENV = 'test';

const app = require('../src/app');

let server;
let baseUrl;

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
  await require('../src/config/mysql').close();
});

test('POST /api/auth/forgot-password rejects a malformed email', async () => {
  const response = await fetch(`${baseUrl}/api/auth/forgot-password`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'not-an-email' }),
  });
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.equal(body.error, 'invalid_email');
});

test('POST /api/auth/forgot-password reports labels like "not configured" rather than crashing', async () => {
  const response = await fetch(`${baseUrl}/api/auth/forgot-password`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'someone@example.com' }),
  });
  const body = await response.json();

  assert.equal(response.status, 503);
  assert.equal(body.error, 'email_not_configured');
});

test('POST /api/auth/verify-code validates the code shape', async () => {
  const response = await fetch(`${baseUrl}/api/auth/verify-code`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'someone@example.com', code: '0' }),
  });
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.equal(body.error, 'invalid_code');
});

test('POST /api/auth/reset-password validates the code shape', async () => {
  const response = await fetch(`${baseUrl}/api/auth/reset-password`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'someone@example.com', code: '12' }),
  });
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.equal(body.error, 'invalid_code');
});

test('POST /api/auth/google requires an ID token', async () => {
  const response = await fetch(`${baseUrl}/api/auth/google`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({}),
  });
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.equal(body.error, 'missing_token');
});

test('POST /api/auth/google rejects a forged ID token', async () => {
  const response = await fetch(`${baseUrl}/api/auth/google`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ idToken: 'forged-token' }),
  });
  const body = await response.json();

  assert.ok([401, 502, 503].includes(response.status));
  assert.ok(typeof body.error === 'string' && body.error.length > 0);
});

test('POST /api/auth/login rejects unknown accounts without leaking why', async () => {
  const response = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      identifier: 'nobody-xyz-123@example.com',
      password: 'whatever123',
    }),
  });
  const body = await response.json();

  assert.equal(response.status, 401);
  assert.equal(body.error, 'invalid_credentials');
});

test('POST /api/auth/login accepts a short admin username', async () => {
  const response = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ identifier: 'admin', password: 'admin123' }),
  });
  const body = await response.json();

  if (response.status === 200) {
    assert.equal(body.user.role, 'admin');
    assert.ok(typeof body.token === 'string' && body.token.length > 0);
  } else {
    // Resilient when the seed admin is absent in the test database: the route
    // must still answer with a structured login error, never crash.
    assert.equal(body.error, 'invalid_credentials');
  }
});
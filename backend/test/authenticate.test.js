const assert = require('node:assert/strict');
const { afterEach, test } = require('node:test');

process.env.NODE_ENV = 'test';

const authenticate = require('../src/middleware/authenticate');
const db = require('../src/db/procedures');
const mysql = require('../src/config/mysql');

const originalGetValid = db.authSessions.getValid;
const originalExtend = db.authSessions.extend;
const originalQuery = mysql.query;

afterEach(() => {
  db.authSessions.getValid = originalGetValid;
  db.authSessions.extend = originalExtend;
  mysql.query = originalQuery;
});

test('hydrates the user returned by the legacy valid-session procedure', async () => {
  db.authSessions.getValid = async () => [
    {
      id: 'session-123',
      user_id: 'user-456',
      expires_at: new Date(Date.now() + 60_000),
      revoked: 0,
      role: 'admin',
      email: 'admin@example.com',
      full_name: 'Admin User',
    },
  ];
  db.authSessions.extend = async () => {};
  mysql.query = async (sql, params) => {
    assert.match(sql, /SELECT \* FROM users/);
    assert.deepEqual(params, ['user-456']);
    return [
      {
        id: 'user-456',
        email: 'admin@example.com',
        full_name: 'Admin User',
        role: 'admin',
        disabled: 0,
        is_deleted: 0,
      },
    ];
  };

  const request = {
    get: (name) =>
      name === 'authorization' ? 'Bearer session-token' : undefined,
  };
  const response = {
    status() {
      assert.fail('authentication unexpectedly returned an HTTP error');
    },
  };
  let nextError;

  await authenticate(request, response, (error) => {
    nextError = error;
  });

  assert.equal(nextError, undefined);
  assert.equal(request.user.uid, 'user-456');
  assert.equal(request.user.role, 'admin');
});

const crypto = require('node:crypto');

// scrypt parameters (OWASP-recommended interactive-login strength).
const SCRYPT_KEYLEN = 64;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1, maxmem: 32 * 1024 * 1024 };

// Session lifetime: 30 days of inactivity.
const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;

function hashPassword(password) {
  return new Promise((resolve, reject) => {
    const salt = crypto.randomBytes(16).toString('hex');
    crypto.scrypt(password, salt, SCRYPT_KEYLEN, SCRYPT_OPTIONS, (err, key) => {
      if (err) return reject(err);
      resolve(`scrypt$${salt}$${key.toString('hex')}`);
    });
  });
}

function verifyPassword(password, stored) {
  return new Promise((resolve, reject) => {
    if (typeof stored !== 'string' || !stored.startsWith('scrypt$')) {
      return resolve(false);
    }
    const [, salt, expectedHex] = stored.split('$');
    if (!salt || !expectedHex) return resolve(false);
    crypto.scrypt(password, salt, SCRYPT_KEYLEN, SCRYPT_OPTIONS, (err, key) => {
      if (err) return reject(err);
      try {
        const expected = Buffer.from(expectedHex, 'hex');
        if (expected.length !== key.length) return resolve(false);
        resolve(crypto.timingSafeEqual(expected, key));
      } catch (_) {
        resolve(false);
      }
    });
  });
}

function newSessionToken() {
  return crypto.randomBytes(32).toString('hex');
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

function utcNowSql() {
  return new Date().toISOString().slice(0, 19).replace('T', ' ');
}

function expiresAtSql(ttlMs = SESSION_TTL_MS) {
  return new Date(Date.now() + ttlMs)
    .toISOString()
    .slice(0, 19)
    .replace('T', ' ');
}

module.exports = {
  SESSION_TTL_MS,
  hashPassword,
  verifyPassword,
  newSessionToken,
  sha256Hex,
  utcNowSql,
  expiresAtSql,
};

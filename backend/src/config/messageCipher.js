const crypto = require('node:crypto');
const env = require('./env');

// AES-256-GCM chat text encryption. The key comes from MESSAGE_ENCRYPTION_KEY
// in the server's .env file and NEVER lives inside the database. Encrypted
// values are stored as "v5:<iv>:<authTag>:<ciphertext>" so they can be told
// apart from legacy plaintext rows and a future key can set a new version tag.

const ALGORITHM = 'aes-256-gcm';
const VERSION = 'v5';
const IV_LENGTH = 12;
const UNAVAILABLE = '[Message unavailable]';

function hasKey() {
  return Boolean(env.messageEncryptionKey);
}

function derivedKey() {
  // Any non-empty secret is turned into a fixed 32-byte AES-256 key, so the
  // DBA / a SQL dump can never recover the key by reading the database.
  return crypto.createHash('sha256').update(env.messageEncryptionKey).digest();
}

function encrypt(plainText) {
  const value = typeof plainText === 'string' ? plainText : String(plainText);
  if (!hasKey()) {
    // No key configured (dev convenience: warn but keep running in plaintext).
    return value;
  }
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, derivedKey(), iv);
  const ciphertext = Buffer.concat([
    cipher.update(value, 'utf8'),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [
    VERSION,
    iv.toString('base64'),
    tag.toString('base64'),
    ciphertext.toString('base64'),
  ].join(':');
}

function decrypt(payload, fallback = UNAVAILABLE) {
  if (typeof payload !== 'string') return payload;
  if (payload.length === 0) return payload;
  if (!payload.startsWith(`${VERSION}:`)) {
    // Legacy plaintext row (e.g. written before encryption was enabled).
    return payload;
  }
  if (!hasKey()) return fallback;
  try {
    const parts = payload.split(':');
    if (parts.length !== 4) return fallback;
    const [, ivB64, tagB64, dataB64] = parts;
    const iv = Buffer.from(ivB64, 'base64');
    const tag = Buffer.from(tagB64, 'base64');
    const data = Buffer.from(dataB64, 'base64');
    const decipher = crypto.createDecipheriv(ALGORITHM, derivedKey(), iv);
    decipher.setAuthTag(tag);
    const plain = Buffer.concat([decipher.update(data), decipher.final()]);
    return plain.toString('utf8');
  } catch (_) {
    // Corrupted or tampered payload: GCM auth fails here.
    return fallback;
  }
}

if (!hasKey()) {
  console.warn(
    '[messageCipher] MESSAGE_ENCRYPTION_KEY is not set; chat text will be stored as plaintext.',
  );
}

module.exports = {
  VERSION,
  hasKey,
  encrypt,
  decrypt,
  UNAVAILABLE,
};
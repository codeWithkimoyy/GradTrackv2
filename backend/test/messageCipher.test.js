process.env.MESSAGE_ENCRYPTION_KEY = 'a'.repeat(64);
const assert = require('node:assert/strict');
const { test } = require('node:test');
const cipher = require('../src/config/messageCipher');

test('encrypt produces versioned ciphertext and decrypts back', () => {
  const plain = 'hello, eyes only 123 !@#';
  const blob = cipher.encrypt(plain);
  assert.ok(blob.startsWith('v5:'));
  assert.notEqual(blob, plain);
  assert.equal(cipher.decrypt(blob), plain);
});

test('encrypt uses a fresh IV for every call', () => {
  assert.notEqual(
    cipher.encrypt('same message'),
    cipher.encrypt('same message'),
  );
});

test('empty and null payloads pass through untouched', () => {
  assert.equal(cipher.decrypt(''), '');
  assert.equal(cipher.decrypt(null), null);
});

test('legacy plaintext rows pass through untouched', () => {
  assert.equal(cipher.decrypt('old plaintext chat'), 'old plaintext chat');
});

test('tampered ciphertext returns the fallback, never the true text', () => {
  const blob = cipher.encrypt('top secret');
  const lastChar = blob.slice(-2);
  const flipped = lastChar === 'AA' ? 'BB' : 'AA';
  const tampered = blob.slice(0, -2) + flipped;
  assert.equal(cipher.decrypt(tampered, '[unreadable]'), '[unreadable]');
});

test('hasKey is true when a key is configured', () => {
  assert.equal(cipher.hasKey(), true);
});
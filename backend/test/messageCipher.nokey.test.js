process.env.MESSAGE_ENCRYPTION_KEY = '';
const assert = require('node:assert/strict');
const { test } = require('node:test');
const cipher = require('../src/config/messageCipher');

test('hasKey is false when no key is configured', () => {
  assert.equal(cipher.hasKey(), false);
});

test('encrypt returns plaintext when no key is configured', () => {
  assert.equal(cipher.encrypt('keep it plain'), 'keep it plain');
});

test('decrypt returns plaintext when no key is configured', () => {
  assert.equal(cipher.decrypt('keep it plain'), 'keep it plain');
});
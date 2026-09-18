/* eslint-disable no-console */
// Encrypts any legacy plaintext chat rows left over from before 
// MESSAGE_ENCRYPTION_KEY was enabled. Idempotent: rows already carrying the
// "v5:" ciphertext marker are skipped, so it is safe to re-run.
// Usage: npm run encrypt-messages   (requires MESSAGE_ENCRYPTION_KEY in .env)
const cipher = require('../src/config/messageCipher');
const mysql = require('../src/config/mysql');

if (!cipher.hasKey()) {
  console.warn(
    '[encrypt-messages] MESSAGE_ENCRYPTION_KEY is not set; nothing was encrypted.',
  );
}

async function encryptColumn(table, column, whereClause) {
  const rows = await mysql.query(
    `SELECT id, \`${column}\` FROM \`${table}\` WHERE ${whereClause}`,
  );
  let updated = 0;
  for (const row of rows) {
    if (row[column] == null) continue;
    const encrypted = cipher.encrypt(row[column]);
    if (encrypted === row[column]) continue;
    // eslint-disable-next-line no-await-in-loop
    await mysql.query(
      `UPDATE \`${table}\` SET \`${column}\` = ? WHERE id = ?`,
      [encrypted, row.id],
    );
    updated += 1;
  }
  console.log(`[encrypt-messages] ${table}.${column}: ${updated} row(s) encrypted`);
  return updated;
}

async function main() {
  try {
    let total = 0;
    total += await encryptColumn(
      'messages',
      'text',
      "is_deleted = 0 AND text IS NOT NULL AND text NOT LIKE 'v5:%'",
    );
    total += await encryptColumn(
      'conversations',
      'last_message',
      "is_deleted = 0 AND last_message IS NOT NULL AND last_message NOT LIKE 'v5:%'",
    );
    console.log(`[encrypt-messages] done. ${total} row(s) encrypted in total.`);
  } finally {
    await mysql.close();
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('[encrypt-messages] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { main };
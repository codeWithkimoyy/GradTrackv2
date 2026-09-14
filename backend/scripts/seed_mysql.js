/* eslint-disable no-console */
// Seeds the GradTrack MySQL database with one account per role so each
// role dashboard can be signed into:
//
//   admin   -> admin@gradtrack.edu.ph   / admin123
//   alumni  -> alumni@gradtrack.edu.ph  / alumni123
//
// Credentials can be overridden with ADMIN_SEED_EMAIL / ADMIN_SEED_PASSWORD /
// ADMIN_SEED_NAME in backend/.env (admin only; the demo alumni is fixed).
//
// Usage:  npm run seed
//
// The script is idempotent: existing users are updated, never duplicated.
require('../src/config/env');

const crypto = require('node:crypto');
const env = require('../src/config/env');
const mysql = require('../src/config/mysql');
const passwords = require('../src/config/passwords');

const ACCOUNTS = [
  {
    email: env.adminSeed.email,
    password: env.adminSeed.password,
    fullName: env.adminSeed.fullName,
    role: 'admin',
  },
  {
    email: 'alumni@gradtrack.edu.ph',
    password: 'alumni123',
    fullName: 'Demo Alumni',
    role: 'alumni',
    course: 'BS Information Technology',
    graduationYear: 2024,
    academicYearGraduated: '2023-2024',
    employmentStatus: 'employed',
  },
];

async function seedAccount(account) {
  const existing = await mysql.query(
    'SELECT id FROM users WHERE email = ? LIMIT 1',
    [account.email],
  );
  const hash = await passwords.hashPassword(account.password);
  if (existing.length > 0) {
    await mysql.query(
      `UPDATE users SET password_hash = ?, full_name = ?, role = ?,
         is_approved = 1, is_verified = 1, email_verified = 1, disabled = 0,
         is_deleted = 0, deleted_at = NULL
       WHERE id = ?`,
      [hash, account.fullName, account.role, existing[0].id],
    );
    console.log(`[${account.role}] user exists (${account.email}), refreshed`);
    return existing[0].id;
  }
  const id = crypto.randomUUID();
  await mysql.query(
    `INSERT INTO users
       (id, email, password_hash, full_name, role, course_name,
        graduation_year, academic_year_graduated, employment_status,
        is_approved, is_verified, email_verified)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, 1)`,
    [
      id,
      account.email,
      hash,
      account.fullName,
      account.role,
      account.course ?? null,
      account.graduationYear ?? null,
      account.academicYearGraduated ?? null,
      account.employmentStatus ?? 'unemployed',
    ],
  );
  console.log(`[${account.role}] created user ${account.email}`);
  return id;
}

async function main() {
  if (!mysql.pool) {
    throw new Error('MySQL pool is not initialized. Check SQL_* in backend/.env.');
  }
  for (const account of ACCOUNTS) {
    // eslint-disable-next-line no-await-in-loop
    await seedAccount(account);
  }

  // A registry entry so the Alumni-ID signup flow can be tried end to end.
  const demo = await mysql.query(
    'SELECT id FROM alumni_registry WHERE id = ? LIMIT 1',
    ['BISU-2024-001'],
  );
  if (demo.length === 0) {
    await mysql.query(
      `INSERT INTO alumni_registry
         (id, full_name, course, academic_year_graduated, graduation_year, status)
       VALUES ('BISU-2024-001', 'Demo Alumni', 'BS Information Technology',
               '2023-2024', 2024, 'pending')`,
    );
    console.log('[registry] added demo entry BISU-2024-001 (pending)');
  }

  console.log('\nSeed complete. Demo logins:');
  console.log('----------------------------------------------');
  for (const a of ACCOUNTS) {
    console.log(`  ${a.role.padEnd(11)} ${a.email.padEnd(30)} ${a.password}`);
  }
  console.log('----------------------------------------------');
  process.exit(0);
}

main().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});

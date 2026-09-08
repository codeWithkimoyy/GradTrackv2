/* eslint-disable no-console */
/*
 * Seed the GradTrack Firebase project (gradtrack-db12d) with one demo
 * account per role so each role dashboard can be signed into:
 *
 *   admin   -> admin@gradtrack.edu.ph   / admin123
 *   alumni  -> alumni@gradtrack.edu.ph  / alumni123
 *
 * Requires a Firebase service-account key (never commit it):
 *
 *   Firebase Console -> Project Settings -> Service Accounts
 *   -> Generate new private key -> save the JSON
 *
 * Usage:
 *   node scripts/seed_roles.js --key=path/to/service-account.json
 *   # or:  $env:GOOGLE_APPLICATION_CREDENTIALS = "path\to\key.json"
 *   #      node scripts/seed_roles.js
 *
 * The script is idempotent: existing auth users and user docs are updated,
 * never duplicated.
 */
const path = require('path');
const admin = require('firebase-admin');

const PROJECT_ID = 'gradtrack-db12d';

const ACCOUNTS = [
  { role: 'admin', fullName: 'System Administrator' },
  { role: 'alumni', fullName: 'Demo Alumni' },
];

function resolveKeyPath() {
  const flag = process.argv.find((a) => a.startsWith('--key='));
  if (flag) return flag.slice('--key='.length);
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }
  if (process.env.SERVICE_ACCOUNT_PATH) return process.env.SERVICE_ACCOUNT_PATH;
  const local = path.join(__dirname, '..', 'service-account.json');
  return local;
}

function emailFor(role) {
  return `${role}@gradtrack.edu.ph`;
}

function passwordFor(role) {
  return `${role}123`;
}

async function seedAccount(auth, db, account) {
  const { role, fullName } = account;
  const email = emailFor(role);

  let uid;
  try {
    const existing = await auth.getUserByEmail(email);
    uid = existing.uid;
    console.log(`[${role}] auth user exists (${uid}), updating password/name`);
    await auth.updateUser(uid, {
      displayName: fullName,
      password: passwordFor(role),
      emailVerified: true,
    });
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const created = await auth.createUser({
      email,
      password: passwordFor(role),
      displayName: fullName,
      emailVerified: true,
    });
    uid = created.uid;
    console.log(`[${role}] created auth user ${uid}`);
  }

  const profile = {
    role,
    email,
    fullName,
    isVerified: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (role === 'alumni') {
    Object.assign(profile, {
      course: 'BS Information Technology',
      graduationYear: 2024,
      employmentStatus: 'employed',
      gender: 'Male',
      biography: 'Demo alumni profile for GradTrack testing.',
    });
  }

  await db.collection('users').doc(uid).set(profile, { merge: true });
  console.log(`[${role}] Firestore user doc ready`);
  return uid;
}

async function main() {
  const keyPath = resolveKeyPath();
  if (!require('fs').existsSync(keyPath)) {
    console.error(`Service-account key not found at: ${keyPath}`);
    console.error(
      'Download one from Firebase Console -> Project Settings -> Service Accounts -> Generate new private key, then run:',
    );
    console.error(`  node scripts/seed_roles.js --key=<path-to-key.json>`);
    process.exit(1);
  }

  admin.initializeApp({ credential: admin.credential.cert(keyPath) });
  const auth = admin.auth();
  const db = admin.firestore();

  for (const account of ACCOUNTS) {
    await seedAccount(auth, db, account);
  }

  console.log('\nAll role accounts are ready. Demo logins:');
  console.log('----------------------------------------------');
  for (const { role } of ACCOUNTS) {
    console.log(`  ${role.padEnd(11)} ${emailFor(role).padEnd(30)} ${passwordFor(role)}`);
  }
  console.log('----------------------------------------------');
  await admin.app().delete();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});

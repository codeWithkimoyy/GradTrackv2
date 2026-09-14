/* eslint-disable no-console */
/*
 * Emulator-based verification of the Firestore security rules.
 * Run (JDK 21+ required):
 *   $env:JAVA_HOME="C:\Users\User\Downloads\jdk-26_windows-x64_bin\jdk-26.0.1"
 *   $env:PATH="$env:JAVA_HOME\bin;$env:PATH"
 *   firebase emulators:exec --only firestore "node backend/scripts/rules.test.js"
 */
const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'demo-gradtrack';
const RULES = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

async function main() {
  const env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: '127.0.0.1', port: 8080, rules: RULES },
  });

  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection('users').doc('alumni-1').set({
      role: 'alumni', fullName: 'Demo Alumni', isVerified: true, createdAt: new Date(),
    });
    await db.collection('users').doc('admin-1').set({
      role: 'admin', fullName: 'Admin', isVerified: true, createdAt: new Date(),
    });
    await db.collection('users').doc('disabled-1').set({
      role: 'alumni', fullName: 'Disabled', disabled: true, createdAt: new Date(),
    });
    // PRIVATE docs force role-based evaluation on list reads.
    await db.collection('jobs').doc('job-private').set({
      jobTitle: 'Secret Job', visibility: 'private', createdBy: 'alumni-1',
    });
    await db.collection('jobs').doc('job-public').set({
      jobTitle: 'Public Job', visibility: 'public', createdBy: 'admin-1',
    });
    await db.collection('announcements').doc('ann-private').set({
      title: 'Secret Announcement', description: 'x', visibility: 'private',
    });
    await db.collection('alumni_registry').doc('ALUM-1').set({
      status: 'active', fullName: 'Demo Alumni',
    });
  });

  const results = [];
  const run = async (name, fn, expectFail = false) => {
    try {
      await fn();
      results.push([name, expectFail ? 'PASS (denied)' : 'PASS']);
    } catch (e) {
      results.push([name, expectFail ? 'WRONGLY-ALLOWED' : 'FAIL']);
      if (!expectFail) console.log('       ' + (e.message || e).split('\n')[0]);
    }
  };
  const alumni = env.authenticatedContext('alumni-1').firestore();
  const admin = env.authenticatedContext('admin-1').firestore();
  const ghost = env.authenticatedContext('ghost-1').firestore();
  const disabled = env.authenticatedContext('disabled-1').firestore();
  const guest = env.unauthenticatedContext().firestore();

  // ---------- ALUMNI ----------
  await run('alumni read jobs list (private doc present)', () => assertSucceeds(alumni.collection('jobs').get()));
  await run('alumni create job', () => assertSucceeds(alumni.collection('jobs').add({
    jobTitle: 'New Job', visibility: 'public', createdBy: 'alumni-1',
  })));
  await run('alumni list own employment_records', () => assertSucceeds(
    alumni.collection('employment_records').where('userId', '==', 'alumni-1').get()));
  await run('alumni create employment_record', () => assertSucceeds(
    alumni.collection('employment_records').add({
      userId: 'alumni-1', company: 'Acme', position: 'Dev',
    })));
  await run('alumni create career_milestone', () => assertSucceeds(
    alumni.collection('career_milestones').add({
      userId: 'alumni-1', title: 'First Job', date: new Date(),
    })));
  await run('alumni read announcements list', () => assertSucceeds(alumni.collection('announcements').get()));
  await run('alumni update own users doc', () => assertSucceeds(
    alumni.collection('users').doc('alumni-1').update({ employmentStatus: 'employed' })));
  await run('alumni send message', () => assertSucceeds(alumni.collection('messages').add({
    senderId: 'alumni-1', userId: 'alumni-1', recipientRole: 'admin',
  })));
  await run('alumni create admin notification', () => assertSucceeds(
    alumni.collection('notifications').add({
      userId: '', recipientRole: 'admin', type: 'employment',
    })));
  await run('alumni create survey response', () => assertSucceeds(
    alumni.collection('survey_responses').add({
      userId: 'alumni-1', surveyId: 's1', answers: {},
    })));

  // ---------- GHOST (no users doc) ----------
  await run('ghost read jobs list', () => assertSucceeds(ghost.collection('jobs').get()));
  await run('ghost create job', () => assertSucceeds(ghost.collection('jobs').add({
    jobTitle: 'Ghost Job', visibility: 'public', createdBy: 'ghost-1',
  })));
  await run('ghost create employment_record', () => assertSucceeds(
    ghost.collection('employment_records').add({
      userId: 'ghost-1', company: 'Acme', position: 'Dev',
    })));

  // ---------- DISABLED ----------
  await run('disabled read jobs list (deny)', () => assertFails(disabled.collection('jobs').get()), true);
  await run('disabled create job (deny)', () => assertFails(disabled.collection('jobs').add({
    jobTitle: 'x', visibility: 'public', createdBy: 'disabled-1',
  })), true);

  // ---------- ADMIN ----------
  await run('admin read jobs list', () => assertSucceeds(admin.collection('jobs').get()));
  await run('admin create job', () => assertSucceeds(admin.collection('jobs').add({
    jobTitle: 'Admin Job', visibility: 'public', createdBy: 'admin-1',
  })));
  await run('admin create announcement', () => assertSucceeds(admin.collection('announcements').add({
    title: 'Adv', description: 'x', visibility: 'public',
  })));
  await run('admin read users list', () => assertSucceeds(admin.collection('users').get()));
  await run('admin create notification (role broadcast)', () => assertSucceeds(
    admin.collection('notifications').add({ userId: '', type: 'announcement' })));
  await run('admin read conversations list', () => assertSucceeds(admin.collection('conversations').get()));

  // ---------- REGISTRATION / USERS CREATE ----------
  const newAlumni = env.authenticatedContext('new-alumni').firestore();
  const newAlumniBad = env.authenticatedContext('new-alumni-bad').firestore();
  const newAlumniNoId = env.authenticatedContext('new-alumni-noid').firestore();
  const newGuest = env.authenticatedContext('new-guest').firestore();
  const newAdmin = env.authenticatedContext('new-admin').firestore();

  await run('register alumni with valid registry id', () => assertSucceeds(
    newAlumni.collection('users').doc('new-alumni').set({
      role: 'alumni', fullName: 'New Alumni', alumniId: 'ALUM-1', createdAt: new Date(),
    })));
  await run('register alumni with unknown registry id (deny)', () => assertFails(
    newAlumniBad.collection('users').doc('new-alumni-bad').set({
      role: 'alumni', fullName: 'Bad', alumniId: 'NOPE', createdAt: new Date(),
    })), true);
  await run('register alumni with no alumniId (deny)', () => assertFails(
    newAlumniNoId.collection('users').doc('new-alumni-noid').set({
      role: 'alumni', fullName: 'NoId', createdAt: new Date(),
    })), true);
  await run('register guest role (deny)', () => assertFails(
    newGuest.collection('users').doc('new-guest').set({
      role: 'guest', fullName: 'Guest', createdAt: new Date(),
    })), true);
  await run('self-assign admin role (deny)', () => assertFails(
    newAdmin.collection('users').doc('new-admin').set({
      role: 'admin', fullName: 'Sneaky', createdAt: new Date(),
    })), true);

  // ---------- GUEST (unauthenticated) ----------
  await run('guest read public jobs (filtered)', () => assertSucceeds(
    guest.collection('jobs').where('visibility', '==', 'public').get()));
  await run('guest read all jobs (deny)', () => assertFails(guest.collection('jobs').get()), true);

  let pass = 0;
  let fail = 0;
  for (const [name, status] of results) {
    console.log(`${status.padEnd(22)} ${name}`);
    if (status === 'PASS' || status === 'PASS (denied)') pass += 1;
    else fail += 1;
  }

  await env.cleanup();
  console.log(`\n${pass} passed, ${fail} failed`);
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error('Test run error:', e);
  process.exit(1);
});
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

const auth = getAuth();
const db = getFirestore();

// Must stay in sync with AppStrings.alumniEmailSuffix in the Flutter app.
const ALUMNI_EMAIL_SUFFIX = '@gradtrack.bisu.edu.ph';
const ALUMNI_ID_PATTERN = /^[A-Za-z0-9_-]+$/;

function alumniEmailFromId(alumniId) {
  return `${alumniId}${ALUMNI_EMAIL_SUFFIX}`;
}

/**
 * Admin-only reset of an alumni's password. Alumni authenticate with an
 * Alumni ID against a synthesized login address, so only the Administrator
 * (with the Admin SDK) can change the password of another account.
 */
exports.resetAlumniPassword = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError(
      'unauthenticated',
      'You must be signed in to reset a password.'
    );
  }

  const profile = await db.collection('users').doc(uid).get();
  const data = profile.exists ? profile.data() : null;
  if (!data || data.role !== 'admin' || data.disabled === true) {
    throw new HttpsError(
      'permission-denied',
      'Only an administrator can reset alumni passwords.'
    );
  }

  const alumniId =
    typeof request.data?.alumniId === 'string'
      ? request.data.alumniId.trim()
      : '';
  const newPassword =
    typeof request.data?.newPassword === 'string'
      ? request.data.newPassword
      : '';

  if (!ALUMNI_ID_PATTERN.test(alumniId)) {
    throw new HttpsError(
      'invalid-argument',
      'A valid Alumni ID is required.'
    );
  }
  if (newPassword.length < 6) {
    throw new HttpsError(
      'invalid-argument',
      'The new password must be at least 6 characters.'
    );
  }

  const registryDoc = await db
    .collection('alumni_registry')
    .doc(alumniId)
    .get();
  if (!registryDoc.exists) {
    throw new HttpsError(
      'not-found',
      `Alumni ID ${alumniId} is not in the registry.`
    );
  }
  if (registryDoc.data().status !== 'active') {
    throw new HttpsError(
      'failed-precondition',
      `Alumni ID ${alumniId} has no active account yet (status: ${registryDoc.data().status}).`
    );
  }

  let user;
  try {
    user = await auth.getUserByEmail(alumniEmailFromId(alumniId));
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError(
        'not-found',
        `No account exists for Alumni ID ${alumniId}.`
      );
    }
    throw error;
  }

  await auth.updateUser(user.uid, { password: newPassword });

  return { message: 'password_updated', temporaryPassword: newPassword };
});
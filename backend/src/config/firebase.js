const admin = require('firebase-admin');
const env = require('./env');

const hasFirebaseCredentials = Boolean(
  env.firebase.projectId &&
    env.firebase.clientEmail &&
    env.firebase.privateKey,
);

if (hasFirebaseCredentials && admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: env.firebase.projectId,
      clientEmail: env.firebase.clientEmail,
      privateKey: env.firebase.privateKey,
    }),
  });
}

module.exports = {
  admin,
  hasFirebaseCredentials,
  auth: hasFirebaseCredentials ? admin.auth() : null,
  db: hasFirebaseCredentials ? admin.firestore() : null,
};

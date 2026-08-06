const { auth, hasFirebaseCredentials } = require('../config/firebase');

async function authenticate(request, response, next) {
  if (!hasFirebaseCredentials || auth == null) {
    return response.status(503).json({
      error: 'firebase_not_configured',
      message: 'Firebase Admin credentials are not configured on the server.',
    });
  }

  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    return response.status(401).json({
      error: 'missing_token',
      message: 'A Firebase ID token is required.',
    });
  }

  try {
    request.user = await auth.verifyIdToken(token, true);
    return next();
  } catch (_) {
    return response.status(401).json({
      error: 'invalid_token',
      message: 'The supplied authentication token is invalid or expired.',
    });
  }
}

module.exports = authenticate;

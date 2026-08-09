import 'dart:async';

String friendlyFirebaseError(Object error) {
  if (error is TimeoutException) {
    return 'Firebase did not respond in time. If your internet is stable, check that Firestore/Storage is enabled, rules and indexes are deployed, and browser extensions are not blocking googleapis.com.';
  }

  try {
    final String? code = _getFirebaseErrorCode(error);
    final String? message = _getFirebaseErrorMessage(error);

    if (code != null) {
      return switch (code) {
        'permission-denied' =>
          'Firebase rejected this request. Check your Firestore/Storage rules and make sure you are signed in as the record owner.',
        'failed-precondition' =>
          'Firebase needs a required index or setup step before this can save. Open the browser console for the Firebase link/details, then deploy the index.',
        'unavailable' =>
          'Firebase is unreachable from this browser. If your internet is stable, disable ad blockers/VPN for localhost and allow googleapis.com, then reload.',
        'unauthenticated' => 'Your session expired. Please sign in again.',
        'not-found' => 'Firebase could not find the requested resource.',
        _ => message == null || message.isEmpty
            ? 'Firebase error ($code).'
            : 'Firebase error ($code): $message',
      };
    }
  } catch (_) {
    // Fall back to the raw error string if type checks or property access fail.
  }

  return error.toString();
}

String? _getFirebaseErrorCode(Object error) {
  try {
    final dynamic dynamicError = error;
    final code = dynamicError.code;
    return code is String ? code : null;
  } catch (_) {
    return null;
  }
}

String? _getFirebaseErrorMessage(Object error) {
  try {
    final dynamic dynamicError = error;
    final message = dynamicError.message;
    return message is String ? message : null;
  } catch (_) {
    return null;
  }
}

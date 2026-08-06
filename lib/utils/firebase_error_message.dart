import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

String friendlyFirebaseError(Object error) {
  if (error is TimeoutException) {
    return 'Firebase did not respond in time. If your internet is stable, check that Firestore/Storage is enabled, rules and indexes are deployed, and browser extensions are not blocking googleapis.com.';
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firebase rejected this request. Check your Firestore/Storage rules and make sure you are signed in as the record owner.',
      'failed-precondition' =>
        'Firebase needs a required index or setup step before this can save. Open the browser console for the Firebase link/details, then deploy the index.',
      'unavailable' =>
        'Firebase is unreachable from this browser. If your internet is stable, disable ad blockers/VPN for localhost and allow googleapis.com, then reload.',
      'unauthenticated' => 'Your session expired. Please sign in again.',
      'not-found' => 'Firebase could not find the requested resource.',
      _ => error.message == null || error.message!.isEmpty
          ? 'Firebase error (${error.code}).'
          : 'Firebase error (${error.code}): ${error.message}',
    };
  }

  return error.toString();
}

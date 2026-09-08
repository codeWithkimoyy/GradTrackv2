import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

/// Central user profile repository for clean Firestore access.
class UserRepository {
  final FirebaseFirestore? _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ??
            (Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null);

  CollectionReference<Map<String, dynamic>>? get _users =>
      _firestore?.collection(FirestoreCollections.users);

  Stream<UserModel?> watchUser(String uid) {
    final collection = _users;
    if (collection == null) return Stream<UserModel?>.value(null);
    return collection.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromDoc(snapshot);
    });
  }

  Future<UserModel?> fetchUser(String uid) async {
    final collection = _users;
    if (collection == null) return null;
    final doc = await collection.doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  Future<void> saveUser(UserModel user, {bool merge = true}) async {
    final collection = _users;
    if (collection == null) return;
    await collection.doc(user.uid).set(user.toMap(), SetOptions(merge: merge));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> changes) async {
    final collection = _users;
    if (collection == null) return;
    await collection.doc(uid).update(changes);
  }

  Future<bool> userExists(String uid) async {
    final collection = _users;
    if (collection == null) return false;
    final doc = await collection.doc(uid).get();
    return doc.exists;
  }
}

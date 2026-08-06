import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

/// Central user profile repository for clean Firestore access.
class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.users);

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromDoc(snapshot);
    });
  }

  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? UserModel.fromDoc(doc) : null;
  }

  Future<void> saveUser(UserModel user, {bool merge = true}) {
    return _users.doc(user.uid).set(user.toMap(), SetOptions(merge: merge));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> changes) {
    return _users.doc(uid).update(changes);
  }

  Future<bool> userExists(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists;
  }
}

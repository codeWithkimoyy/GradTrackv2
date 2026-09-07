import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/app_constants.dart';
import '../models/notification_model.dart';

class NotificationService {
  FirebaseFirestore? get _firestore =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  Stream<List<AppNotification>> watchNotifications(String userId) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value([]);
    return firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<int> getUnreadCount(String userId) async {
    final firestore = _firestore;
    if (firestore == null) return 0;
    final snapshot = await firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> markAsRead(String notificationId) async {
    final firestore = _firestore;
    if (firestore == null) return;
    await firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final firestore = _firestore;
    if (firestore == null) return;
    final snapshot = await firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final firestore = _firestore;
    if (firestore == null) return;
    await firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteMultiple(List<String> notificationIds) async {
    final firestore = _firestore;
    if (firestore == null) return;
    final batch = firestore.batch();
    for (final id in notificationIds) {
      batch.delete(
          firestore.collection(FirestoreCollections.notifications).doc(id));
    }
    await batch.commit();
  }

  Future<void> createNotification(AppNotification notification) async {
    final firestore = _firestore;
    if (firestore == null) return;
    await firestore
        .collection(FirestoreCollections.notifications)
        .add(notification.toMap());
  }

  Future<AppNotification?> getNotification(String id) async {
    final firestore = _firestore;
    if (firestore == null) return null;
    final doc = await firestore
        .collection(FirestoreCollections.notifications)
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return AppNotification.fromMap(doc.data()!, doc.id);
  }
}

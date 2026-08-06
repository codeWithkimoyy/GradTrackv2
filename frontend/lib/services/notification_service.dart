import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteMultiple(List<String> notificationIds) async {
    final batch = _firestore.batch();
    for (final id in notificationIds) {
      batch.delete(
          _firestore.collection(FirestoreCollections.notifications).doc(id));
    }
    await batch.commit();
  }

  Future<void> createNotification(AppNotification notification) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .add(notification.toMap());
  }

  Future<AppNotification?> getNotification(String id) async {
    final doc = await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(id)
        .get();
    if (!doc.exists) return null;
    return AppNotification.fromMap(doc.data()!, doc.id);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';

class NotificationService {
  FirebaseFirestore? get _firestore =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  Stream<List<AppNotification>> watchNotifications(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) {
    final firestore = _firestore;
    if (firestore == null) return Stream.value([]);
    Query<Map<String, dynamic>> query =
        firestore.collection(FirestoreCollections.notifications);
    if (includeRoleBroadcasts) {
      // Admins see their own notifications plus any alerts broadcast to the
      // admin role (e.g. "new alumni message").
      query = query.where(Filter.or(
        Filter('userId', isEqualTo: userId),
        Filter('recipientRole', isEqualTo: 'admin'),
      ));
    } else {
      query = query.where('userId', isEqualTo: userId);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<int> getUnreadCount(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return 0;
    Query<Map<String, dynamic>> query =
        firestore.collection(FirestoreCollections.notifications);
    if (includeRoleBroadcasts) {
      query = query.where(Filter.or(
        Filter('userId', isEqualTo: userId),
        Filter('recipientRole', isEqualTo: 'admin'),
      ));
    } else {
      query = query.where('userId', isEqualTo: userId);
    }
    final snapshot = await query.where('isRead', isEqualTo: false).count().get();
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

  Future<void> markAllAsRead(
    String userId, {
    bool includeRoleBroadcasts = false,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    var docs = <DocumentSnapshot<Map<String, dynamic>>>[];
    final collection = firestore.collection(FirestoreCollections.notifications);

    final mine = await collection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    docs.addAll(mine.docs);

    if (includeRoleBroadcasts) {
      final broadcasts = await collection
          .where('recipientRole', isEqualTo: 'admin')
          .where('isRead', isEqualTo: false)
          .get();
      docs.addAll(broadcasts.docs);
    }

    if (docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in docs) {
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

  /// Sends a bell alert to every alumni user — used when new public content
  /// (announcements, events, jobs) is published by staff.
  Future<void> notifyAllAlumni({
    required NotificationType type,
    required String title,
    String description = '',
    NotificationPriority priority = NotificationPriority.medium,
    String? link,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final alumni = await firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: UserRole.alumni.name)
        .get();
    if (alumni.docs.isEmpty) return;

    final batch = firestore.batch();
    final now = DateTime.now();
    for (final doc in alumni.docs) {
      if (doc.data()['disabled'] == true) continue;
      final notification = AppNotification(
        id: '',
        userId: doc.id,
        type: type,
        title: title,
        description: description,
        priority: priority,
        createdAt: now,
        link: link,
      );
      batch.set(
        firestore.collection(FirestoreCollections.notifications).doc(),
        notification.toMap(),
      );
    }
    await batch.commit();
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

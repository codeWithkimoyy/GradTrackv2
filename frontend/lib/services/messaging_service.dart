import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class MessagingService {
  FirebaseFirestore? get _firestore =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>>? get _messages =>
      _firestore?.collection(FirestoreCollections.messages);

  CollectionReference<Map<String, dynamic>>? get _conversations =>
      _firestore?.collection(FirestoreCollections.conversations);

  /// Live stream of messages for a specific conversation, ordered chronologically.
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    final col = _messages;
    if (col == null) return Stream.value([]);
    return col
        .where('conversationId', isEqualTo: conversationId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(ChatMessage.fromDoc).toList();
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  /// Live stream of all conversations for Staff / Admin view.
  Stream<List<ChatConversation>> watchConversations() {
    final col = _conversations;
    if (col == null) return Stream.value([]);
    return col.snapshots().map((snapshot) {
      final list = snapshot.docs.map(ChatConversation.fromDoc).toList();
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    });
  }

  /// Live stream of the specific conversation for an alumni.
  Stream<ChatConversation?> watchAlumniConversation(String alumniId) {
    final col = _conversations;
    if (col == null) return Stream.value(null);
    final convId = 'conv_$alumniId';
    return col.doc(convId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatConversation.fromDoc(doc);
    });
  }

  /// Sends a message from an alumni to admin or from an admin to alumni.
  Future<void> sendMessage({
    required String alumniId,
    required String alumniName,
    required String alumniEmail,
    String? alumniCourse,
    required UserModel currentUser,
    required String text,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final conversationId = 'conv_$alumniId';
    final now = DateTime.now();
    final isAdmin = currentUser.role == UserRole.admin;

    // 1. Save message to 'messages' collection
    final messageRef = firestore.collection(FirestoreCollections.messages).doc();
    final message = ChatMessage(
      id: messageRef.id,
      conversationId: conversationId,
      senderId: currentUser.uid,
      senderName: currentUser.fullName,
      senderRole: currentUser.role.name,
      text: trimmed,
      timestamp: now,
      isRead: false,
    );

    await messageRef.set({
      ...message.toMap(),
      'timestamp': FieldValue.serverTimestamp(),
      'userId': currentUser.uid,
      'participantIds': [alumniId, 'admin', if (isAdmin) currentUser.uid],
      'recipientId': isAdmin ? alumniId : 'admin',
    });

    // 2. Upsert conversation header
    final convRef =
        firestore.collection(FirestoreCollections.conversations).doc(conversationId);

    final convData = <String, dynamic>{
      'alumniId': alumniId,
      'alumniName': alumniName,
      'alumniEmail': alumniEmail,
      'alumniCourse': alumniCourse,
      'participantIds': [alumniId, 'admin', if (isAdmin) currentUser.uid],
      'lastMessage': trimmed,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': currentUser.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (isAdmin) {
      // Admin sent message: reset admin unread, increment alumni unread
      convData['unreadCountForAdmin'] = 0;
      convData['unreadCountForAlumni'] = FieldValue.increment(1);
    } else {
      // Alumni sent message: reset alumni unread, increment admin unread
      convData['unreadCountForAlumni'] = 0;
      convData['unreadCountForAdmin'] = FieldValue.increment(1);
    }

    await convRef.set(convData, SetOptions(merge: true));

    // Raise an in-app notification so admins are alerted on the bell when an
    // alumni sends a message. Always best-effort: a failed alert must never
    // turn a successfully sent message into a failure for the alumni.
    if (!isAdmin) {
      try {
        await firestore
            .collection(FirestoreCollections.notifications)
            .add({
          'userId': '',
          'recipientRole': 'admin',
          'type': 'system',
          'title': 'New message from $alumniName',
          'description': trimmed,
          'priority': 'medium',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'link': '/admin/messages',
        });
} catch (e) {
          debugPrint('sendMessage: admin alert notification failed: $e');
        }
    }
  }

  /// Marks unread messages as read for this conversation.
  Future<void> markConversationAsRead(
    String conversationId, {
    required bool isAdmin,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final convRef = firestore
          .collection(FirestoreCollections.conversations)
          .doc(conversationId);
      if (isAdmin) {
        await convRef.update({'unreadCountForAdmin': 0});
      } else {
        await convRef.update({'unreadCountForAlumni': 0});
      }
    } catch (_) {}
  }
}

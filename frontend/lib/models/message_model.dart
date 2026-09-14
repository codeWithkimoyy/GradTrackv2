import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return DateTime.now();
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      conversationId: data['conversationId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'User',
      senderRole: data['senderRole']?.toString() ?? 'alumni',
      text: data['text']?.toString() ?? '',
      timestamp: _parseDate(data['timestamp']),
      isRead: data['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
        'isRead': isRead,
      };
}

class ChatConversation {
  final String id;
  final String alumniId;
  final String alumniName;
  final String alumniEmail;
  final String? alumniCourse;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final int unreadCountForAdmin;
  final int unreadCountForAlumni;
  final DateTime createdAt;

  const ChatConversation({
    required this.id,
    required this.alumniId,
    required this.alumniName,
    required this.alumniEmail,
    this.alumniCourse,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    this.unreadCountForAdmin = 0,
    this.unreadCountForAlumni = 0,
    required this.createdAt,
  });

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return DateTime.now();
  }

  factory ChatConversation.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final pIds = (data['participantIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ChatConversation(
      id: doc.id,
      alumniId: data['alumniId']?.toString() ?? '',
      alumniName: data['alumniName']?.toString() ?? 'Alumni',
      alumniEmail: data['alumniEmail']?.toString() ?? '',
      alumniCourse: data['alumniCourse']?.toString(),
      participantIds: pIds,
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageTime: _parseDate(data['lastMessageTime']),
      lastSenderId: data['lastSenderId']?.toString() ?? '',
      unreadCountForAdmin: (data['unreadCountForAdmin'] as num?)?.toInt() ?? 0,
      unreadCountForAlumni: (data['unreadCountForAlumni'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'alumniId': alumniId,
        'alumniName': alumniName,
        'alumniEmail': alumniEmail,
        'alumniCourse': alumniCourse,
        'participantIds': participantIds,
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromDate(lastMessageTime),
        'lastSenderId': lastSenderId,
        'unreadCountForAdmin': unreadCountForAdmin,
        'unreadCountForAlumni': unreadCountForAlumni,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

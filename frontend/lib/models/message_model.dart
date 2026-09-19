import 'user_model.dart' show parseApiDate;

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
  });

  static DateTime _parseDate(dynamic val) {
    return parseApiDate(val) ?? DateTime.now();
  }

  factory ChatMessage.fromJson(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      conversationId: data['conversationId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      senderName: data['senderName']?.toString() ?? 'User',
      senderRole: data['senderRole']?.toString() ?? 'alumni',
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
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
        'imageUrl': imageUrl,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasVisibleText => text.isNotEmpty && text != '📷 Photo';
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
    return parseApiDate(val) ?? DateTime.now();
  }

  factory ChatConversation.fromJson(Map<String, dynamic> data, String id) {
    final pIds = (data['participantIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return ChatConversation(
      id: id,
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
        'lastMessageTime': lastMessageTime.toIso8601String(),
        'lastSenderId': lastSenderId,
        'unreadCountForAdmin': unreadCountForAdmin,
        'unreadCountForAlumni': unreadCountForAlumni,
        'createdAt': createdAt.toIso8601String(),
      };
}

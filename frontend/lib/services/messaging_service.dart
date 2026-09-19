import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../routes/app_router.dart';
import 'api_client.dart';

class MessagingService {
  MessagingService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const Duration pollInterval = Duration(seconds: 15);

  /// Messages for a specific conversation, ordered chronologically.
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _api.poll(
      () => fetchMessages(conversationId),
      interval: pollInterval,
    );
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final raw = await _api.get('/api/conversations/$conversationId/messages');
    final list = (raw as List)
        .cast<Map<String, dynamic>>()
        .map((m) => ChatMessage.fromJson(m, m['id']?.toString() ?? ''))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// All conversations for Staff / Admin view.
  Stream<List<ChatConversation>> watchConversations() {
    return _api.poll(fetchConversations, interval: pollInterval);
  }

  Future<List<ChatConversation>> fetchConversations() async {
    final raw = await _api.get('/api/conversations');
    final list = (raw as List)
        .cast<Map<String, dynamic>>()
        .map((m) => ChatConversation.fromJson(m, m['id']?.toString() ?? ''))
        .toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return list;
  }

  /// The specific conversation for an alumni.
  Stream<ChatConversation?> watchAlumniConversation(String alumniId) {
    return _api.poll(
      () => fetchAlumniConversation(alumniId),
      interval: pollInterval,
    );
  }

  Future<ChatConversation?> fetchAlumniConversation(String alumniId) async {
    try {
      final raw = await _api.get('/api/conversations/conv_$alumniId');
      if (raw == null) return null;
      final map = Map<String, dynamic>.from(raw);
      return ChatConversation.fromJson(map, map['id']?.toString() ?? '');
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Sends a message from an alumni to admin or from an admin to alumni.
  /// The backend upserts the conversation header and raises the bell alert.
  Future<void> sendMessage({
    required String alumniId,
    required String alumniName,
    required String alumniEmail,
    String? alumniCourse,
    required UserModel currentUser,
    required String text,
    String? imageUrl,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (imageUrl == null || imageUrl.isEmpty)) return;

    final conversationId = 'conv_$alumniId';
    try {
      await _api.post('/api/conversations/$conversationId/messages', body: {
        'text': trimmed,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'alumniId': alumniId,
        'alumniName': alumniName,
        'alumniEmail': alumniEmail,
        if (alumniCourse != null) 'alumniCourse': alumniCourse,
        'link': currentUser.role == UserRole.admin
            ? AppRoutes.adminMessages
            : AppRoutes.alumniMessages,
      });
    } catch (e) {
      debugPrint('sendMessage failed: $e');
      rethrow;
    }
  }

  /// Marks unread messages as read for this conversation.
  Future<void> markConversationAsRead(
    String conversationId, {
    required bool isAdmin,
  }) async {
    try {
      await _api.patch('/api/conversations/$conversationId/read',
          body: {'isAdmin': isAdmin});
    } catch (_) {}
  }
}

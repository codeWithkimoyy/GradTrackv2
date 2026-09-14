import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/messaging_service.dart';
import 'auth_providers.dart';

final messagingServiceProvider = Provider<MessagingService>(
    (ref) => MessagingService(api: ref.watch(apiClientProvider)));

/// Live messages stream for a specific conversation ID.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  final service = ref.watch(messagingServiceProvider);
  return service.watchMessages(conversationId);
});

/// Live list of all conversations (for Admin / Staff).
final adminConversationsProvider =
    StreamProvider<List<ChatConversation>>((ref) {
  final service = ref.watch(messagingServiceProvider);
  return service.watchConversations();
});

/// Live conversation for an individual alumni.
final alumniConversationProvider =
    StreamProvider.family<ChatConversation?, String>((ref, alumniId) {
  final service = ref.watch(messagingServiceProvider);
  return service.watchAlumniConversation(alumniId);
});

/// Total unread messages for Admin across all alumni conversations.
final unreadAdminMessagesCountProvider = Provider<int>((ref) {
  final async = ref.watch(adminConversationsProvider);
  return async.valueOrNull?.fold<int>(
        0,
        (sum, conv) => sum + conv.unreadCountForAdmin,
      ) ??
      0;
});

/// Unread messages for a specific alumni.
final unreadAlumniMessagesCountProvider =
    Provider.family<int, String>((ref, alumniId) {
  final async = ref.watch(alumniConversationProvider(alumniId));
  return async.valueOrNull?.unreadCountForAlumni ?? 0;
});

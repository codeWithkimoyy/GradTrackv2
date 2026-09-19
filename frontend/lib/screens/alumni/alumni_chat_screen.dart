import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/document_providers.dart';
import '../../providers/messaging_providers.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/chat_message_image.dart';

class AlumniChatScreen extends ConsumerStatefulWidget {
  const AlumniChatScreen({super.key});

  @override
  ConsumerState<AlumniChatScreen> createState() => _AlumniChatScreenState();
}

class _AlumniChatScreenState extends ConsumerState<AlumniChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProfileProvider).valueOrNull;
      if (user != null) {
        ref.read(messagingServiceProvider).markConversationAsRead(
              'conv_${user.alumniId ?? user.uid}',
              isAdmin: false,
            );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(UserModel user) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref.read(messagingServiceProvider).sendMessage(
            alumniId: user.alumniId ?? user.uid,
            alumniName: user.fullName,
            alumniEmail: user.email,
            alumniCourse: user.course,
            currentUser: user,
            text: text,
          );
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        showError(context, 'Failed to send message: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage(UserModel user) async {
    if (_isSending) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _isSending = true);
      try {
        final bytes = await picked.readAsBytes();
        final uploaded =
            await ref.read(storageServiceProvider).uploadChatImage(
                  fileName: picked.name,
                  bytes: bytes,
                  onProgress: (_) {},
                );
        await ref.read(messagingServiceProvider).sendMessage(
              alumniId: user.alumniId ?? user.uid,
              alumniName: user.fullName,
              alumniEmail: user.email,
              alumniCourse: user.course,
              currentUser: user,
              text: _textController.text.trim(),
              imageUrl: uploaded.url,
            );
        _textController.clear();
        Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
      } catch (e) {
        if (mounted) {
          showError(context, 'Failed to send photo: $e');
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Could not pick photo: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProfileProvider).valueOrNull;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final conversationId = 'conv_${user.alumniId ?? user.uid}';
    final messagesAsync = ref.watch(messagesStreamProvider(conversationId));

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 1,
        titleSpacing: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryBlue, width: 1.5),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: AppColors.primaryBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'University Admin Support',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.primaryNavy,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Direct Messaging Channel',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Informational Notice Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.12 : 0.06),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messages sent here are received directly by BISU GradTrack administrators.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 34,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Have questions about verification, records, surveys, or opportunities? Type a message below to contact the admin team.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(messagingServiceProvider).markConversationAsRead(
                        conversationId,
                        isAdmin: false,
                      );
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == user.uid;

                    return _ChatMessageBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error loading messages: $err'),
                ),
              ),
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLightAlt,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.image_outlined, size: 20),
                      color: isDark ? Colors.white70 : AppColors.primaryNavy,
                      onPressed:
                          _isSending ? null : () => _sendImage(user),
                      tooltip: 'Send photo',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLightAlt,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        minLines: 1,
                        maxLines: 4,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your message to Admin...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : AppColors.textSecondary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(user),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _isSending ? null : () => _sendMessage(user),
                      tooltip: 'Send',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleBg = isMe
        ? AppColors.primaryBlue
        : (isDark ? AppColors.surfaceDarkAlt : const Color(0xFFE2E8F0));

    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : AppColors.primaryNavy);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.tealLight : AppColors.tealDeep)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    message.senderRole.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.tealLight
                          : AppColors.tealDeep,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                isMe ? 'You' : message.senderName,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat.jm().format(message.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: message.hasImage && !message.hasVisibleText ? 4 : 16,
              vertical: message.hasImage && !message.hasVisibleText ? 4 : 12,
            ),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (message.hasImage)
                  ChatMessageImage(imageUrl: message.imageUrl!),
                if (message.hasVisibleText) ...[
                  if (message.hasImage) const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: textColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/messaging_providers.dart';
import '../../utils/app_snack_bar.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/chat_message_image.dart';

class AdminMessagesScreen extends ConsumerStatefulWidget {
  final String? initialAlumniId;
  final String? initialAlumniName;
  final String? initialAlumniEmail;
  final String? initialAlumniCourse;

  const AdminMessagesScreen({
    super.key,
    this.initialAlumniId,
    this.initialAlumniName,
    this.initialAlumniEmail,
    this.initialAlumniCourse,
  });

  @override
  ConsumerState<AdminMessagesScreen> createState() =>
      _AdminMessagesScreenState();
}

class _AdminMessagesScreenState extends ConsumerState<AdminMessagesScreen> {
  String? _selectedAlumniId;
  String? _selectedAlumniName;
  String? _selectedAlumniEmail;
  String? _selectedAlumniCourse;

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _selectedAlumniId = widget.initialAlumniId;
    _selectedAlumniName = widget.initialAlumniName;
    _selectedAlumniEmail = widget.initialAlumniEmail;
    _selectedAlumniCourse = widget.initialAlumniCourse;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
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

  Future<void> _sendReply(UserModel admin) async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending || _selectedAlumniId == null) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref.read(messagingServiceProvider).sendMessage(
            alumniId: _selectedAlumniId!,
            alumniName: _selectedAlumniName ?? 'Alumni',
            alumniEmail: _selectedAlumniEmail ?? '',
            alumniCourse: _selectedAlumniCourse,
            currentUser: admin,
            text: text,
          );
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        showError(context, 'Failed to send reply: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final admin = ref.watch(currentUserProfileProvider).valueOrNull;
    final conversationsAsync = ref.watch(adminConversationsProvider);
    final isWide = MediaQuery.of(context).size.width >= 768;

    if (admin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        elevation: 1,
        title: Text(
          'Alumni Support & Inquiries',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.primaryNavy,
          ),
          onPressed: () => popOrGoHome(context),
        ),
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          final query = _searchController.text.trim().toLowerCase();
          final filtered = conversations.where((c) {
            if (query.isEmpty) return true;
            return c.alumniName.toLowerCase().contains(query) ||
                c.alumniEmail.toLowerCase().contains(query) ||
                (c.alumniCourse?.toLowerCase().contains(query) ?? false);
          }).toList();

          if (isWide) {
            // Split View for Desktop / Tablet
            return Row(
              children: [
                SizedBox(
                  width: 340,
                  child: _buildConversationList(
                    filtered,
                    isDark,
                    onSelect: (conv) {
                      setState(() {
                        _selectedAlumniId = conv.alumniId;
                        _selectedAlumniName = conv.alumniName;
                        _selectedAlumniEmail = conv.alumniEmail;
                        _selectedAlumniCourse = conv.alumniCourse;
                      });
                      ref.read(messagingServiceProvider).markConversationAsRead(
                            conv.id,
                            isAdmin: true,
                          );
                    },
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                Expanded(
                  child: _selectedAlumniId == null
                      ? _buildNoConversationSelected(isDark)
                      : _buildChatPane(admin, isDark),
                ),
              ],
            );
          } else {
            // Mobile View: If selected, show chat pane with back button
            if (_selectedAlumniId != null) {
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    color: isDark ? AppColors.cardDark : Colors.white,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          onPressed: () =>
                              setState(() => _selectedAlumniId = null),
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryBlue,
                          child: Text(
                            (_selectedAlumniName ?? 'A').substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedAlumniName ?? 'Alumni',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                _selectedAlumniCourse ?? _selectedAlumniEmail ?? '',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildChatPane(admin, isDark)),
                ],
              );
            }

            return _buildConversationList(
              filtered,
              isDark,
              onSelect: (conv) {
                setState(() {
                  _selectedAlumniId = conv.alumniId;
                  _selectedAlumniName = conv.alumniName;
                  _selectedAlumniEmail = conv.alumniEmail;
                  _selectedAlumniCourse = conv.alumniCourse;
                });
                ref.read(messagingServiceProvider).markConversationAsRead(
                      conv.id,
                      isAdmin: true,
                    );
              },
            );
          }
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) => Center(child: Text('Error loading messages: $e')),
      ),
    );
  }

  Widget _buildConversationList(
    List<ChatConversation> list,
    bool isDark, {
    required ValueChanged<ChatConversation> onSelect,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.poppins(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search alumni or program...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
              filled: true,
              fillColor: isDark ? AppColors.cardDark : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
          ),
        ),
        if (list.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.forum_outlined,
                        size: 40, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(
                      'No alumni inquiries yet',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              itemBuilder: (context, index) {
                final conv = list[index];
                final isSelected = conv.alumniId == _selectedAlumniId;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  onTap: () => onSelect(conv),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryBlue,
                    child: Text(
                      conv.alumniName.isNotEmpty
                          ? conv.alumniName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    conv.alumniName,
                    style: GoogleFonts.poppins(
                      fontWeight: conv.unreadCountForAdmin > 0
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    conv.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: conv.unreadCountForAdmin > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: conv.unreadCountForAdmin > 0
                          ? (isDark ? Colors.white : AppColors.primaryNavy)
                          : Colors.grey,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat.jm().format(conv.lastMessageTime),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      if (conv.unreadCountForAdmin > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${conv.unreadCountForAdmin}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildNoConversationSelected(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select an alumni inquiry',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Click on any conversation from the list to view and reply.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPane(UserModel admin, bool isDark) {
    final conversationId = 'conv_$_selectedAlumniId';
    final messagesAsync = ref.watch(messagesStreamProvider(conversationId));

    return Column(
      children: [
        // Alumni Info Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryBlue,
                child: Text(
                  (_selectedAlumniName ?? 'A')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedAlumniName ?? 'Alumni',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      '${_selectedAlumniCourse ?? 'Program not set'} · ${_selectedAlumniEmail ?? ''}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: messagesAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(
                  child: Text('No messages in this conversation.'),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(messagingServiceProvider).markConversationAsRead(
                      conversationId,
                      isAdmin: true,
                    );
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == admin.uid ||
                      msg.senderRole == 'admin' ||
                      msg.senderRole == 'coordinator';

                  return _AdminChatMessageBubble(message: msg, isMe: isMe);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Reply Input
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
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLightAlt,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      style: GoogleFonts.poppins(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Reply to ${_selectedAlumniName ?? 'alumni'}...',
                        hintStyle: GoogleFonts.poppins(fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendReply(admin),
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
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                    onPressed: _isSending ? null : () => _sendReply(admin),
                    tooltip: 'Send Reply',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _AdminChatMessageBubble({
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
              Text(
                isMe ? 'You (Admin)' : message.senderName,
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
              maxWidth: MediaQuery.of(context).size.width * 0.70,
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../constants/app_constants.dart';
import '../models/notification_model.dart';
import '../providers/audit_log_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/stats_providers.dart';
import '../utils/app_snack_bar.dart';
import 'skeleton_loader.dart';

/// Admin dashboard card listing users awaiting approval, with inline
/// approve / revoke actions. Streams live from [pendingApprovalsProvider].
class PendingApprovalsQueue extends ConsumerStatefulWidget {
  final VoidCallback onViewAll;

  const PendingApprovalsQueue({super.key, required this.onViewAll});

  @override
  ConsumerState<PendingApprovalsQueue> createState() =>
      _PendingApprovalsQueueState();
}

class _PendingApprovalsQueueState extends ConsumerState<PendingApprovalsQueue> {
  final Set<String> _busy = {};

  bool get _isBusy => _busy.isNotEmpty;

  Future<void> _setApproved(Map<String, dynamic> user, bool approved) async {
    final uid = user['id'] as String;
    setState(() => _busy.add(uid));
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set({
        'approved': approved,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final name = user['fullName']?.toString() ?? uid;
      if (mounted) {
        showAppSnackBar(
          context,
          approved ? '$name approved.' : 'Approval revoked for $name.',
          backgroundColor: AppColors.success,
        );
      }
      try {
        final service = ref.read(notificationServiceProvider);
        await service.createNotification(AppNotification(
          id: '',
          userId: uid,
          type: NotificationType.system,
          title: approved ? 'Account approved' : 'Account approval revoked',
          description: approved
              ? 'Your account has been approved. You can now explore the app.'
              : 'Your account approval was revoked by an administrator.',
          priority: NotificationPriority.medium,
          createdAt: DateTime.now(),
        ));
      } catch (_) {}
      try {
        await logAudit(
          ref,
          action: 'update',
          title: approved ? 'Account approved' : 'Account approval revoked',
          description:
              '$name ($uid) ${approved ? 'was approved from the dashboard queue' : 'had approval revoked from the dashboard queue'}.',
          targetId: uid,
          targetType: 'user',
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Update failed: $e',
            backgroundColor: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncQueue = ref.watch(pendingApprovalsProvider);
    final queue = asyncQueue.valueOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (queue == null || queue.isEmpty)
              ? AppColors.primaryBlue.withValues(alpha: .10)
              : AppColors.warning.withValues(alpha: .35),
          width: (queue == null || queue.isEmpty) ? 1 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B1F3A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded,
                  color: (queue?.isEmpty ?? true)
                      ? AppColors.primaryBlue
                      : AppColors.warning,
                  size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Pending Approvals',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (queue != null && queue.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${queue.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: widget.onViewAll,
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (asyncQueue.isLoading) ...[
            const SkeletonList(itemCount: 2, itemHeight: 62),
          ] else if (asyncQueue.hasError) ...[
            Text(
              'Could not load pending approvals.\n${asyncQueue.error}',
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ] else if (queue == null || queue.isEmpty) ...[
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'All caught up — no accounts are waiting for approval.',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ] else ...[
            for (final user in queue.take(5)) ...[
              _PendingUserTile(
                user: user,
                busy: _busy.contains(user['id'] as String),
                onApprove:
                    _isBusy ? null : () => _setApproved(user, true),
                onReject:
                    _isBusy ? null : () => _setApproved(user, false),
              ),
              if (user != queue.last) const SizedBox(height: 8),
            ],
            if (queue.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '+${queue.length - 5} more waiting',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .55),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PendingUserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _PendingUserTile({
    required this.user,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = user['fullName']?.toString() ?? 'Unknown';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'guest';
    final createdAt = (user['createdAt'] as Timestamp?)?.toDate();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkAlt : AppColors.surfaceLightAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: .22),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.warning.withValues(alpha: .16),
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$email · ${role.toUpperCase()}'
                  '${createdAt != null ? ' · ${timeago.format(createdAt)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .55),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              tooltip: 'Approve',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.check_circle_rounded),
              color: AppColors.success,
              onPressed: onApprove,
            ),
            IconButton(
              tooltip: 'Revoke',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.block_rounded),
              color: AppColors.error,
              onPressed: onReject,
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
<<<<<<< HEAD
import 'package:go_router/go_router.dart';
=======
import 'package:google_fonts/google_fonts.dart';
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
import 'package:http/http.dart' as http;

import '../../constants/app_constants.dart';
import '../../dashboards/dashboard_components.dart'
    show DashboardMetric, DashboardMetricGrid;
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/audit_log_providers.dart';
import '../../providers/notification_providers.dart';
import '../../providers/role_providers.dart';
import '../../providers/stats_providers.dart';
import '../../utils/academic_year_utils.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/empty_state_widget.dart';

/// Staff user directory: browse, search, filter, verify, edit, disable,
/// delete and (admins) add users. UI buttons are role-aware; the Firestore
/// security rules enforce the same permissions server-side.
class UserManagementScreen extends ConsumerStatefulWidget {
  final String? roleFilter;
  final bool canVerify;
<<<<<<< HEAD
  final bool approvedOnly;
=======
  final bool initialPendingOnly;
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6

  const UserManagementScreen({
    super.key,
    this.roleFilter,
    this.canVerify = true,
<<<<<<< HEAD
    this.approvedOnly = false,
=======
    this.initialPendingOnly = false,
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
  });

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _query = '';
  String? _roleFilter;
  bool _pendingOnly = false;
  bool _approvedOnly = false;
  String? _batchFilter;

  /// Selected graduation batch ('All Batches' = null).
  String? _batchFilter;

  /// Sentinel label for alumni without a graduation batch.
  static const String unspecifiedBatch = 'Academic Year Not Specified';

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(FirestoreCollections.users);

  static String _normalizeSearch(String s) => s
      .toLowerCase()
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-');

  bool _matchesQuery(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final fields = [
      data['fullName'],
      data['email'],
      data['role'],
      data['course'],
      data['academicYearGraduated'],
      data['employmentStatus'],
    ];
    final haystack = fields
        .whereType<String>()
        .map(_normalizeSearch)
        .join(' ');
    return haystack.contains(_normalizeSearch(_query));
  }

  String _batchKey(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return graduationBatchKey(
      academicYearGraduated: data['academicYearGraduated']?.toString(),
      graduationYear: (data['graduationYear'] as num?)?.toInt(),
    );
  }

  @override
  void initState() {
    super.initState();
    _roleFilter = widget.roleFilter;
<<<<<<< HEAD
    _approvedOnly = widget.approvedOnly;
  }

  void _openEmployment(DocumentSnapshot<Map<String, dynamic>> doc) {
    context.push('/staff/users/employment?userId=${doc.id}');
=======
    _pendingOnly = widget.initialPendingOnly;
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
  }

  Future<void> _addUser() async {
    final result = await showDialog<_NewUser>(
      context: context,
      builder: (_) => const _AddUserDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final apiKey = dotenv.env['FIREBASE_API_KEY'] ?? '';
      final resp = await http.post(
        Uri.parse(
            'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': result.email,
          'password': result.password,
          'returnSecureToken': false,
        }),
      );
      if (resp.statusCode != 200) {
        throw Exception(_parseApiError(resp.body));
      }
      final localId = (jsonDecode(resp.body) as Map)['localId'] as String;

      await _users.doc(localId).set({
        'email': result.email,
        'fullName': result.fullName,
        'role': result.role.name,
        'isVerified': false,
        'emailVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showAppSnackBar(context, 'User created successfully.',
            backgroundColor: AppColors.success);
      }
      await logAudit(
        ref,
        action: 'create',
        title: 'User created',
        description:
            'Created ${result.fullName} (${result.email}) as ${result.role.label}.',
        targetId: localId,
        targetType: 'user',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Could not create user: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  String _parseApiError(String body) {
    try {
      final map = jsonDecode(body) as Map;
      return switch (map['error']?['message'] as String? ?? '') {
        'EMAIL_EXISTS' => 'An account already exists for this email.',
        'INVALID_EMAIL' => 'Please enter a valid email address.',
        'WEAK_PASSWORD' => 'Password should be at least 6 characters.',
        'EMAIL_NOT_FOUND' => 'Email address not found.',
        final m => m,
      };
    } catch (_) {
      return 'Unexpected error.';
    }
  }

  Future<void> _editUser(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final isAdmin = ref.read(isAdminProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(doc: doc, adminRoleEditing: isAdmin),
    );
    if (result == true && mounted) {
      showAppSnackBar(context, 'User updated.',
          backgroundColor: AppColors.success);
    }
    if (result == true) {
      await logAudit(
        ref,
        action: 'update',
        title: 'User profile edited',
        description:
            'Edited the profile of ${(doc.data()?['fullName']?.toString() ?? 'a user')} (${doc.data()?['email']?.toString() ?? doc.id}).',
        targetId: doc.id,
        targetType: 'user',
      );
    }
  }

  Future<void> _toggleVerified(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final newValue = data['isVerified'] != true;
    final uid = doc.id;
    try {
      await _users.doc(uid).update({'isVerified': newValue});
      final service = ref.read(notificationServiceProvider);
      await service.createNotification(AppNotification(
        id: '',
        userId: uid,
        type: NotificationType.system,
        title: newValue ? 'Profile verified' : 'Verification revoked',
        description: newValue
            ? 'Your graduate record has been verified by an administrator.'
            : 'Your graduate record verification was revoked.',
        priority: newValue ? NotificationPriority.medium : NotificationPriority.high,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Update failed: $e',
            backgroundColor: AppColors.error);
      }
      return;
    }
    if (mounted) {
      showAppSnackBar(
          context, newValue ? 'Alumni verified.' : 'Verification revoked.',
          backgroundColor: AppColors.success);
    }
    await logAudit(
      ref,
      action: 'update',
      title: newValue ? 'Alumni verified' : 'Verification revoked',
      description: '${data['fullName']?.toString() ?? uid} ($uid) was ${newValue ? 'marked as a verified graduate' : 'unmarked (verification revoked)'}.',
      targetId: uid,
      targetType: 'user',
    );
  }

  Future<void> _toggleApproved(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final newValue = data['approved'] != true;
    final uid = doc.id;
    try {
      await _users.doc(uid).set({
        'approved': newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Update failed: $e',
            backgroundColor: AppColors.error);
      }
      return;
    }
    if (mounted) {
      showAppSnackBar(context,
          newValue ? 'User approved successfully.' : 'Approval revoked.',
          backgroundColor: AppColors.success);
    }
    try {
      final service = ref.read(notificationServiceProvider);
      await service.createNotification(AppNotification(
        id: '',
        userId: uid,
        type: NotificationType.system,
        title: newValue ? 'Account approved' : 'Account approval revoked',
        description: newValue
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
        title: newValue ? 'Account approved' : 'Account approval revoked',
        description:
            '${data['fullName']?.toString() ?? uid} ($uid) ${newValue ? 'was approved' : 'had approval revoked'}.',
        targetId: uid,
        targetType: 'user',
      );
    } catch (_) {}
  }



  Future<void> _deleteUser(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: const Text(
            'This removes the user record from Firebase. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final data = doc.data() ?? {};
    try {
      await _users.doc(doc.id).delete();
      if (mounted) {
        showAppSnackBar(context, 'User deleted.',
            backgroundColor: AppColors.success);
      }
      await logAudit(
        ref,
        action: 'delete',
        title: 'User deleted',
        description: 'Deleted user ${data['fullName']?.toString() ?? doc.id} (${data['email']?.toString() ?? ''}).',
        targetId: doc.id,
        targetType: 'user',
      );
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  Widget _buildAlumniSections(
    List<DocumentSnapshot<Map<String, dynamic>>> filtered,
    List<String> sortedBatches,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = ref.watch(isAdminProvider);
    final sorted = [...filtered]..sort((a, b) {
        final an = (a.data()?['fullName']?.toString() ?? '').toLowerCase();
        final bn = (b.data()?['fullName']?.toString() ?? '').toLowerCase();
        return an.compareTo(bn);
      });

    final groups = <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
    for (final doc in sorted) {
      final key = _batchKey(doc);
      groups.putIfAbsent(key, () => []).add(doc);
    }

    if (groups.isEmpty) return _alumniEmptyState(isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final batch in sortedBatches.where((b) => groups.containsKey(b)))
          ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_outlined,
                      size: 19, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        graduationBatchInfo(batch).$2,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : AppColors.primaryNavy,
                        ),
                      ),
                      Text(
                        '${groups[batch]!.length} Alumni',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...groups[batch]!.map((doc) => _UserCard(
                  doc: doc,
                  isAdmin: isAdmin,
                  canVerify: widget.canVerify,
                  onEdit: () => _editUser(doc),
                  onVerify:
                      widget.canVerify ? () => _toggleVerified(doc) : null,
                  onToggleApproved:
                      isAdmin ? () => _toggleApproved(doc) : null,
                  onViewEmployment:
                      isAdmin ? () => _openEmployment(doc) : null,
                  onDelete: isAdmin ? () => _deleteUser(doc) : null,
                )),
            const SizedBox(height: AppSpacing.md),
          ],
      ],
    );
  }

  Widget _alumniEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_outlined,
                size: 42, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 18),
          Text(
            _batchFilter == null
                ? 'No alumni found'
                : 'No alumni found for this graduation batch.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust your search or graduation batch filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final stats = ref.watch(staffStatsProvider).valueOrNull;

    final userQuery = isAdmin
        ? _users.snapshots()
        : _users.where('role', isEqualTo: 'alumni').snapshots();

    final chips = <String, int>{
      'all': stats?.totalUsers ?? 0,
      'alumni': stats?.alumni ?? 0,
      if (isAdmin) 'admin': stats?.admins ?? 0,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _addUser,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add User'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: userQuery,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    'You do not have permission to manage users.\n\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!.docs;
<<<<<<< HEAD
          final scoped = all.where((doc) {
=======

          // ---- Filtering (pending / role / search) ----
          String searchHaystack(Map<String, dynamic> data) => [
                data['fullName'],
                data['email'],
                data['role'],
                data['course'],
                data['academicYearGraduated'],
              ]
                  .whereType<String>()
                  .join(' ')
                  .toLowerCase()
                  .replaceAll('-', '–');

          final searchNeedle = _query.trim().toLowerCase().replaceAll('-', '–');

          final filtered = all.where((doc) {
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
            final data = doc.data();
            if (_pendingOnly && data['approved'] == true) {
              return false;
            }
            if (_approvedOnly && data['approved'] != true) {
              return false;
            }
            if (_roleFilter != null &&
                _roleFilter != 'all' &&
                data['role'] != _roleFilter) {
              return false;
            }
<<<<<<< HEAD
            return true;
          }).toList();

          final alumniScoped =
              scoped.where((d) => d.data()['role'] == 'alumni').toList();
          final adminScoped =
              scoped.where((d) => d.data()['role'] != 'alumni').toList();

          final batchCounts = <String, int>{};
          for (final doc in alumniScoped) {
            final key = _batchKey(doc);
            batchCounts[key] = (batchCounts[key] ?? 0) + 1;
          }
          final sortedBatches = batchCounts.keys.toList()
            ..sort((a, b) {
              final (aYear, _) = graduationBatchInfo(a);
              final (bYear, _) = graduationBatchInfo(b);
              if (aYear != null && bYear != null) return bYear.compareTo(aYear);
              if (aYear == null) return 1;
              if (bYear == null) return -1;
              return 0;
            });

          final alumniMatch = alumniScoped.where((doc) {
            final data = doc.data();
            if (_batchFilter != null && _batchKey(doc) != _batchFilter) {
              return false;
            }
            return _matchesQuery(data);
          }).toList();

          final adminMatch =
              adminScoped.where((doc) => _matchesQuery(doc.data())).toList();
=======
            if (searchNeedle.isNotEmpty &&
                !searchHaystack(data).contains(searchNeedle)) {
              return false;
            }
            return true;
          }).toList();

          final isAlumniView =
              _roleFilter == null || _roleFilter == 'alumni';
          final alumniDocs = isAlumniView
              ? filtered
                  .where((d) => d.data()['role'] == 'alumni')
                  .toList()
              : <DocumentSnapshot<Map<String, dynamic>>>[];
          final otherDocs = isAlumniView
              ? filtered
                  .where((d) => d.data()['role'] != 'alumni')
                  .toList()
              : filtered;

          // ---- Alumni batch grouping ----
          // Key: academic year string, or null for "Academic Year Not
          // Specified" (always rendered last).
          final groups = <String?, List<DocumentSnapshot<Map<String, dynamic>>>>{};
          for (final doc in alumniDocs) {
            // Safe read: tolerate non-string stored values (e.g. legacy
            // numeric years) via toString, mirroring the rest of the screen.
            final year = doc.data()?['academicYearGraduated']?.toString();
            final key = (year == null || year.isEmpty) ? null : year;
            groups.putIfAbsent(key, () => []).add(doc);
          }

          // Sort members alphabetically inside every group.
          for (final entry in groups.entries) {
            entry.value.sort((a, b) =>
                (a.data()?['fullName']?.toString() ?? '')
                    .toLowerCase()
                    .compareTo((b.data()?['fullName']?.toString() ?? '')
                        .toLowerCase()));
          }

          // Group keys: batches newest-first, unspecified always last.
          final batchKeys = groups.keys
              .whereType<String>()
              .toList()
            ..sort((a, b) => b.compareTo(a));
          final hasUnspecified = groups.containsKey(null);

          // ---- Batch filter application ----
          final visibleBatchKeys = _batchFilter == null
              ? batchKeys
              : (groups.containsKey(_batchFilter)
                  ? [_batchFilter!]
                  : <String>[]);
          final visibleUnspecified =
              _batchFilter == null || _batchFilter == unspecifiedBatch
                  ? hasUnspecified
                  : false;

          final totalAlumni = alumniDocs.length;
          final selectedBatchCount = _batchFilter == null
              ? null
              : (_batchFilter == unspecifiedBatch
                  ? (groups[null]?.length ?? 0)
                  : (groups[_batchFilter]?.length ?? 0));

          final alumniListEmpty = isAlumniView &&
              visibleBatchKeys.isEmpty &&
              !visibleUnspecified &&
              otherDocs.isEmpty;

          final availableBatches = <String>[...batchKeys];
          if (hasUnspecified) availableBatches.add(unspecifiedBatch);
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextField(
                decoration: InputDecoration(
<<<<<<< HEAD
                  hintText:
                      'Search by name, academic year, course or employment...',
=======
                  hintText: 'Search name, email, course or academic year...',
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (isAdmin) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Pending approval'),
                          selected: _pendingOnly,
                          onSelected: (v) => setState(() {
                            _pendingOnly = v;
                            _approvedOnly = false;
                            if (v) _roleFilter = null;
                          }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Approved alumni'),
                          selected: _approvedOnly && !_pendingOnly,
                          onSelected: (v) => setState(() {
                            _approvedOnly = v;
                            _pendingOnly = false;
                            if (v) _roleFilter = 'alumni';
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    for (final entry in chips.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                              '${entry.key[0].toUpperCase()}${entry.key.substring(1)} (${entry.value})'),
                          selected: _roleFilter == entry.key && !_pendingOnly,
                          onSelected: (_) => setState(() {
                            _roleFilter = entry.key;
                            _pendingOnly = false;
                          }),
                        ),
                      ),
                    if (alumniScoped.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All Batches'),
                          selected: _batchFilter == null,
                          onSelected: (_) =>
                              setState(() => _batchFilter = null),
                        ),
                      ),
                      for (final batch in sortedBatches)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label:
                                Text(graduationBatchInfo(batch).$2),
                            selected: _batchFilter == batch,
                            onSelected: (_) =>
                                setState(() => _batchFilter = batch),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
<<<<<<< HEAD
              if (alumniScoped.isNotEmpty)
                _buildAlumniSections(alumniMatch, sortedBatches)
              else if (adminMatch.isEmpty)
                Text('0 users',
=======

              // ---- Alumni grouped by graduation batch ----
              if (isAlumniView) ...[
                DashboardMetricGrid(
                  metrics: [
                    DashboardMetric(
                      'Total Alumni',
                      '$totalAlumni',
                      Icons.school_outlined,
                      AppColors.primaryBlue,
                    ),
                    DashboardMetric(
                      _batchFilter == null
                          ? 'Selected Batch'
                          : _batchFilter == unspecifiedBatch
                              ? unspecifiedBatch
                              : 'Class of $_batchFilter',
                      selectedBatchCount == null
                          ? '—'
                          : '$selectedBatchCount',
                      Icons.calendar_month_outlined,
                      selectedBatchCount == null
                          ? AppColors.textMuted
                          : AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Batch filter chips
                if (availableBatches.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('All Batches'),
                            selected: _batchFilter == null,
                            onSelected: (_) =>
                                setState(() => _batchFilter = null),
                          ),
                        ),
                        for (final batch in availableBatches)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                  '$batch (${groups[batch == unspecifiedBatch ? null : batch]?.length ?? 0})'),
                              selected: _batchFilter == batch,
                              onSelected: (_) =>
                                  setState(() => _batchFilter = batch),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),

                if (alumniListEmpty)
                  const EmptyStateWidget(
                    icon: Icons.school_rounded,
                    title: 'No alumni found',
                    message:
                        'No alumni found for this graduation batch.',
                  )
                else ...[
                  for (final batchKey in visibleBatchKeys)
                    _BatchSection(
                      title: batchKey,
                      count: groups[batchKey]!.length,
                      docs: groups[batchKey]!,
                      isAdmin: isAdmin,
                      canVerify: widget.canVerify,
                      onEdit: _editUser,
                      onVerify: _toggleVerified,
                      onToggleApproved: _toggleApproved,
                      onDelete: _deleteUser,
                    ),
                  if (visibleUnspecified)
                    _BatchSection(
                      title: unspecifiedBatch,
                      count: groups[null]!.length,
                      docs: groups[null]!,
                      isAdmin: isAdmin,
                      canVerify: widget.canVerify,
                      onEdit: _editUser,
                      onVerify: _toggleVerified,
                      onToggleApproved: _toggleApproved,
                      onDelete: _deleteUser,
                    ),
                  if (visibleBatchKeys.isEmpty &&
                      !visibleUnspecified &&
                      _batchFilter != null)
                    const EmptyStateWidget(
                      icon: Icons.school_rounded,
                      title: 'No alumni found',
                      message:
                          'No alumni found for this graduation batch.',
                    ),
                ],

                if (otherDocs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _BatchSection(
                    title: 'Other Users',
                    count: otherDocs.length,
                    docs: otherDocs,
                    isAdmin: isAdmin,
                    canVerify: widget.canVerify,
                    onEdit: _editUser,
                    onVerify: _toggleVerified,
                    onToggleApproved: _toggleApproved,
                    onDelete: _deleteUser,
                    noun: 'Users',
                  ),
                ],
              ]

              // ---- Non-alumni role views keep the existing layout ----
              else if (MediaQuery.sizeOf(context).width >= 900 &&
                  filtered.isNotEmpty)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: PaginatedDataTable(
                    header: Text('${filtered.length} Users Registered'),
                    rowsPerPage: (filtered.length < 10) ? filtered.length : 10,
                    columns: const [
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Course / Batch')),
                      DataColumn(label: Text('Verification')),
                      DataColumn(label: Text('Actions')),
                    ],
                    source: _UserDataTableSource(
                      docs: filtered,
                      isAdmin: isAdmin,
                      canVerify: widget.canVerify,
                      onEdit: _editUser,
                      onVerify: _toggleVerified,
                      onToggleApproved: _toggleApproved,
                      onDelete: _deleteUser,
                    ),
                  ),
                )
              else ...[
                Text('${filtered.length} users',
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
                    style: Theme.of(context).textTheme.bodySmall),
              if (adminMatch.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                if (MediaQuery.sizeOf(context).width >= 900)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: PaginatedDataTable(
                      header: Text(
                          '${adminMatch.length} Admin${adminMatch.length == 1 ? '' : 's'}'),
                      rowsPerPage:
                          (adminMatch.length < 10) ? adminMatch.length : 10,
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Course / Batch')),
                        DataColumn(label: Text('Verification')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _UserDataTableSource(
                        docs: adminMatch,
                        isAdmin: isAdmin,
                        canVerify: widget.canVerify,
                        onEdit: _editUser,
                        onVerify: _toggleVerified,
                        onToggleApproved: _toggleApproved,
                        onViewEmployment: isAdmin ? _openEmployment : null,
                        onDelete: _deleteUser,
                      ),
                    ),
                  )
                else ...[
                  Text(
                      '${adminMatch.length} Administrator${adminMatch.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  ...adminMatch.map((doc) => _UserCard(
                        doc: doc,
                        isAdmin: isAdmin,
                        canVerify: widget.canVerify,
                        onEdit: () => _editUser(doc),
                        onVerify: widget.canVerify
                            ? () => _toggleVerified(doc)
                            : null,
                        onToggleApproved:
                            isAdmin ? () => _toggleApproved(doc) : null,
                        onViewEmployment:
                            isAdmin ? () => _openEmployment(doc) : null,
                        onDelete: isAdmin ? () => _deleteUser(doc) : null,
                      )),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// An always-expanded section of alumni sharing one graduation batch
/// (or the "Academic Year Not Specified" / "Other Users" catch-alls).
/// Reuses the existing [_UserCard] styling — no accordions.
class _BatchSection extends StatelessWidget {
  final String title;
  final int count;
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isAdmin;
  final bool canVerify;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onVerify;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onToggleApproved;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onDelete;

  /// Noun used in the header count, e.g. 'Alumni' or 'Users'. Defaults to
  /// the alumni label; the "Other Users" catch-all overrides it.
  final String noun;

  const _BatchSection({
    required this.title,
    required this.count,
    required this.docs,
    required this.isAdmin,
    required this.canVerify,
    required this.onEdit,
    required this.onVerify,
    required this.onToggleApproved,
    required this.onDelete,
    this.noun = 'Alumni',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(
            children: [
              Icon(
                title == _UserManagementScreenState.unspecifiedBatch
                    ? Icons.help_outline_rounded
                    : Icons.school_rounded,
                size: 17,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$title ($count ${_countNoun(count)})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...docs.map((doc) => _UserCard(
              doc: doc,
              isAdmin: isAdmin,
              canVerify: canVerify,
              onEdit: () => onEdit(doc),
              onVerify: canVerify ? () => onVerify(doc) : null,
              onToggleApproved: isAdmin ? () => onToggleApproved(doc) : null,
              onDelete: isAdmin ? () => onDelete(doc) : null,
            )),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  String _countNoun(int count) {
    if (noun == 'Alumni') return count == 1 ? 'Alumnus' : 'Alumni';
    return count == 1 ? 'User' : 'Users';
  }
}

class _UserDataTableSource extends DataTableSource {
  final List<DocumentSnapshot<Map<String, dynamic>>> docs;
  final bool isAdmin;
  final bool canVerify;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onEdit;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onVerify;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onToggleApproved;
  final void Function(DocumentSnapshot<Map<String, dynamic>>)? onViewEmployment;
  final void Function(DocumentSnapshot<Map<String, dynamic>>) onDelete;

  _UserDataTableSource({
    required this.docs,
    required this.isAdmin,
    required this.canVerify,
    required this.onEdit,
    required this.onVerify,
    required this.onToggleApproved,
    this.onViewEmployment,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= docs.length) return null;
    final doc = docs[index];
    final data = doc.data() ?? {};
    final name = data['fullName']?.toString() ?? 'Unknown';
    final email = data['email']?.toString() ?? '';
    final role = data['role']?.toString() ?? 'alumni';
    final course = data['course']?.toString() ?? '—';
    final year = data['graduationYear']?.toString() ?? '';
    final verified = data['isVerified'] == true;
    final approved = data['approved'] == true;

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        )),
        DataCell(Text(email)),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: role == 'admin'
                ? AppColors.error.withValues(alpha: 0.15)
                : AppColors.teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: role == 'admin'
                  ? AppColors.error
                  : AppColors.teal,
            ),
          ),
        )),
        DataCell(Text(year.isNotEmpty ? '$course ($year)' : course)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (verified)
              const Icon(Icons.verified_rounded, size: 16, color: AppColors.success)
            else
              const Icon(Icons.pending_outlined, size: 16, color: AppColors.warning),
            const SizedBox(width: 4),
            Text(verified ? 'Verified' : 'Pending', style: const TextStyle(fontSize: 12)),
          ],
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin && onViewEmployment != null)
              IconButton(
                icon: const Icon(Icons.badge_outlined, size: 18),
                tooltip: 'View employment',
                onPressed: () => onViewEmployment!(doc),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => onEdit(doc),
            ),
            if (canVerify)
              IconButton(
                icon: Icon(
                  verified ? Icons.verified_user : Icons.verified_user_outlined,
                  size: 18,
                  color: verified ? AppColors.success : null,
                ),
                tooltip: verified ? 'Revoke verification' : 'Verify alumni',
                onPressed: () => onVerify(doc),
              ),
            if (isAdmin)
              IconButton(
                icon: Icon(
                  approved ? Icons.check_circle : Icons.check_circle_outline,
                  size: 18,
                  color: approved ? AppColors.info : null,
                ),
                tooltip: approved ? 'Revoke approval' : 'Approve user',
                onPressed: () => onToggleApproved(doc),
              ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                tooltip: 'Delete',
                onPressed: () => onDelete(doc),
              ),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => docs.length;
  @override
  int get selectedRowCount => 0;
}

class _UserCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool isAdmin;
  final bool canVerify;
  final VoidCallback onEdit;
  final VoidCallback? onVerify;
  final VoidCallback? onToggleApproved;
  final VoidCallback? onViewEmployment;
  final VoidCallback? onDelete;

  const _UserCard({
    required this.doc,
    required this.isAdmin,
    required this.canVerify,
    required this.onEdit,
    this.onVerify,
    this.onToggleApproved,
    this.onViewEmployment,
    this.onDelete,
  });

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isEmpty ? '?' : name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() ?? {};
    final name = data['fullName']?.toString() ?? 'Unknown';
    final role = data['role']?.toString() ?? 'alumni';
    final verified = data['isVerified'] == true;
    final approved = data['approved'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              AppColors.primaryBlue.withValues(alpha: .12),
          child: Text(_initials(name),
              style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (!approved) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${data['email'] ?? ''}\n'
          '${role.toUpperCase()} · ${verified ? 'Verified' : 'Unverified'} · '
<<<<<<< HEAD
          '${data['course']?.toString() ?? 'No course'} · '
          '${EmploymentStatusX.fromString(data['employmentStatus']?.toString() ?? '').label}',
=======
          '${data['course']?.toString() ?? 'No course'}'
          '${data['academicYearGraduated'] != null ? ' · ${data['academicYearGraduated']}' : ''}',
>>>>>>> 912ab68eea4fd77971b7cda4789ea56cc9845bd6
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onToggleApproved != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: approved
                    ? 'Revoke approval'
                    : 'Approve user',
                color: approved ? AppColors.success : AppColors.warning,
                icon: Icon(approved
                    ? Icons.check_circle_rounded
                    : Icons.pending_actions_rounded, size: 20),
                onPressed: onToggleApproved,
              ),
            if (onVerify != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: verified ? 'Revoke verification' : 'Verify alumni',
                color: verified ? AppColors.success : null,
                icon: Icon(verified
                    ? Icons.verified_rounded
                    : Icons.verified_outlined, size: 20),
                onPressed: onVerify,
              ),
            if (onViewEmployment != null)
              IconButton(
                tooltip: 'View employment',
                icon: const Icon(Icons.badge_outlined),
                onPressed: onViewEmployment,
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              iconSize: 20,
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewUser {
  final String fullName;
  final String email;
  final String password;
  final UserRole role;

  const _NewUser(this.fullName, this.email, this.password, this.role);
}

class _AddUserDialog extends StatefulWidget {
  const _AddUserDialog();

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.alumni;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || !email.contains('@')) return;
    if (password.length < 6) return;
    Navigator.pop(
        context, _NewUser(name, email, password, _role));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Temporary password (min 6 characters)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final role in UserRole.values)
                  DropdownMenuItem(value: role, child: Text(role.label)),
              ],
              onChanged: (v) => setState(() => _role = v ?? UserRole.alumni),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool adminRoleEditing;

  const _EditUserDialog({
    required this.doc,
    required this.adminRoleEditing,
  });

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _name;
  late final TextEditingController _course;
  late final TextEditingController _gradYear;
  late String _role;
  late String _status;
  late bool _verified;
  late bool _approved;
  String? _academicYear;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() ?? {};
    _name = TextEditingController(text: data['fullName']?.toString() ?? '');
    _course = TextEditingController(text: data['course']?.toString() ?? '');
    _gradYear = TextEditingController(
        text: data['graduationYear']?.toString() ?? '');
    _role = data['role']?.toString() ?? 'alumni';
    _status = data['employmentStatus']?.toString() ?? 'unemployed';
    _verified = data['isVerified'] == true;
    _approved = data['approved'] == true;
    _academicYear = data['academicYearGraduated']?.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _course.dispose();
    _gradYear.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final changes = <String, dynamic>{
      'fullName': _name.text.trim(),
      'course': _course.text.trim().isEmpty ? null : _course.text.trim(),
      'graduationYear':
          int.tryParse(_gradYear.text.trim()),
      'academicYearGraduated':
          (_academicYear == null || _academicYear!.isEmpty) ? null : _academicYear,
      'employmentStatus': _status,
      'isVerified': _verified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (widget.adminRoleEditing) {
      changes['role'] = _role;
    }
    changes['approved'] = _approved;
    try {
      await widget.doc.reference.update(changes);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Save failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit User'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _course,
                decoration: const InputDecoration(labelText: 'Course')),
            const SizedBox(height: 12),
            TextFormField(
                controller: _gradYear,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Graduation year')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: AcademicYearUtils.isValid(_academicYear)
                  ? _academicYear
                  : null,
              decoration: const InputDecoration(
                labelText: 'Academic Year Graduated',
                hintText: 'Select Academic Year',
              ),
              hint: const Text('Select Academic Year'),
              items: [
                for (final year in AcademicYearUtils.options())
                  DropdownMenuItem(value: year, child: Text(year)),
                const DropdownMenuItem(
                  value: '',
                  child: Text('Not specified'),
                ),
              ],
              onChanged: (v) => setState(() => _academicYear = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Employment status'),
              items: [
                for (final s in EmploymentStatus.values)
                  DropdownMenuItem(value: s.name, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            if (widget.adminRoleEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final role in UserRole.values)
                    DropdownMenuItem(
                        value: role.name, child: Text(role.label)),
                ],
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Verified graduate'),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v),
            ),
            if (widget.adminRoleEditing)
              SwitchListTile(
                title: const Text('Account approved'),
                value: _approved,
                onChanged: (v) => setState(() => _approved = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save Changes')),
      ],
    );
  }
}
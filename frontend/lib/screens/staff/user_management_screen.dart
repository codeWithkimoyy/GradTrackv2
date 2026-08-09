import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_constants.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../providers/notification_providers.dart';
import '../../providers/role_providers.dart';
import '../../providers/stats_providers.dart';
import '../../utils/app_snack_bar.dart';

/// Staff user directory: browse, search, filter, verify, edit, disable,
/// delete and (admins) add users. UI buttons are role-aware; the Firestore
/// security rules enforce the same permissions server-side.
class UserManagementScreen extends ConsumerStatefulWidget {
  final String? roleFilter;
  final bool canVerify;

  const UserManagementScreen({super.key, this.roleFilter, this.canVerify = true});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _query = '';
  String? _roleFilter;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(FirestoreCollections.users);

  @override
  void initState() {
    super.initState();
    _roleFilter = widget.roleFilter;
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
            ? 'Your graduate record has been verified by the coordinator.'
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
  }

  Future<void> _toggleDisabled(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final newValue = data['disabled'] != true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newValue ? 'Disable account?' : 'Enable account?'),
        content: Text(newValue
            ? 'The user will be blocked from accessing their account.'
            : 'The user will regain access to their account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: newValue ? AppColors.error : AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: Text(newValue ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await _users.doc(doc.id).update({'disabled': newValue});
      if (mounted) {
        showAppSnackBar(context,
            newValue ? 'Account disabled.' : 'Account enabled.',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Update failed: $e',
            backgroundColor: AppColors.error);
      }
    }
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
    try {
      await _users.doc(doc.id).delete();
      if (mounted) {
        showAppSnackBar(context, 'User deleted.',
            backgroundColor: AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'Delete failed: $e',
            backgroundColor: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final stats = ref.watch(staffStatsProvider).valueOrNull;

    final userQuery = isAdmin
        ? _users.snapshots()
        : _users
            .where('role', whereIn: const ['alumni', 'guest'])
            .snapshots();

    final chips = <String, int>{
      'all': stats?.totalUsers ?? 0,
      'alumni': stats?.alumni ?? 0,
      'coordinator': stats?.coordinators ?? 0,
      if (isAdmin) 'admin': stats?.admins ?? 0,
      if (isAdmin) 'guest': stats?.guests ?? 0,
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
          final filtered = all.where((doc) {
            final data = doc.data();
            if (_roleFilter != null && data['role'] != _roleFilter) {
              return false;
            }
            if (_query.isNotEmpty) {
              final haystack = [
                data['fullName'],
                data['email'],
                data['role'],
              ].whereType<String>().join(' ').toLowerCase();
              if (!haystack.contains(_query.toLowerCase())) return false;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search name, email or role...',
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
                    for (final entry in chips.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                              '${entry.key[0].toUpperCase()}${entry.key.substring(1)} (${entry.value})'),
                          selected: _roleFilter == entry.key,
                          onSelected: (_) =>
                              setState(() => _roleFilter = entry.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${filtered.length} users',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              ...filtered.map((doc) => _UserCard(
                    doc: doc,
                    isAdmin: isAdmin,
                    canVerify: widget.canVerify,
                    onEdit: () => _editUser(doc),
                    onVerify: widget.canVerify
                        ? () => _toggleVerified(doc)
                        : null,
                    onToggleDisabled:
                        isAdmin ? () => _toggleDisabled(doc) : null,
                    onDelete: isAdmin ? () => _deleteUser(doc) : null,
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final bool isAdmin;
  final bool canVerify;
  final VoidCallback onEdit;
  final VoidCallback? onVerify;
  final VoidCallback? onToggleDisabled;
  final VoidCallback? onDelete;

  const _UserCard({
    required this.doc,
    required this.isAdmin,
    required this.canVerify,
    required this.onEdit,
    this.onVerify,
    this.onToggleDisabled,
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
    final role = data['role']?.toString() ?? 'guest';
    final verified = data['isVerified'] == true;
    final disabled = data['disabled'] == true;

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
            if (disabled) ...[
              const SizedBox(width: 6),
              const Chip(
                label: Text('Disabled', style: TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.error,
                labelStyle: TextStyle(color: Colors.white),
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${data['email'] ?? ''}\n'
          '${role.toUpperCase()} · ${verified ? 'Verified' : 'Unverified'} · '
          '${data['course']?.toString() ?? 'No course'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onVerify != null)
              IconButton(
                tooltip: verified ? 'Revoke verification' : 'Verify alumni',
                color: verified ? AppColors.success : null,
                icon: Icon(verified
                    ? Icons.verified_rounded
                    : Icons.verified_outlined),
                onPressed: onVerify,
              ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'disable':
                    onToggleDisabled?.call();
                  case 'delete':
                    onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                if (onToggleDisabled != null)
                  PopupMenuItem(
                    value: 'disable',
                    child: Text(disabled ? 'Enable' : 'Disable'),
                  ),
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
  late bool _disabled;

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
    _disabled = data['disabled'] == true;
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
      'employmentStatus': _status,
      'isVerified': _verified,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (widget.adminRoleEditing) {
      changes['role'] = _role;
    }
    if (widget.adminRoleEditing) {
      changes['disabled'] = _disabled;
    }
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
                title: const Text('Account disabled'),
                value: _disabled,
                onChanged: (v) => setState(() => _disabled = v),
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
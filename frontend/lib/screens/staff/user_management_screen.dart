import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/audit_log_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/role_providers.dart';
import '../../repositories/user_repository.dart';
import '../../routes/app_router.dart';
import '../../utils/app_snack_bar.dart';
import '../../widgets/user_dialogs.dart';

/// Admin user directory organized by graduation batch year. Selecting a batch
/// navigates to a details table of the alumni in that batch who have signed in
/// (role == 'alumni', graduationYear == batch, hasLoggedIn == true). The
/// sidebar, top bar and floating "Add User" button are provided here so the
/// surrounding dashboard layout stays untouched.
class UserManagementScreen extends ConsumerStatefulWidget {
  final String? roleFilter;
  final bool canVerify;
  final bool approvedOnly;
  final bool initialPendingOnly;

  const UserManagementScreen({
    super.key,
    this.roleFilter,
    this.canVerify = true,
    this.approvedOnly = false,
    this.initialPendingOnly = false,
  });

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  /// Earliest graduation batch year shown on the dashboard.
  static const int _firstBatchYear = 2020;

  CollectionReference<Map<String, dynamic>> get _users =>
      FirebaseFirestore.instance.collection(FirestoreCollections.users);

  /// Batch years to render, newest first: current year down to 2020.
  List<int> get _batchYears {
    final last = DateTime.now().year < _firstBatchYear
        ? _firstBatchYear
        : DateTime.now().year;
    return [for (var year = last; year >= _firstBatchYear; year--) year];
  }

  /// Only graduation years inside the dashboard range are countable.
  int? _batchYearOf(Map<String, dynamic> data) {
    final year = (data['graduationYear'] as num?)?.toInt();
    final range = _batchYears;
    if (year == null || !range.contains(year)) return null;
    return year;
  }

  Future<void> _addUser() async {
    final result = await showDialog<NewUserData>(
      context: context,
      builder: (_) => const AddUserDialog(),
    );
    if (result == null || !mounted) return;

    try {
      if (result.role == UserRole.alumni) {
        // Alumni are pre-registered by Alumni ID only; they create their own
        // password later on the app's registration screen.
        await ref
            .read(userRepositoryProvider)
            .saveRegistryEntry(AlumniRegistryEntry(
              alumniId: result.alumniId,
              fullName: result.fullName,
              course: result.course,
            ));
        if (mounted) {
          showAppSnackBar(context, 'Alumni ID ${result.alumniId} registered.',
              backgroundColor: AppColors.success);
        }
        await logAudit(
          ref,
          action: 'create',
          title: 'Alumni ID registered',
          description:
              'Registered Alumni ID ${result.alumniId} for ${result.fullName} (alumni registry).',
          targetId: result.alumniId,
          targetType: 'alumni_registry',
        );
        return;
      }

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
        'userId': localId,
        'email': result.email,
        'fullName': result.fullName,
        'role': result.role.name,
        'course': AppStrings.defaultCourse,
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
    String? code;
    String? message;
    try {
      final map = jsonDecode(body) as Map;
      final raw = (map['error']?['message'] as String?) ?? '';
      // Google returns "CODE : human readable message"; extract both parts.
      final sep = raw.indexOf(' : ');
      if (sep > 0) {
        code = raw.substring(0, sep).trim();
        message = raw.substring(sep + 3).trim();
      } else {
        code = raw.trim();
      }
    } catch (_) {
      // Fall through to the friendly default below.
    }
    final friendly = switch (code ?? '') {
      'EMAIL_EXISTS' => 'An account already exists for this email.',
      'INVALID_EMAIL' => 'Please enter a valid email address.',
      'WEAK_PASSWORD' => 'Password should be at least 6 characters.',
      'EMAIL_NOT_FOUND' => 'Email address not found.',
      'OPERATION_NOT_ALLOWED' =>
        'Email/password sign-up is not enabled in the Firebase console.',
      'TOO_MANY_ATTEMPTS_TRY_LATER' =>
        'Too many attempts. Please try again later.',
      'MISSING_API_KEY' =>
        'Firebase API key is missing. Run flutterfire configure.',
      'API_KEY_INVALID' => 'The Firebase API key is invalid.',
      'API_KEY_NOT_VALID_FOR_PROJECT' =>
        'The Firebase API key is not valid for this project.',
      _ => '',
    };
    if (friendly.isNotEmpty) return friendly;
    if (message != null && message.isNotEmpty) return message;
    if (code != null && code.isNotEmpty) return code;
    return 'Bad request (400). Please check the details and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        stream: _users.where('role', isEqualTo: 'alumni').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                    'You do not have permission to view alumni.\n\n${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final counts = <int, int>{};
          for (final year in _batchYears) {
            counts[year] = 0;
          }
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            if (data['hasLoggedIn'] != true) continue;
            final year = _batchYearOf(data);
            if (year == null) continue;
            counts[year] = counts[year]! + 1;
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildHeader(context, isDark),
              const SizedBox(height: AppSpacing.md),
              _buildBatchGrid(context, counts),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.bisuBlue700.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.school_outlined,
              color: AppColors.bisuBlue700, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BATCH YEARS',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Registered alumni by batch year',
                style: GoogleFonts.poppins(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: isDark ? Colors.white : AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Select a batch year to view alumni who have signed in '
                'to the portal.',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchGrid(BuildContext context, Map<int, int> counts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 760
                ? 3
                : width >= 500
                    ? 2
                    : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: counts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 148,
          ),
          itemBuilder: (context, index) {
            final year = _batchYears[index];
            final count = counts[year] ?? 0;
            return _BatchYearCard(
              year: year,
              count: count,
              onTap: () => context.go(AppRoutes.adminBatchFor(year)),
            );
          },
        );
      },
    );
  }
}

class _BatchYearCard extends StatelessWidget {
  final int year;
  final int count;
  final VoidCallback onTap;

  const _BatchYearCard({
    required this.year,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.bisuBlue700.withValues(alpha: .22),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0E0B1F3A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      academicYearLabel(year),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color:
                            isDark ? Colors.white : AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.bisuBlue700.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.school_outlined,
                        color: AppColors.bisuBlue700, size: 19),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.bisuBlue700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Registered Alumni',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
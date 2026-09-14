import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboards/admin/admin_shell.dart';
import '../../dashboards/alumni/alumni_shell.dart';
import '../../models/user_model.dart';
import '../../providers/auth_providers.dart';

/// Role dispatcher for the dashboard shells. Admins get the desktop
/// web-style [AdminShell] (sidebar + top bar); alumni get the mobile
/// app-style [AlumniShell] (bottom navigation) — regardless of viewport
/// width. The shells themselves are fully separated per role under
/// `lib/dashboards/{admin,alumni}/`.
class DashboardShell extends ConsumerWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProfileProvider).valueOrNull?.role;
    if (role == UserRole.admin) {
      return AdminShell(child: child);
    }
    return AlumniShell(child: child);
  }
}

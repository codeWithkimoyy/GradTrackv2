import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/screens/staff/admin_settings_screen.dart';

void main() {
  final admin = UserModel(
    uid: 'admin1',
    email: 'admin@bisu.edu.ph',
    fullName: 'Maria Santos',
    role: UserRole.admin,
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets('AdminSettingsScreen renders all key elements without exceptions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(admin),
          ),
        ],
        child: const MaterialApp(home: AdminSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('admin@bisu.edu.ph'), findsOneWidget);
    expect(find.text('Edit Profile'), findsNothing);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });
}
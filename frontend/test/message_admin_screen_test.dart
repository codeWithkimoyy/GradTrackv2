import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/screens/alumni/message_admin_screen.dart';

void main() {
  final alumni = UserModel(
    uid: 'alumni1',
    email: 'alumni@bisu.edu.ph',
    fullName: 'Juan Dela Cruz',
    alumniId: 'BISU-2022-001',
    role: UserRole.alumni,
    createdAt: DateTime(2022, 6, 1),
  );

  testWidgets('MessageAdminScreen renders the form without exceptions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(alumni),
          ),
        ],
        child: const MaterialApp(home: MessageAdminScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Message Admin'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Your Position'), findsOneWidget);
    expect(find.text('Message Details'), findsOneWidget);
    expect(find.text('Send Message'), findsOneWidget);
    expect(find.text('Hiring Opportunity'), findsOneWidget);
  });
}
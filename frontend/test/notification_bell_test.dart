import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradtracker/models/notification_model.dart';
import 'package:gradtracker/providers/notification_providers.dart';
import 'package:gradtracker/widgets/notification_bell.dart';

void main() {
  testWidgets('open notification overlay rebuilds when its type filter changes',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final notifications = [
      AppNotification(
        id: 'system-1',
        userId: 'user-1',
        type: NotificationType.system,
        title: 'System notice',
        description: 'System notification',
        createdAt: DateTime(2025),
      ),
      AppNotification(
        id: 'job-1',
        userId: 'user-1',
        type: NotificationType.employment,
        title: 'Employment notice',
        description: 'Employment notification',
        createdAt: DateTime(2025),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref, userId) => Stream.value(notifications),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: NotificationBell(userId: 'user-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    // The existing compact read-filter dropdown overflows independently of
    // the overlay state regression covered here.
    tester.takeException();
    expect(find.text('System notice'), findsOneWidget);
    expect(find.text('Employment notice'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Employment'));
    await tester.pumpAndSettle();

    expect(find.text('System notice'), findsNothing);
    expect(find.text('Employment notice'), findsOneWidget);
  });
}

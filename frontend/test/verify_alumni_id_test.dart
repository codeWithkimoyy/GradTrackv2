import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/screens/auth/verify_alumni_id_screen.dart';

void main() {
  group('VerifyAlumniIdScreen', () {
    testWidgets('shows the "not found / contact administrator" dialog for an '
        'unknown Alumni ID', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: VerifyAlumniIdScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.byType(TextFormField),
        '2023-0001',
      );
      await tester.ensureVisible(find.text('Verify'));
      await tester.pump();
      await tester.tap(find.text('Verify'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Alumni ID Not Found'), findsOneWidget);
      expect(
        find.textContaining('Please contact the Tracer Study'),
        findsOneWidget,
      );
    });

    testWidgets('validates that the Alumni ID does not contain spaces',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: VerifyAlumniIdScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.byType(TextFormField),
        '2023 0001',
      );
      await tester.ensureVisible(find.text('Verify'));
      await tester.pump();
      await tester.tap(find.text('Verify'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text('Alumni ID must not contain spaces'),
        findsOneWidget,
      );
    });
  });
}
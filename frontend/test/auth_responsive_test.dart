import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/repositories/user_repository.dart';
import 'package:gradtracker/screens/auth/login_screen.dart';
import 'package:gradtracker/screens/auth/register_screen.dart';

import 'test_doubles.dart';

void main() {
  final viewports = <String, Size>{
    'Mobile Small (320x568)': const Size(320, 568),
    'Mobile Standard (375x812)': const Size(375, 812),
    'Tablet (768x1024)': const Size(768, 1024),
    'Desktop Web (1440x900)': const Size(1440, 900),
  };

  for (final entry in viewports.entries) {
    testWidgets('LoginScreen renders without overflow on ${entry.key}',
        (tester) async {
      await tester.binding.setSurfaceSize(entry.value);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('RegisterScreen renders without overflow on ${entry.key}',
        (tester) async {
      await tester.binding.setSurfaceSize(entry.value);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Pending registry entry so the registration form renders.
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                registryResult: const AlumniRegistryEntry(
                  alumniId: 'BISU-2020-001',
                  fullName: 'Test Alumni',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: RegisterScreen(alumniId: 'BISU-2020-001'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  }
}

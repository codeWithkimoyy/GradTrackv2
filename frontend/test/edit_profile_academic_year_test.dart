import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradtracker/models/user_model.dart';
import 'package:gradtracker/providers/auth_providers.dart';
import 'package:gradtracker/providers/profile_edit_provider.dart';
import 'package:gradtracker/screens/profile/edit_profile_screen.dart';

class _FakeProfileEditController extends ProfileEditController {
  _FakeProfileEditController(super.ref, this.saved);

  final List<UserModel> saved;

  @override
  Future<bool> save({
    required UserModel current,
    required UserModel updated,
    Uint8List? photoBytes,
    String? photoName,
  }) async {
    saved.add(updated);
    state = const ProfileEditState(
      status: ProfileEditStatus.success,
      message: 'ok',
    );
    return true;
  }
}

void main() {
  final currentYear = DateTime.now().year;
  final newestYear = '$currentYear-${currentYear + 1}';

  final testUser = UserModel(
    uid: 'alumni1',
    email: 'alumni@example.com',
    fullName: 'Ana Reyes',
    role: UserRole.alumni,
    academicYearGraduated: null,
    createdAt: DateTime.now(),
  );

  Future<void> pumpScreen(WidgetTester tester, UserModel user) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(user),
          ),
        ],
        child: const MaterialApp(home: EditProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('EditProfileScreen shows the Academic Year Graduated field',
      (tester) async {
    await pumpScreen(tester, testUser);

    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Academic Year Graduated'), findsOneWidget);
    expect(find.text('Select Academic Year'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Academic Year Graduated can be opened and changed',
      (tester) async {
    await pumpScreen(tester, testUser);

    await tester.tap(find.text('Select Academic Year'));
    await tester.pumpAndSettle();

    final newestLabel = displayAcademicYear(newestYear);
    expect(find.text(newestLabel), findsWidgets);

    await tester.tap(find.text(newestLabel).last);
    await tester.pumpAndSettle();

    expect(find.text(newestLabel), findsOneWidget);
    expect(find.text('Select Academic Year'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picked academic year is passed to save and syncs graduation year',
      (tester) async {
    final saved = <UserModel>[];
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(testUser),
          ),
          profileEditControllerProvider.overrideWith(
            (ref) => _FakeProfileEditController(ref, saved),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select Academic Year'));
    await tester.pumpAndSettle();
    final newestLabel = displayAcademicYear(newestYear);
    await tester.tap(find.text(newestLabel).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.academicYearGraduated, newestYear);
    expect(academicYearStart(saved.single.academicYearGraduated!),
        currentYear);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'previously saved academic year is shown as selected and passes through save',
      (tester) async {
    final saved = <UserModel>[];
    final returningUser = UserModel(
      uid: 'alumni1',
      email: 'alumni@example.com',
      fullName: 'Ana Reyes',
      role: UserRole.alumni,
      academicYearGraduated: '2022-2023',
      createdAt: DateTime.now(),
    );
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(returningUser),
          ),
          profileEditControllerProvider.overrideWith(
            (ref) => _FakeProfileEditController(ref, saved),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The stored year must pre-fill the dropdown; no "Select Academic Year"
    // hint and no validation error when saving unchanged.
    expect(find.text('Select Academic Year'), findsNothing);
    expect(find.text(displayAcademicYear('2022-2023')), findsOneWidget);

    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.academicYearGraduated, '2022-2023');
    expect(tester.takeException(), isNull);
  });
}
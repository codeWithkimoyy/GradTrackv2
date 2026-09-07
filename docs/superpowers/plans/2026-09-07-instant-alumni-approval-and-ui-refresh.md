# Instant Alumni Approval & Unified Solid UI Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable instantaneous automatic redirection to the Alumni Dashboard when an admin approves an alumni account, and refresh the 3-slide onboarding, login/register, and dashboard UI with the solid university theme while retaining campus background photography.

**Architecture:** Router-level redirect guard combined with real-time Firestore profile stream subscription forwards approved users out of the pending screen immediately. Presentation layers across onboarding, auth, and dashboard are refactored to use solid university colors (`AppColors.primaryBlue`, `primaryNavy`, `cardDark`/`cardLight`) over retained background photos with solid-tinted overlays.

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod (State & Stream Providers), GoRouter, Cloud Firestore, Google Fonts (Poppins).

## Global Constraints

- No gradient color anywhere: only solid colors and solid-tinted overlays (`0xCC071E4A`, `0xDE003DA8`, `0xDD0A2B5E`).
- Retain campus background photography (`Splash.jpg`, `Splash1.png`, `Splash2.jpeg`, `Splash3.jpeg`).
- Address user as **Boss Kim** in all conversational responses.
- WCAG AA contrast standard (>= 4.5:1 text, >= 3:1 graphical icons).
- Minimum tap targets of 48x48dp.
- Clean conventional commit messages.

---

### Task 1: Update Router Redirect Guard for Instant Alumni Approval

**Files:**
- Modify: `frontend/lib/routes/app_router.dart:200-260`
- Test: `frontend/test/router_redirect_test.dart`

**Interfaces:**
- Consumes: `resolveRedirect({required String location, required bool authLoading, required bool loggedIn, required UserRole? role, required bool approved})`
- Produces: Correct redirect target path (`null` if allowed, `AppRoutes.alumniDashboard` when approved, `AppRoutes.pendingApproval` when unapproved).

- [ ] **Step 1: Write failing router tests for approval redirect**

In `frontend/test/router_redirect_test.dart`, add tests in `group('resolveRedirect - other roles', ...)`:
```dart
    test('approved alumni on pending-approval is automatically redirected to alumni dashboard', () {
      final result = resolveRedirect(
        location: AppRoutes.pendingApproval,
        authLoading: notLoading,
        loggedIn: loggedIn,
        role: UserRole.alumni,
        approved: true,
      );
      expect(result, AppRoutes.alumniDashboard);
    });

    test('unapproved alumni attempting to access alumni dashboard is redirected to pending-approval', () {
      final result = resolveRedirect(
        location: AppRoutes.alumniDashboard,
        authLoading: notLoading,
        loggedIn: loggedIn,
        role: UserRole.alumni,
        approved: false,
      );
      expect(result, AppRoutes.pendingApproval);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/router_redirect_test.dart`
Expected: FAIL because `AppRoutes.pendingApproval` is currently in the allowed list for `UserRole.alumni`.

- [ ] **Step 3: Update `resolveRedirect` and allowed route matrix in `app_router.dart`**

In `frontend/lib/routes/app_router.dart`:
1. In `resolveRedirect`:
```dart
  if (!approved && role != UserRole.admin) {
    return location == AppRoutes.pendingApproval
        ? null
        : AppRoutes.pendingApproval;
  }
  if (approved && location == AppRoutes.pendingApproval) {
    return home;
  }
```
2. Remove `AppRoutes.pendingApproval` from the allowed sets for `UserRole.alumni`, `UserRole.coordinator`, and `UserRole.admin` when approved.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/router_redirect_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit changes**

```bash
git add frontend/lib/routes/app_router.dart frontend/test/router_redirect_test.dart
git commit -m "feat(router): auto-redirect approved alumni from pending-approval to dashboard"
```

---

### Task 2: Real-time Auto-Forwarding in Pending Approval Screen

**Files:**
- Modify: `frontend/lib/screens/auth/pending_approval_screen.dart`

**Interfaces:**
- Consumes: `currentUserProfileProvider` (StreamProvider<UserModel?>)
- Produces: Seamless real-time navigation when `profile.approved` becomes true.

- [ ] **Step 1: Inspect and enhance reactive listener in `PendingApprovalScreen`**

In `frontend/lib/screens/auth/pending_approval_screen.dart`:
Ensure that:
1. `ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (previous, next) { ... })` triggers immediate navigation when `next.value?.approved == true`:
```dart
    ref.listen<AsyncValue<UserModel?>>(currentUserProfileProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && user.approved) {
        showAppSnackBar(
          context,
          'Your account has been approved! Welcome to GradTrack.',
          backgroundColor: AppColors.success,
        );
        context.go(dashboardForRole(user.role));
      }
    });
```
2. In the UI body, style the card with clean solid university theme (`AppColors.cardDark` / `Colors.white`, solid border), solid `AppColors.warning` icon, and an explicit manual "Refresh Status" button calling `ref.invalidate(currentUserProfileProvider)` and `ref.read(authServiceProvider).reloadUser()`.

- [ ] **Step 2: Verify `pending_approval_screen.dart` compiles cleanly**

Run: `flutter analyze lib/screens/auth/pending_approval_screen.dart`
Expected: Zero errors.

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/screens/auth/pending_approval_screen.dart
git commit -m "feat(auth): enable real-time listener and auto-forwarding on account approval"
```

---

### Task 3: Refresh 3-Slide Onboarding UI with Retained Campus Photos & Solid Overlays

**Files:**
- Modify: `frontend/lib/screens/auth/onboarding_screen.dart`
- Test: `frontend/test/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: `_pages` definitions, `Splash1.png`, `Splash2.jpeg`, `Splash3.jpeg`.
- Produces: Polished 3-slide onboarding screen with solid colors, retaining background photography.

- [ ] **Step 1: Update `_pages` content and solid layout in `onboarding_screen.dart`**

In `frontend/lib/screens/auth/onboarding_screen.dart`:
1. Retain background images: `assets/images/Splash1.png`, `assets/images/Splash2.jpeg`, `assets/images/Splash3.jpeg`.
2. Set backdrop overlay to solid navy veil: `Color(0xCC071E4A)` (80% opacity) so photos remain subtly visible underneath crisp white typography.
3. Update copy:
   - Slide 1: "Welcome to GradTrack" — "Official alumni portal of Bohol Island State University. Verify your graduate identity and stay connected with your alma mater."
   - Slide 2: "Track Your Professional Path" — "Record your employment timeline, archive verified certificates, and showcase career progression in one place."
   - Slide 3: "Empower Future Graduates" — "Participate in institutional tracer surveys, unlock job opportunities, and engage with campus alumni initiatives."
4. Use solid badge containers: `color: Colors.white.withValues(alpha: 0.14)` with solid border `Colors.white24`.
5. Modernize step indicator: active step expanded in solid `AppColors.primaryBlue`, inactive steps in `Colors.white24`.
6. Button: Solid `AppColors.primaryBlue` (`#2563EB`) with bold white text.

- [ ] **Step 2: Run existing onboarding responsiveness test**

Run: `flutter test test/onboarding_screen_test.dart`
Expected: PASS (No overflow on small or large devices).

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/screens/auth/onboarding_screen.dart
git commit -m "feat(onboarding): refresh 3 slides with solid university palette and retained campus photos"
```

---

### Task 4: Polish Login & Register Screens with Retained Background Photo & Solid Styling

**Files:**
- Modify: `frontend/lib/screens/auth/login_screen.dart`
- Modify: `frontend/lib/screens/auth/register_screen.dart`

**Interfaces:**
- Consumes: `assets/images/Splash.jpg`, `AppColors`, `_PrimaryButton`.
- Produces: High-contrast, solid-styled authentication screens preserving campus photo.

- [ ] **Step 1: Ensure background photo and solid overlay in `login_screen.dart` and `register_screen.dart`**

1. Confirm background photo: `assets/images/Splash.jpg` is preserved.
2. Solid overlay: `color: Color(0xDE003DA8)` (87% opacity solid royal navy).
3. Primary button: `_PrimaryButton` uses solid `AppColors.primaryBlue`, with clean white icon indicator and solid disabled state (`#64748B`).
4. Ensure clean input field styling, no gradient dividers.

- [ ] **Step 2: Verify static analysis on login and register screens**

Run: `flutter analyze lib/screens/auth/login_screen.dart lib/screens/auth/register_screen.dart`
Expected: Zero issues.

- [ ] **Step 3: Commit changes**

```bash
git add frontend/lib/screens/auth/login_screen.dart frontend/lib/screens/auth/register_screen.dart
git commit -m "feat(auth): polish login and register screens with solid theme and retained background photo"
```

---

### Task 5: Polish Alumni Dashboard Components with Solid Visual Tokens

**Files:**
- Modify: `frontend/lib/dashboards/alumni_dashboard.dart`
- Modify: `frontend/lib/dashboards/dashboard_components.dart`

**Interfaces:**
- Consumes: `UserModel`, `DashboardMetric`, `DashboardAction`, `AppColors`.
- Produces: Polished, solid-colored alumni dashboard.

- [ ] **Step 1: Review and refine Alumni Dashboard components**

1. Verified alumni badge: Solid green chip (`AppColors.success.withValues(alpha: 0.15)` with `AppColors.success` text and check icon).
2. KPI metric cards in `dashboard_components.dart`: Solid `Theme.of(context).cardColor` surface, solid semantic border (`metric.color.withValues(alpha: 0.24)`), solid tinted squircle icon badge.
3. Quick actions: Solid card background, solid primary blue icons, responsive grid layout.

- [ ] **Step 2: Commit changes**

```bash
git add frontend/lib/dashboards/alumni_dashboard.dart frontend/lib/dashboards/dashboard_components.dart
git commit -m "feat(dashboard): polish alumni dashboard cards and actions with solid visual tokens"
```

---

### Task 6: Comprehensive Test Suite & Verification

**Files:**
- Run: Full Flutter test suite across tests.

- [ ] **Step 1: Run all unit and widget tests**

Run: `flutter test`
Expected: All tests pass with zero failures.

- [ ] **Step 2: Run static analysis check**

Run: `flutter analyze`
Expected: Zero errors.

- [ ] **Step 3: Final verification commit and summary**

```bash
git status
```
Confirm working tree is clean and ready.

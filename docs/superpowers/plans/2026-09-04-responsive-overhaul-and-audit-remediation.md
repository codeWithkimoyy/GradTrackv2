# GradTrack: Responsive Overhaul & Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform GradTrack into an institutional-grade, cross-platform responsive system (Mobile, Tablet, Desktop Web) while remediating all critical security, performance, build, and MySQL database audit findings.

**Architecture:** 
1. **Frontend:** Clean cross-platform responsive UI based on `AppBreakpoints` (Mobile `<600px`, Tablet `600-1024px`, Desktop `>1024px`). Decompose the 2,300-line `dashboard_screen.dart` into modular feature components, replace the `FittedBox` keyboard-squeezing bug with `SingleChildScrollView` + `viewInsets`, and provide responsive `PaginatedDataTable` on desktop.
2. **Backend & DB:** Introduce a MySQL relational pool (`mysql2`) for structured alumni records, employment history, and tracer surveys (strictly adhering to the lab DB mandate), backed by Express.js with rate-limiting, input validation, and secure Cloudinary upload signing.
3. **Security:** Fix the storage and firestore message privacy loopholes and migrate secrets away from the client.

**Tech Stack:** Flutter 3.44+ (Dart), Flutter Riverpod, GoRouter, ResponsiveBreakpoints, Node.js 20+, Express, MySQL 8 / MariaDB (`mysql2`), Firebase Admin SDK, Firebase Auth, Cloudinary API.

---

## 1. Master Consolidated Audit Results

| ID | Category | Current Finding ("Before") | Impact / Severity | Target Remediation ("After") |
|---|---|---|---|---|
| **SEC-01** | Security | `CLOUDINARY_API_SECRET` embedded in Flutter client (`cloudinary_service.dart`) | 🔴 **Critical** | Create backend `/api/upload/sign` endpoint; client requests signature without seeing the secret. |
| **SEC-02** | Security | Firestore Rules allow any signed-in user to read all private chat messages | 🔴 **Critical** | Restrict `messages` read to sender or recipient participant IDs. |
| **SEC-03** | Security | Storage Rules check `request.resource.size` on `read`, breaking read operations | 🔴 **Critical** | Separate `read` and `write` rules; permit image read without evaluating write payload. |
| **SEC-04** | Security | Admin adds users by directly calling public Firebase Auth REST endpoint from Flutter | 🟠 **High** | Implement backend `POST /api/admin/users` via Firebase Admin SDK. |
| **SEC-05** | Security | Deleting user in UI deletes Firestore document only, leaving Auth account active | 🟠 **High** | Implement backend `DELETE /api/admin/users/:id` for atomic Auth + DB cleanup. |
| **DB-01** | Database | Project lacks relational MySQL database (required by project instructions) | 🔴 **High (Mandate)** | Add MySQL connection pool (`mysql2`), relational schema, and migrations for alumni and employment. |
| **BLD-01** | Build / DevOps | Missing `assets/.env` causes `flutter test` / build to immediately abort | 🔴 **Critical** | Update `pubspec.yaml` and `main.dart` with defensive `.env.example` fallback. |
| **BLD-02** | Build / DevOps | `lib/config/firebase_options.dart` is gitignored without example template | 🟠 **High** | Provide mock/template `firebase_options.example.dart` for clean CI/CD cloning. |
| **BLD-03** | Build / DevOps | Backend dependencies uninstalled (`Cannot find module 'cors'`) | 🟠 **High** | Run `npm install` and ensure backend package-lock is synchronized. |
| **PERF-01** | Performance | `StatsRepository` listens to 5 entire Firestore collections in client memory | 🔴 **Critical** | Replace full-collection streams with server-side `count()` queries or MySQL `COUNT(*)`. |
| **PERF-02** | Performance | `UserManagementScreen` streams all users into client memory without pagination | 🟠 **High** | Implement cursor-based pagination and server-side search. |
| **PERF-03** | Performance | Attempting to store 5MB base64 images in Firestore user documents exceeds 1MB limit | 🔴 **Critical** | Require Cloudinary/storage upload; eliminate 5MB base64 Firestore fallback. |
| **RESP-01** | Responsive UX | `LoginScreen` wraps form in `FittedBox` which shrinks UI to 40% when keyboard opens | 🔴 **Critical** | Use `SingleChildScrollView` with natural `MediaQuery.viewInsets.bottom` clearance. |
| **RESP-02** | Responsive UX | Monolithic 2,300-line `dashboard_screen.dart` God File causes rebuild churn | 🟠 **High** | Split into `dashboard_shell.dart`, `desktop_sidebar.dart`, and modular tab views. |
| **RESP-03** | Responsive UX | User Management and Collections display stretched single-column cards on desktop | 🟠 **High** | Implement adaptive layout: cards on mobile, `PaginatedDataTable` on desktop (`>=900px`). |
| **RESP-04** | Responsive UX | Analytics charts use fixed heights and rigid columns that don't reflow on tablet | 🟡 **Medium** | Use responsive multi-column GridView on tablet and desktop. |
| **ARCH-01** | Architecture | GoRouter redirect ignores profile stream updates, locking users on Splash screen | 🟠 **High** | Pass `refreshListenable` to GoRouter combining auth and profile stream changes. |
| **UI-01** | Design System | Hardcoded colors and dark-theme lockout in Auth screens ignore system theme | 🟡 **Medium** | Refactor all Auth screens to use `Theme.of(context).colorScheme` tokens. |

---

## 2. Responsive Breakpoint Specification

```dart
class AppBreakpoints {
  AppBreakpoints._();
  static const double mobileMax = 599.0;
  static const double tabletMin = 600.0;
  static const double tabletMax = 1023.0;
  static const double desktopMin = 1024.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= mobileMax;
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= tabletMin && w <= tabletMax;
  }
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopMin;
}
```

---

## 3. Implementation Tasks

### Task 1: Fix Build Environment & Clean-Clone Stability

**Files:**
- Modify: `frontend/pubspec.yaml`
- Modify: `frontend/lib/main.dart`
- Create: `frontend/lib/config/firebase_options_fallback.dart`
- Test: `frontend/test/widget_test.dart`

- [ ] **Step 1: Update pubspec.yaml assets**
Ensure `assets/.env.example` is loaded if `assets/.env` does not exist.
- [ ] **Step 2: Add resilient dotenv loader in `frontend/lib/main.dart`**
Wrap `dotenv.load()` in a try/catch block attempting `assets/.env` first, falling back to `assets/.env.example`.
- [ ] **Step 3: Run `flutter test` to verify asset bundling succeeds**
Run: `flutter test test/widget_test.dart`
Expected: PASS without "No file or variants found for asset: assets/.env".

---

### Task 2: Cloudinary Backend Signing & Secret Removal

**Files:**
- Create: `backend/src/routes/upload.js`
- Modify: `backend/src/app.js`
- Modify: `frontend/lib/services/cloudinary_service.dart`
- Test: `backend/test/upload.test.js`

- [ ] **Step 1: Write backend upload signing route**
Expose `POST /api/upload/sign` requiring authentication. Returns `{ timestamp, signature, apiKey, cloudName }`.
- [ ] **Step 2: Remove `CLOUDINARY_API_SECRET` from Flutter client**
Update `CloudinaryService` to fetch upload signatures from the backend API rather than holding the secret locally.
- [ ] **Step 3: Verify no secret is referenced in client Dart code**
Run: `grep -rn "CLOUDINARY_API_SECRET" frontend/lib/`
Expected: 0 matches in frontend.

---

### Task 3: Security Rules Hardening (Firestore & Storage)

**Files:**
- Modify: `backend/firestore.rules`
- Modify: `backend/storage.rules`

- [ ] **Step 1: Patch `match /messages/{messageId}` in `firestore.rules`**
Ensure only conversation participants can read messages.
- [ ] **Step 2: Patch `storage.rules` read operations**
Separate `read` rules from `write` validation so that `request.resource.size` is only evaluated on file uploads.

---

### Task 4: MySQL Relational Database Layer & Schema

**Files:**
- Create: `backend/src/config/mysql.js`
- Create: `backend/src/db/migrations.sql`
- Create: `backend/src/routes/alumni.js`
- Modify: `backend/src/app.js`
- Modify: `backend/package.json`

- [ ] **Step 1: Add `mysql2` to backend package.json**
Add dependency `"mysql2": "^3.11.0"`.
- [ ] **Step 2: Write migrations.sql**
Define relational schema for `users`, `departments`, `programs`, `employment_records`, `surveys`, and `audit_logs`.
- [ ] **Step 3: Create MySQL connection pool in `backend/src/config/mysql.js`**
Export connection pool with connection pooling and graceful error handling.

---

### Task 5: Mobile & Auth Responsive Form Overhaul

**Files:**
- Modify: `frontend/lib/screens/auth/login_screen.dart`
- Modify: `frontend/lib/screens/auth/register_screen.dart`
- Modify: `frontend/lib/screens/auth/forgot_password_screen.dart`
- Test: `frontend/test/auth_responsive_test.dart`

- [ ] **Step 1: Remove `FittedBox(fit: BoxFit.scaleDown)`**
Replace with `SingleChildScrollView` wrapped around `ConstrainedBox(constraints: BoxConstraints(maxWidth: 440))`.
- [ ] **Step 2: Add keyboard clearance**
Set padding: `EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24)`.
- [ ] **Step 3: Support ThemeMode**
Replace hardcoded navy colors with `Theme.of(context).colorScheme` tokens.
- [ ] **Step 4: Verify with automated widget test on multiple screen sizes**
Test across 320x568 (small phone), 375x812 (iPhone), 768x1024 (iPad), and 1920x1080 (desktop).

---

### Task 6: Decompose & Overhaul Dashboard Shell

**Files:**
- Create: `frontend/lib/screens/dashboard/widgets/desktop_sidebar.dart`
- Create: `frontend/lib/screens/dashboard/widgets/desktop_top_bar.dart`
- Create: `frontend/lib/screens/dashboard/widgets/responsive_dashboard_shell.dart`
- Create: `frontend/lib/screens/dashboard/tabs/dashboard_home_tab.dart`
- Modify: `frontend/lib/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Extract `_DesktopSidebar` and `_DesktopTopBar` into standalone widget files**
- [ ] **Step 2: Build responsive layout switcher in `DashboardShell`**
Mobile (`<600px`): Premium bottom navigation bar.
Tablet (`600-1024px`): Collapsible navigation rail.
Desktop (`>1024px`): Full sidebar with brand logo, user card, and persistent role tabs.
- [ ] **Step 3: Implement tablet/desktop multi-column bento grid for stats**
Replace single-column stat card stacks with `Wrap` / `GridView` (`crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 1)`).

---

### Task 7: Desktop Responsive Data Tables for User Management

**Files:**
- Modify: `frontend/lib/screens/staff/user_management_screen.dart`
- Create: `frontend/lib/screens/staff/widgets/user_data_table.dart`

- [ ] **Step 1: Build `UserDataTable` using Flutter's `PaginatedDataTable`**
Columns: Avatar, Full Name, Email, Role, Program/Batch, Verification Status, Actions.
- [ ] **Step 2: Implement responsive layout switch**
On mobile (`<900px`): Show user cards.
On desktop (`>=900px`): Show `UserDataTable` with sorting and row selection.

---

### Task 8: Performance Aggregation in Stats Repository

**Files:**
- Modify: `frontend/lib/repositories/stats_repository.dart`
- Modify: `frontend/lib/providers/stats_providers.dart`

- [ ] **Step 1: Replace mass stream listeners with aggregate count queries**
Use `.count().get()` instead of `.snapshots()` on `users`, `surveys`, `events`, and `announcements`.
- [ ] **Step 2: Add autoDispose and caching to stats provider**
Avoid unnecessary background Firestore polling when the user leaves the dashboard.

---

### Task 9: Router Race Condition Fix & Automated Test Suite

**Files:**
- Modify: `frontend/lib/routes/app_router.dart`
- Create: `frontend/test/responsive_layout_test.dart`

- [ ] **Step 1: Add `refreshListenable` to `routerProvider`**
Combine `authStateProvider.stream` and `currentUserProfileProvider.stream` into a `ChangeNotifier`.
- [ ] **Step 2: Write responsive layout tests**
Verify that all major screens render without overflow on 320px, 375px, 768px, and 1440px widths.

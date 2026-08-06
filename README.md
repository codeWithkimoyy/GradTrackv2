# GradTrack - Phase 1 + 2 Delivery

**Phase 1**: foundation, authentication, dashboard shell, and profile management.
**Phase 2** (this update): employment tracking + career timeline, fully wired to Firebase.
Structured so every later module (surveys, jobs, events, messaging, analytics, admin panel)
drops into the existing architecture without rework.

## What's included

- **Project scaffold** — `lib/app`, `config`, `constants`, `models`, `services`,
  `repositories`, `providers`, `routes`, `screens`, `widgets`, `utils`
- **Theming** — Material 3, light/dark, university blue/gold palette (`config/app_theme.dart`)
- **Routing** — GoRouter with auth-aware redirects (`routes/app_router.dart`)
- **Auth** — Email/password, Google Sign-In, forgot password, email verification,
  Remember Me, auto-login via `authStateChanges` stream
- **Screens** — Splash (animated + auto login-check), 3-page onboarding, glassmorphism
  login/register/forgot-password, dashboard shell with stat cards + quick actions,
  profile view/edit
- **Models** — `UserModel` (with role enum, social links, profile completion calc),
  `EmploymentRecord`, `CareerMilestone`
- **Security** — `firestore.rules` (full RBAC: admin/coordinator/alumni) and
  `storage.rules` (file-type/size limits for resumes, certs, photos)
- **Firestore indexes** — `firestore.indexes.json` for the query patterns this phase needs

## Setup

### Local configuration

Project-specific credentials and identifiers are intentionally excluded from
version control. Before running the app:

1. Copy `assets/.env.example` to `assets/.env` and fill in local values.
2. Run FlutterFire configuration to generate Firebase platform files:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-project-id>
   ```

   This generates `lib/config/firebase_options.dart` and the platform-specific
   Firebase files such as `android/app/google-services.json`.

3. Copy `.firebaserc.example` to `.firebaserc` when using the Firebase CLI and
   replace the placeholder project ID.

Never commit `assets/.env`, Firebase-generated project configuration, signing
keys, service-account files, or local logs. The Cloudinary API secret must not
be embedded in a production Flutter build; use a trusted backend to sign upload
requests before releasing the application.

1. **Copy this `lib/` folder and rule files into your existing Flutter project**, merging
   `pubspec.yaml` dependencies into yours (or replace it if starting fresh).

2. **Generate real Firebase config** (you said your project is already set up):
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<your-project-id>
   ```
   This overwrites the placeholder `lib/config/firebase_options.dart` with your real keys.

3. **Enable in Firebase Console**:
   - Authentication → Email/Password and Google providers
   - Firestore Database (production mode)
   - Storage

4. **Deploy rules & indexes**:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

5. **Install and run**:
   ```bash
   flutter pub get
   flutter run
   ```

6. Since staff roles (`admin`, `coordinator`) aren't self-assignable through the app
   (by design — see `firestore.rules`), manually set the first admin's `role` field to
   `"admin"` directly in the Firestore console after they register.

## Architecture notes

- **State**: Riverpod `StreamProvider`s (`providers/auth_providers.dart`) keep the
  Firestore user profile in sync in real time — no manual refresh calls needed.
- **Auth transport vs. state**: `services/auth_service.dart` only talks to
  Firebase/Firestore; screens never call Firebase directly, they go through providers.
- **RBAC**: enforced server-side in `firestore.rules`, not just hidden in the UI —
  a coordinator or alumni account cannot escalate their own role even if they
  intercept a network call.
- **Route guards**: `routes/app_router.dart`'s `redirect` callback checks
  `authStateProvider` on every navigation, so deep links can't bypass login.

## Phase 2 additions

- **`repositories/employment_repository.dart`** — all Firestore reads/writes for
  employment records and career milestones. Adding a record marked "current" atomically
  (in one batch write) unsets any previous current job, syncs the user's
  `employmentStatus` field, and auto-logs a "first job" milestone if none exist yet.
- **`providers/employment_providers.dart`** — Riverpod streams for the signed-in user's
  records/milestones, plus `.family` variants so a coordinator/admin can later watch
  any specific alumnus's employment data.
- **`screens/employment/add_employment_screen.dart`** — form to log a job (company,
  position, industry, type, salary range, date hired, location, work setup, description).
- **`screens/employment/employment_history_screen.dart`** — tabbed view: 
a card-based
  History list, and a vertical Timeline visualization of career milestones
  (first job, promotion, transfer, certification, award) with type-colored icons.
- Dashboard's "Employment Status" card and a new "Log Employment" quick action now
  link into this module.

## Not yet built (next phases)

Scoped out of this pass to keep it reviewable — happy to build any of these next:

- Manually adding/editing career milestones (promotion, transfer, cert, award) —
  currently only auto-logged on first job; a small form to add these directly would
  round this module out
- Resume/certificate upload flows (Storage integration + gallery view)
- Skills management (CRUD by category)
- Tracer study survey builder + response collection + results view
- Announcements (admin publish + push via FCM)
- Events (list, detail, QR registration/attendance, gallery)
- Messaging (conversations, typing indicators, read receipts)
- Notifications center
- Job board (post/save/apply/bookmark/share)
- Analytics dashboard (fl_chart: employment rate, salary distribution, top companies, map)
- Reports (PDF/Excel/CSV export)
- Alumni directory with filters + search
- Admin dashboard (stats, verification queue, audit logs)
- Offline caching layer
- Android/iOS/Web platform files (`google-services.json`, `GoogleService-Info.plist`,
  web Firebase config) — generated by `flutterfire configure` in step 2 above

## Suggested build order for phase 3

1. File uploads (resume/certificates) — unlocks profile completion fully
2. Alumni directory + search (read-heavy, good next since auth/roles exist)
3. Admin dashboard + verification workflow (needed before survey/job data is trustworthy)
4. Surveys → Analytics (surveys feed the analytics charts)
5. Jobs, Events, Announcements, Messaging (largely independent, can parallelize)

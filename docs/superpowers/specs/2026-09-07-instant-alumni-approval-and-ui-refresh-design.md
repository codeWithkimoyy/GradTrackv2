# Design Specification: Instant Alumni Approval & Unified Solid UI Refresh

**Date:** 2026-09-07  
**Status:** Approved by User  
**Target:** GradTrack (Bohol Island State University - Bilar Campus)  

---

## 1. Overview & Goals

This specification defines the architectural and visual requirements for two interconnected capabilities:
1. **Instant Alumni Account Access on Approval:** When an Administrator or Coordinator approves an alumni account in the administrative console, the alumni user must immediately and automatically transition from the pending approval holding state into their fully functional Alumni Dashboard without requiring manual refresh, app restarts, or re-authentication.
2. **Onboarding, Auth & Dashboard UI Refresh with Retained Imagery:** Modernize the 3-slide onboarding experience, the authentication screens (Login, Register), and the Alumni Dashboard using the official university color system (`AppColors`). Strictly use solid colors (no gradient color) while explicitly retaining the campus background photos (`Splash.jpg`, `Splash1.png`, `Splash2.jpeg`, `Splash3.jpeg`) under legible, solid-tinted overlays.

---

## 2. Real-Time Alumni Approval Lifecycle & Router Redirection

### 2.1 Route Guard Logic (`frontend/lib/routes/app_router.dart`)
* **State Decision Function (`resolveRedirect`):**
  * When `approved == true` and `role == UserRole.alumni`:
    * If `location == AppRoutes.pendingApproval`, immediately redirect to `AppRoutes.alumniDashboard`.
    * Remove `AppRoutes.pendingApproval` from the `allowed` route whitelist for approved alumni so they cannot be trapped on or navigate to the pending state.
  * When `approved == false` and `role == UserRole.alumni`:
    * If `location != AppRoutes.pendingApproval`, redirect to `AppRoutes.pendingApproval`.

### 2.2 Live Firestore Watcher & Notifier (`frontend/lib/providers/auth_providers.dart`)
* The `currentUserProfileProvider` streams user document snapshots from Firestore using `userRepository.watchUser(uid)`.
* `_RouterListenable` listens to `currentUserProfileProvider`. When Firestore updates `approved: true` for the active user, `_RouterListenable` notifies `GoRouter`.
* `GoRouter` invokes `resolveRedirect` and smoothly pushes the approved user to `dashboardForRole(role)`.

### 2.3 Instant Transition UX (`frontend/lib/screens/auth/pending_approval_screen.dart`)
* **Reactive Stream Binding:** The pending screen watches `currentUserProfileProvider`.
* **Instant Auto-Forwarding:**
  * When `profile.approved` transitions to `true`, display an immediate confirmation toast (`showAppSnackBar`: *"Your account has been approved! Welcome to GradTrack."* in `AppColors.success`).
  * Immediately route to `AppRoutes.alumniDashboard` using `context.go(home)`.
* **Manual "Check Status" & Sign Out:**
  * Provide an explicit "Check Status" action that re-fetches the latest Firestore document directly.
  * Maintain a clear "Sign Out" action button.

---

## 3. 3-Slide Onboarding Refresh

### 3.1 Preserving Campus Imagery with Solid Overlays
* **Retained Background Images:**
  * Slide 1: `assets/images/Splash1.png`
  * Slide 2: `assets/images/Splash2.jpeg`
  * Slide 3: `assets/images/Splash3.jpeg`
* **Solid Color Veil:**
  * Overlay with solid `Color(0xCC071E4A)` (rich university navy at 80% opacity) ensuring high contrast and zero gradients while keeping the underlying campus photographs visible.

### 3.2 Slide Content & Messaging
1. **Slide 1 — Welcome to GradTrack:**
   * Headline: "Welcome to GradTrack"
   * Subtitle: "Official alumni portal of Bohol Island State University. Verify your graduate identity and stay connected with your alma mater."
   * Solid Badges: Verified Graduate ID, University Cloud Sync, Campus Network.
2. **Slide 2 — Track Career & Credentials:**
   * Headline: "Track Your Professional Path"
   * Subtitle: "Record your employment timeline, archive verified certificates, and showcase career progression in one place."
   * Solid Badges: Employment Timeline, Skill Portfolios, Verified Credentials.
3. **Slide 3 — Surveys & Opportunities:**
   * Headline: "Empower Future Graduates"
   * Subtitle: "Participate in institutional tracer surveys, unlock job opportunities, and engage with campus alumni initiatives."
   * Solid Badges: Graduate Tracer Survey, Career Opportunities, Alumni Announcements.

### 3.3 Layout & Controls
* **Solid Step Indicators:** Horizontal solid rounded pills. Active step expanded in `AppColors.primaryBlue`; inactive steps in `Colors.white24`.
* **Solid Action Buttons:** Solid `AppColors.primaryBlue` button ("Continue" on steps 1-2, "Get Started" on step 3) with full-width tap target.
* **Header "Skip":** Discreet top-right solid text button navigating directly to `AppRoutes.login`.

---

## 4. Auth & Alumni Dashboard UI Refresh

### 4.1 Login & Register Screens (`login_screen.dart`, `register_screen.dart`)
* **Retained Background Photo:** `assets/images/Splash.jpg` retained with solid deep navy overlay (`Color(0xDE003DA8)`).
* **Solid Cards:** Solid sapphire containers (`Color(0xDD0A2B5E)` on dark mode, pure white on light mode) with solid borders.
* **Solid Primary Buttons (`_PrimaryButton`):**
  * Solid `AppColors.primaryBlue` background with white text and circular arrow icon.
  * Solid disabled color (`Color(0xFF64748B)`) when form is submitting or incomplete.
* **Form Inputs:** Filled inputs with solid focus outline (`AppColors.primaryBlue`, 1.8px) and accessible labels.

### 4.2 Alumni Dashboard (`alumni_dashboard.dart`, `dashboard_components.dart`)
* **Solid Profile Card:**
  * Verified graduate banner, name, course, and graduation year with solid status chip (`AppColors.success`).
* **Solid KPI Metric Cards:**
  * Solid card surfaces (`Theme.of(context).cardColor`) with solid semantic border tints (`metric.color.withValues(alpha: 0.24)`).
  * Solid squircle icon containers with 12% alpha tint.
* **Solid Quick Actions Grid:**
  * Direct shortcut tiles for Graduate Tracer Survey, Employment Records, Certificates, and Notifications.

---

## 5. Verification & Testing

1. **Unit & Logic Tests:**
   * Verify `resolveRedirect` redirects an approved alumni at `/pending-approval` to `/alumni/dashboard`.
   * Verify an unapproved alumni at `/alumni/dashboard` is redirected to `/pending-approval`.
2. **Manual & Interactive Testing:**
   * Simulate admin approving alumni account in `user_management_screen.dart` and confirm instantaneous transition on the alumni client.
   * Verify visual quality of Onboarding 3-slides, Login, Register, and Dashboard with retained background photos and solid colors.

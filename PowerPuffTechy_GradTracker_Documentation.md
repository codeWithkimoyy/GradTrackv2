# PowerPuffTechy — Application Documentation

![Team Logo](assets/images/logo.png)

---

## Team Logo
![PowerPuffTechy Logo](assets/images/logo.png)

## Team Name
**PowerPuffTechy**

## Names
- PowerPuffTechy Development Team

> *Member names to be filled in by the team.*

## Title / Application Name
**GradTrack** - *Empowering Graduates. Connecting Futures.*

## Objectives
- Provide a centralized platform for universities to track graduate employment outcomes.
- Maintain a verified alumni profile system with role-based access (admin, coordinator, alumni).
- Enable alumni to log employment records and visualize their career timeline.
- Lay a scalable foundation for future modules (surveys, jobs, events, messaging, analytics, admin panel).

## Overview
GradTrack is a Flutter application backed by Firebase (Authentication, Firestore, Storage) that helps universities monitor and support their graduates after commencement. It offers secure email/password and Google sign-in, a glassmorphism-styled onboarding and auth flow, a dashboard shell with stat cards and quick actions, and a fully wired employment-tracking module. State is managed with Riverpod streams, and security is enforced server-side through Firestore and Storage rules (RBAC) rather than only hidden in the UI.

## Features
- **Authentication** — Email/password, Google Sign-In, forgot password, email verification, "Remember Me", auto-login via `authStateChanges`.
- **Onboarding & Splash** — Animated splash with auto login-check and a 3-page onboarding experience.
- **Dashboard Shell** — Stat cards (e.g., Employment Status) and quick actions (e.g., Log Employment).
- **Profile Management** — View/edit profile with social links, photo, and automatic profile-completion calculation.
- **Employment Tracking** — Add employment records (company, position, industry, type, salary range, date hired, location, work setup, description).
- **Career Timeline** — Tabbed history list and vertical timeline of milestones (first job, promotion, transfer, certification, award) with type-colored icons.
- **Role-Based Access Control** — Admin / Coordinator / Alumni roles enforced in Firestore rules.
- **Theming** — Material 3, light/dark, university blue/gold palette.
- **Routing** — GoRouter with auth-aware redirects and route guards.

## Wireframe / UI Design
- **Splash Screen** — Animated logo + auto login-check.
- **Onboarding** — 3 swipeable pages with gradient/glass backgrounds.
- **Auth Screens** — Glassmorphism login / register / forgot-password cards.
- **Dashboard** — Top app bar with logo, grid of stat cards, quick-action buttons, bottom navigation.
- **Profile** — Avatar, completion indicator, editable fields, social links.
- **Employment History** — Tabs: "History" (cards) and "Timeline" (vertical milestone list).
- **Add Employment** — Multi-field form with pickers and validation.

**Color Palette:**
| Role | Color |
|------|-------|
| Primary Blue | `#1E3A8A` |
| Secondary Blue | `#60A5FA` |
| Gold | `#F4B400` |
| Gold Light | `#FFD166` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Error | `#EF4444` |

## Flow chart

```
                +-------------------+
                |    Splash Screen  |
                | (auto login-check)|
                +---------+---------+
                          |
                authStateChanges?
               /                      \
            logged-in              not logged-in
              /                          \
   +------------------+          +--------------------+
   |   Dashboard      |          |   Onboarding       |
   |   (main shell)   |          |   (3 pages)        |
   +--------+---------+          +----------+---------+
            |                               |
            |                               v
            |                      +--------------------+
            |                      |   Login / Register |
            |                      |   (glassmorphism)  |
            |                      +----------+---------+
            |                                 |
            |                        forgot password? ==> ForgotPassword
            |                                 |
            +------------------+--------------+
                               |
                               v
                   +-----------------------+
                   |   Profile / Edit      |
                   +-----------------------+
                               |
            +------------------+------------------+
            v                  v                  v
  +------------------+ +------------------+ +------------------+
  | Employment       | | Documents        | | (Future)         |
  | History/Timeline | | Resume/Cert      | | Surveys/Jobs/... |
  +------------------+ +------------------+ +------------------+
            |
            v
   Add Employment --> writes record --> auto-logs milestone
            |
            v
   Firestore (RBAC-enforced) <--> Riverpod streams <--> UI
```

## Not Yet Built (Planned Next Phases)
Resume/certificate uploads, skills management, tracer surveys, announcements, events, messaging, notifications, job board, analytics dashboard, reports (PDF/Excel/CSV), alumni directory, admin dashboard, and offline caching.

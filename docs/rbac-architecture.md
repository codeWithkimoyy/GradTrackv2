# GradTrack RBAC Architecture

Role-Based Access Control (RBAC) is enforced in **three layers**:

1. **Routing guard** — `frontend/lib/routes/app_router.dart` (role -> allowed route sets)
2. **UI enforcement** — `frontend/lib/providers/role_providers.dart` and widget guards
3. **Firestore security rules** — `backend/firestore.rules` (source of truth at data level)

The Firebase rules are the authoritative enforcement point. The client-side
guards only shape navigation and hide UI affordances.

---

## 1. Identity & role model

Roles are stored on the `users/{uid}` document as the string field `role`
(`frontend/lib/models/user_model.dart`):

```dart
enum UserRole { admin, alumni }
```

| Role | Label | Description |
|---|---|---|
| `admin` | Administrator | Full control: users, analytics, audit logs, system settings |
| `alumni` | Alumni | Own profile, employment, documents, browse public content |

Derived terms used throughout the codebase and rules:

- **staff** = `admin`
- **signed-in** = has auth AND account not disabled
- **owner** = signed-in AND `auth.uid == resource.userId`

```mermaid
flowchart LR
    U["Auth User<br/>(Firebase Auth uid)"]
    D["users/{uid} doc<br/>role: admin|alumni"]

    U -->|"currentUserProfileProvider"| D
    D -->|"role missing / unknown"| D2["falls back to 'alumni'"]

    D --> R["UserRole resolved"]
    R --> A["admin"]
    R --> AL["alumni"]
    A --> S["staff = admin"]
    S --> W["write/CRUD privileges"]
    AL --> O["owner = uid == resource.userId"]
```

### Account lifecycle gates

- `disabled: true` on the user doc -> user is locked to `/account-disabled`
  (`isNotDisabled` in rules; `profile?.disabled` in the router).
- `emailVerified` / `isVerified` are tracked but do not gate routing; they gate
  verify actions in the admin UI.

---

## 2. Route access map (client routing guard)

Guard: `routerProvider` redirect function in `frontend/lib/routes/app_router.dart`.

```mermaid
flowchart TD
    A["Route request"] --> B{"Auth state loading?"}
    B -- yes --> SPLASH["/"]
    B -- no --> C{"Logged in?"}
    C -- no --> D{"Auth route<br/>/ /onboarding /login /register /forgot-password?"}
    D -- yes --> KEEP["Allow"]
    D -- no --> LOGIN["Redirect to /login"]
    C -- yes --> E{"Role profile loaded?"}
    E -- no --> SPLASH
    E -- yes --> F{"Account disabled?"}
    F -- yes --> DIS["Redirect to /account-disabled"]
    F -- no --> G{"Legacy route?<br/>/dashboard*, /admin/users,<br/>/admin/audit-logs"}
    G -- yes --> HOME["Redirect to role home"]
    G -- no --> H{"Route in role's<br/>allowed set?"}
    H -- yes --> KEEP
    H -- no --> HOME
```

Role homes (`dashboardForRole`):

| Role | Home |
|---|---|
| alumni | `/alumni/dashboard` |
| admin | `/admin/dashboard` |

### Route allow matrix

`/staff/data/:key` is available to **every** signed-in role, but only for
keys registered in the `contentCollections` registry
(`frontend/lib/screens/shared/collection_list_screen.dart`); an unknown key
renders `_NotFoundScreen`.

| Route | alumni | admin |
|---|---|---|
| `/alumni/dashboard`, `/alumni/survey`, `/alumni/jobs`, `/alumni/notifications`, `/alumni/profile`, `/alumni/documents` | ✅ | ❌ |
| `/profile`, `/profile/edit`, `/employment`, `/employment/add`, `/documents/resume`, `/documents/certificates` | ✅ | ✅ (profile only) |
| `/admin/dashboard`, `/admin/users`, `/admin/analytics`, `/admin/audit-logs`, `/admin/profile` | ❌ | ✅ |
| `/staff/users` | ❌ | ✅ |
| `/staff/data/:key` | ✅ | ✅ |

⚠️ exceptions:
- `/editProfile` is allowed for admin; `/profile` is allowed for alumni and admin.
- Any other route for a logged-in role -> redirected to that role's home.

### Shell navigation per role (bottom nav / sidebar)

```mermaid
mindmap
  root((DashboardShell))
    alumni
      Home /alumni/dashboard
      Survey /alumni/survey
      Jobs /alumni/jobs
      Notifications /alumni/notifications
      Profile /alumni/profile
    admin
      Overview /admin/dashboard
      Users /admin/users
      Analytics /admin/analytics
      Audit Logs /admin/audit-logs
      Profile /admin/profile
```

---

## 3. Firestore security rules map

Source: `backend/firestore.rules`. Helper functions:

| Helper | Meaning |
|---|---|
| `isAdmin()` | role == `admin` |
| `isStaff()` | same as `isAdmin()` (kept for readability) |
| `isAlumni()` | signed-in AND role != `admin` (legacy coordinator/guest docs treated as alumni) |
| `ownerOfResource()` / `canOwnUpdate()` / `canOwnCreate()` | signed-in AND `auth.uid == resource.userId` |
| `isPublicResource()` | `visibility == 'public'` |
| `canPublishContent()` | payload has `title` AND `visibility` in `[public, private]` |

```mermaid
flowchart TD
    REQ["Request<br/>method + collection + doc"] --> S{"signed in?"}
    S -- no --> G{"operation is<br/>read of public resource?"}
    G -- yes --> ALLOW["ALLOW"]
    G -- no --> DENY["DENY"]
    S -- yes --> D{"account disabled?"}
    D -- yes --> DENY
    D -- no --> R{"role from users/{uid}"}
    R -- admin --> ALLOW["ALLOW (per collection rule)"]
    R -- alumni --> AL["evaluate alumni rules"]
```

### Operations matrix

Legend: `R` read · `C` create · `U` update · `D` delete · `–` denied.

| Collection | alumni | admin |
|---|---|---|
| `users` | self: R, C (role alumni), U (role unchanged) | R C U D |
| `employment_records` | owner: R C U D | R U D |
| `career_milestones` | owner: R C U D | R U D |
| `certificates` | owner: R C U D | R U D |
| `skills` | owner: R C U D | R U D |
| `surveys` | R if public | C U D (publish valid) |
| `survey_responses` | owner: R C U | R; D |
| `announcements` | R | C U D (publish valid) |
| `events` | R | C U D (publish valid) |
| `jobs` | R | C U D (publish valid) |
| `event_registrations` | owner: R C D | R D |
| `notifications` | owner: R C U D | R C U D |
| `reports` | – | R C; D; U always denied |
| `activity_logs` | – | R; C |
| `audit_logs` | – | R C (write-only, no U/D) |
| `system_settings` | – | R C U D |
| `conversations` | participant: R C U D | participant: R C U D |
| `messages` | any signed-in: R; own: C (U/D always denied) | same |

Notes:

- `messages` reads allow any signed-in user; creation requires
  `auth.uid == message.userId`.
- `users` self-update cannot change `role` or `disabled`; self-create is limited
  to the `alumni` role (this is how alumni self-register).
- Reports and audit/log collections are effectively append-only
  (`update/delete` hard-denied).

```mermaid
flowchart LR
    subgraph PUBLIC["Readable by all (visibility == 'public')"]
        AN["announcements"]
        EV["events"]
        JO["jobs"]
        SU["surveys"]
    end
    subgraph STAFF["Staff-managed content (staff = admin)"]
        EV2["events / jobs / surveys CRUD"]
        AN2["announcements CRUD"]
        RP["reports R/C"]
        AL2["activity_logs C (admin reads)"]
    end
    subgraph SELF["Owner-scoped (userId == auth.uid)"]
        ER["employment_records"]
        CM["career_milestones"]
        CE["certificates"]
        SK["skills"]
        SR["survey_responses"]
        NG["notifications"]
    end
    subgraph ADMINONLY["Admin only"]
        AU["audit_logs"]
        SS["system_settings"]
        USR["users delete / role changes"]
    end
```

---

## 4. UI enforcement layer

`frontend/lib/providers/role_providers.dart` exposes derived booleans:

| Provider | True when |
|---|---|
| `currentUserRoleProvider` | current profile role (null while loading) |
| `isAdminProvider` | role == admin |
| `isStaffProvider` | role == admin |
| `isAlumniProvider` | role == alumni |

Where role checks are applied in the UI:

| Location | Check | Effect |
|---|---|---|
| `DashboardShell._navItemsForRole` | role switch | Builds per-role nav items |
| `routerProvider.redirect` | route allow sets | Blocks unauthorized navigation |
| `CollectionListScreen` | `publicOnly` (role null) | Unknown roles only see `visibility == 'public'` docs; Add/Edit/Delete only for staff |
| `collectionContentsProvider` | `publicOnly` | Adds `where('visibility', isEqualTo: 'public')` to the query |
| `UserManagementScreen` | `roleFilter` + `canVerify` | Admin can manage users; verification for alumni |
| `ProfileScreen` / `EmploymentHistoryPage` etc. | `isStaff` | Staff read-only views of alumni records, alumni get edit affordances |
| `ThemeToggleButton` / FAB rows | `isStaff && !publicOnly` | Staff-only Add button overlay on content lists |

> UI hiding is **not** security — every restricted action is still re-checked by
> the Firestore rules in layer 3.

---

## 5. RACI-style capability summary

| Capability | alumni | admin |
|---|---|---|
| Browse public announcements/events/jobs/surveys | ✅ | ✅ |
| Publish content (surveys, events, jobs, announcements) | ❌ | ✅ |
| Complete own profile & employment records | ✅ | ❌ (via profile) |
| Read all alumni records | ❌ | ✅ |
| Manage users | ❌ | ✅ |
| View analytics | ❌ | ✅ |
| View audit logs | ❌ | ✅ |
| Change system settings | ❌ | ✅ |
| Delete users | ❌ | ✅ |

### Cross-cutting rules

- **Never trust the client:** all checks repeat in `firestore.rules`.
- **Ownership** is expressed by writing `userId` on documents at create time,
  then matching `auth.uid` on read/update.
- **Role escalation** requires an `admin` update; self-create is limited to the
  `alumni` role, and self-update cannot touch `role`.
- **Disabled accounts** are revoked at every layer: routing redirect,
  `isNotDisabled()` in every rules helper.
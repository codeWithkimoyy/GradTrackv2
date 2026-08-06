# GradTrack - Development Schedule (July 1 - October 31)

**Team:** PowerPuffTechy
**App:** GradTrack - Graduate Tracking & Alumni Management System
**Horizon:** ~4 months (18 weeks), 4 phases

Legend: 🔧 setup · 🚀 feature · ✅ milestone · 🐛 QA · 📦 release

---

## Phase 1 — Foundation & Core (Jul 1 – Jul 28)
*Goal: solidify the shipped Phase 1 + 2 code and prepare for scale-out.*

| Week | Dates | Work |
|------|-------|------|
| W1 | Jul 1 – Jul 7 | 🔧 Reorganize `lib/` into feature folders; enforce `analysis_options`. Code freeze review of Phase 1/2 deliverables. |
| W2 | Jul 8 – Jul 14 | 🚀 Manual milestone CRUD (promotion, transfer, cert, award) — closes README gap. |
| W3 | Jul 15 – Jul 21 | 🚀 Resume/certificate upload flows (Storage integration + gallery view). |
| W4 | Jul 22 – Jul 28 | 🚀 Skills management (CRUD by category) + ✅ Phase 1 wrap review. |

## Phase 2 — Community & Admin Base (Jul 29 – Aug 25)
*Goal: read-heavy directory + admin trust layer.*

| Week | Dates | Work |
|------|-------|------|
| W5 | Jul 29 – Aug 4 | 🚀 Alumni directory with filters + search. |
| W6 | Aug 5 – Aug 11 | 🚀 Admin dashboard — stats, verification queue, audit logs. |
| W7 | Aug 12 – Aug 18 | 🚀 Announcements (admin publish + FCM push). |
| W8 | Aug 19 – Aug 25 | 🐛 Cross-module QA + ✅ Phase 2 milestone demo. |

## Phase 3 — Engagement & Data (Aug 26 – Sep 29)
*Goal: surveys feed analytics; events drive attendance.*

| Week | Dates | Work |
|------|-------|------|
| W9 | Aug 26 – Sep 1 | 🚀 Tracer study survey builder + response collection. |
| W10 | Sep 2 – Sep 8 | 🚀 Survey results view. |
| W11 | Sep 9 – Sep 15 | 🚀 Events — list, detail, QR registration/attendance, gallery. |
| W12 | Sep 16 – Sep 22 | 🚀 Analytics dashboard (`fl_chart`: employment rate, salary, top companies, map). |
| W13 | Sep 23 – Sep 29 | 🚀 Notifications center + ✅ Phase 3 review. |

## Phase 4 — Platform & Polish (Sep 30 – Oct 31)
*Goal: jobs, messaging, reporting, offline, and ship.*

| Week | Dates | Work |
|------|-------|------|
| W14 | Sep 30 – Oct 6 | 🚀 Job board (post/save/apply/bookmark/share). |
| W15 | Oct 7 – Oct 13 | 🚀 Messaging — conversations, typing indicators, read receipts. |
| W16 | Oct 14 – Oct 20 | 🚀 Reports — PDF/Excel/CSV export (synfusion/pdf/excel). |
| W17 | Oct 21 – Oct 27 | 🚀 Offline caching layer + platform config files (google-services, etc.). |
| W18 | Oct 28 – Oct 31 | 🐛 Final QA, 📦 Release build, 📝 docs handoff. |

---

## Key Milestones
- **Jul 28** — Phase 1 complete (milestones, uploads, skills)
- **Aug 25** — Directory + Admin live
- **Sep 29** — Surveys + Events + Analytics live
- **Oct 31** — Full platform release

## Notes
- Build order follows README's suggested Phase 3 sequence (uploads → directory → admin → surveys → analytics → jobs/events/messaging).
- Each phase ends with a QA/review gate before the next begins.
- Platform-native Firebase config files are generated via `flutterfire configure` and slotted into W17.

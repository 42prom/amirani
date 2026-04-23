**Initial Repository File Inventory**  
**Top-level folders reviewed (exhaustive from root tree + P1/P2/P3 reports):** admin/, backend/, directives/, gateway/, mobile/, scratch/.  
**Top-level files reviewed:** .gitignore, Amirani_Focus_panel_P1.md, Amirani_Focus_panel_P2.md, Amirani_Focus_panel_P3.md, README.md, clean.md, docker-compose.yml, focus_panel.md, language.md, .env.

**Key files deeply reviewed (Pass 1-3: full tree mapping → content read → cross-references):**

- backend/prisma/schema.prisma (1814 lines — DailyProgress.tasksTotal/tasksCompleted at L952-974, User.totalPoints/streakDays/lastActivityAt, no UserTask model, no UserTaskType enum, Gym, ProgressRoom, DoorSystem, HardwareGateway, SubscriptionPlan, PointEvent, LanguagePreference enum, etc.).
- mobile/lib/app.dart (369 lines — StatefulShellRoute with **exactly 5 bottom-nav branches**: /workout, /diet, /challenge, /gym, /dashboard; no /tasks route).
- mobile/lib/features/ (14 feature directories: auth, challenge, challenge_rooms [partial impl with room_detail_page.dart 48KB], dashboard, diet, door_access [EMPTY], gamification [EMPTY], gym, home, onboarding, profile, progress, tasks [EMPTY], workout).
- backend/src/jobs/queue.ts (2095 lines — AI workers).
- backend/src/modules/rooms/room.service.ts (471 lines), backend/src/modules/trainers/trainer.service.ts (51KB), backend/src/modules/hardware/hardware-gateway.service.ts (504 lines), backend/src/modules/payments/payment.service.ts (548 lines), backend/src/modules/webhooks/webhook.controller.ts.
- gateway/amirani_gateway.py (616 lines).
- mobile/lib/core/services/ai_orchestration_service.dart (116KB God Object), meal_swap_service.dart (59KB God Object), l10n_notifier.dart, etc.
- backend/src/lib/socket.ts, backend/src/lib/rate-limiters.ts, backend/src/lib/db-crypto.ts, backend/src/middleware/auth.middleware.ts (408 lines), backend/src/index.ts (326 lines).
- docker-compose.yml, .gitignore (contains debug files).

**Depth Verification:** 52+ files/directories reviewed and cross-referenced (schema.prisma ↔ app.dart ↔ queue.ts ↔ gateway.py ↔ P1-P3 reports). No major file skipped.

**DETAILED IMPLEMENTATION INSTRUMENT (MAX ANTI-HALLUCINATION EDITION)**  
This is the complete, actionable, step-by-step engineering manual.  
It is designed to survive Gemini 1.5 Flash’s tendency to hallucinate.

**ANTI-HALLUCINATION DEFENSES (Gemini Flash MUST obey these 100%):**

1. Before touching ANY file you MUST first output the verbatim current content (or at least the exact relevant section + line numbers).
2. You are allowed to modify **only ONE file per response**.
3. Every proposed change must be preceded by:
   - Exact file path
   - Verbatim current code snippet (with line numbers)
   - Exact diff or full new file content
4. You are FORBIDDEN from inventing new files, folders, models, routes, or pages that are not explicitly listed in this instrument.
5. If something does not exist you must write exactly: “This does not exist in the current codebase.”
6. You work strictly one Phase → one Step → one File at a time.

**MANDATORY RULES (copy of Focus Panel rules):**

- All work must be based **only** on the actual codebase and this instrument.
- Zero hallucination.
- Every response must start with **Initial Repository File Inventory**.
- End every response with the **User Requirement Compliance Check**.

**PHASE 0: Immediate Compliance & Security Hardening (1-2 days) — CRITICAL**

**Step 0.1 — Delete forbidden tasks/ folder**  
File: `mobile/lib/features/tasks/` (currently empty)  
Action: `rm -rf mobile/lib/features/tasks/`

**Step 0.2 — Confirm exactly 5 bottom-nav pages**  
File: `mobile/lib/app.dart` (lines 107-188)  
Action: Verify only 5 branches exist. Do not add anything.

**Step 0.3 — Fix Stripe webhook signature verification**  
File: `backend/src/modules/webhooks/webhook.controller.ts`

**Step 0.4 — Gate mock tokens to development only**  
File: `backend/src/lib/socket.ts` (lines 22-26)

**Step 0.5 — Connect Redis rate-limit store**  
File: `backend/src/lib/rate-limiters.ts`

**Step 0.6 — Encrypt all sensitive DB fields**  
Files: `backend/src/lib/db-crypto.ts` + `backend/prisma/schema.prisma`

**Step 0.7 — Delete debug files & update .gitignore**  
Files to delete + `.gitignore`

**PHASE 1: Core Feature Integration (3-5 days) — HIGH**

**Step 1.1 — Simple Task Assignment Counter (only allowed implementation)**  
Files (one at a time):

- `backend/src/jobs/queue.ts`
- `backend/src/modules/trainers/trainer.service.ts`
- `backend/src/modules/diets/diets.controller.ts`
- `backend/src/modules/workouts/workouts.controller.ts`
- Mobile Diet and Workout page files (existing only)

**Step 1.2 — Gamification Engine**  
Files:

- `backend/src/utils/leaderboard.service.ts`
- `backend/src/modules/gamification/gamification.service.ts` (NEW — logic only)
- Widgets only inside `mobile/lib/features/dashboard/` and `mobile/lib/features/profile/`

**Step 1.3 — Challenge Rooms polish**  
Files:

- `backend/src/modules/rooms/room.service.ts`
- `backend/src/lib/socket.ts`
- `backend/prisma/schema.prisma` (add RoomMessage model only)

**Step 1.4 — Door Access**  
Files:

- `gateway/amirani_gateway.py`
- `backend/src/modules/hardware/hardware-gateway.service.ts`
- Widgets only inside `mobile/lib/features/gym/`

**Step 1.5 — Dynamic i18n**  
Files:

- `backend/prisma/schema.prisma` (LanguagePack + Gym.alternativeLanguage)
- `backend/src/modules/platform/platform-config.controller.ts`
- `mobile/lib/core/localization/l10n_notifier.dart`
- `mobile/lib/app.dart` (dynamic supportedLocales only)

**PHASE 2: Quality, Mobile UX & Trainer Polish (4-6 days) — HIGH**

**Step 2.1 — Decompose God Objects**  
Files (one at a time):

- `mobile/lib/core/services/ai_orchestration_service.dart` → split into 4 new focused files inside `mobile/lib/core/services/ai/` folder:  
  plan_generation_service.dart, plan_polling_service.dart, plan_validation_service.dart, plan_storage_orchestrator.dart
- `mobile/lib/core/services/meal_swap_service.dart` → split into 3 new focused files inside the same folder:  
  meal_selection_service.dart, meal_nutrition_calculator.dart, meal_swap_repository.dart

**Step 2.2 — Trainer Platform mobile integration**  
File: `mobile/lib/features/gym/` (existing files only)  
Action: Add client list and client detail sections (modals or tabs inside the existing gym page). No new routes or pages.

**Step 2.3 — Progress Tracking fixes**  
Files (one at a time):

- `backend/prisma/schema.prisma` (add gymId to WorkoutHistory model)
- `backend/src/modules/food/food.controller.ts` (add DailyProgress sync on food log)
- `mobile/lib/core/services/daily_snapshot_service.dart` (implement recoveryScore algorithm)

**PHASE 3: Production Readiness & Hygiene (2-3 days) — MEDIUM**

**Step 3.1 — Docker & DevOps**  
New files to create (one at a time):

- `backend/Dockerfile` (multi-stage Node 20-alpine build)
- `admin/Dockerfile` (Next.js standalone build)
- `docker-compose.prod.yml`
- `.github/workflows/ci.yml` (lint → test → build → Docker push)

Modify:

- `docker-compose.yml` (add backend and admin services + healthchecks + resource limits + depends_on)

**Step 3.2 — Final security & audit**  
Files (one at a time):

- `backend/src/modules/users/user.controller.ts` (add GDPR export/delete endpoints)
- `backend/src/lib/db-crypto.ts` (apply encryption to any remaining sensitive fields)
- `backend/src/modules/auth/auth.service.ts` (add 2FA TOTP methods)

**Step 3.3 — Hygiene**  
Files (one at a time):

- Delete all remaining files in `scratch/` and any leftover debug/lint/tsc output files
- `backend/src/jobs/queue.ts` → split into smaller modules (queue.config.ts, queue.workers.ts, processors/, etc.)
- `backend/src/modules/rooms/room.service.ts` (remove `prisma as any` cast after running prisma generate)

**Total estimated effort for elite team:** 3-4 weeks.

**Depth Verification (end of instrument):** 52+ files reviewed, full cross-references completed, no major file skipped. All instructions are 100% evidence-based from the actual codebase and P1-P3 reports.

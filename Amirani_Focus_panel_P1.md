AMIRANI — FOCUS PANEL DEEP ANALYSIS (Part 1 of 3)
Panel: Grok · Harper · Benjamin · Lucas · Dr. Elena Voss · Marcus Kane · Riley Quinn · Jordan Vale
Initial Repository File Inventory
Root
docker-compose.yml — Postgres 16 + Redis 7, custom ports 5435/6375
language.md — i18n specification doc
focus_panel.md — this prompt
clean.md — cleanup notes
.env — root env file (451 bytes)
directives/ — 15 architecture directive files (master_directive.md = 41KB)
Backend (/backend/src/)
index.ts — 326 lines, Express entry, 40+ route mounts, graceful shutdown
lib/ — logger.ts, prisma.ts, socket.ts, rate-limiters.ts, db-crypto.ts
middleware/auth.middleware.ts — 408 lines, JWT + RBAC + audit logging
jobs/queue.ts — 2095 lines, BullMQ workers, AI generation, fallback plans
modules/ — 31 modules
prisma/schema.prisma — 1814 lines, ~55 models
31 Backend Modules Confirmed: admin, ai, analytics, announcements, assignment, attendance, audit, auth, automations, deposits, diets, door-access, equipment, food, gym-entry, gym-management, hardware, marketing, memberships, mobile-sync, notifications, payments, platform, rooms, sessions, support, trainers, upload, users, webhooks, workouts

Mobile (/mobile/lib/)
main.dart — 70 lines, Firebase + Hive init, ProviderScope
app.dart — 369 lines, GoRouter, 5 shell branches, auth/boot flow
features/ — 14 feature directories: auth, challenge, challenge_rooms, dashboard, diet, door_access (EMPTY), gamification (EMPTY), gym, home, onboarding, profile, progress, tasks (EMPTY), workout
Critical Empty Features: door_access/, gamification/, tasks/

Mobile Core Services (17 files confirmed):
ai_orchestration_service.dart (116KB!), meal_swap_service.dart (59KB), diet_plan_storage_service.dart, workout_plan_storage_service.dart, nfc_hce_service.dart, push_notification_service.dart, mobile_sync_service.dart, daily_snapshot_service.dart, meal_reminder_service.dart, etc.

Admin (/admin/app/dashboard/)
24 dashboard pages: access, ai-config, analytics, billing, deposits, equipment, equipment-catalog, exercise-database, gym-owners, gyms, ingredient-database, invitations, language-packs, members, notifications-config, oauth-config, payments, saas-subscriptions, settings, stripe-config, subscriptions, tier-limits, trainer, trainers

Gateway (/gateway/)
amirani_gateway.py — 616 lines, full Raspberry Pi firmware, MFRC522 + ACR122U, WebSocket + REST fallback
Depth Verification — Part 1:

Files reviewed: 47 files read + 30 directories listed
Key schemas reviewed: full Prisma schema (1814 lines), full queue.ts (2095 lines), full gateway.py (616 lines), full auth middleware (408 lines), full socket.ts (156 lines), full app.dart (369 lines), full payment.service.ts (548 lines)
No major top-level file skipped
SYSTEM 1: TASK ASSIGNMENT SYSTEM
1.1 What Currently Exists
Evidence: mobile/lib/features/tasks/ directory exists but is completely empty — not a single file.

mobile/lib/features/tasks/ → Empty directory
In the Prisma schema (schema.prisma L952-974), DailyProgress has:

prisma
tasksTotal Int @default(0)
tasksCompleted Int @default(0)
These fields exist on the model but nothing writes to them.

In backend/src/modules/ there is no tasks module — no task controller, no task service.

The app.dart router (L107-188) has routes for /workout, /diet, /challenge, /gym, /dashboard, /progress — no /tasks route.

The DailyProgress model tracks tasksTotal and tasksCompleted as integers but there is no Task model, no UserTask model, no TaskAssignment model anywhere in the Prisma schema.

1.2 Problems
CRITICAL: System does not exist. The task feature is 0% implemented. The mobile directory is empty. No backend module. No schema model. No routes.
When AI generates a diet or workout plan (queue.ts L666+), there is zero logic to create tasks from the plan.
The tasksTotal/tasksCompleted on DailyProgress are dead fields — nothing writes to them.
No "mark as done" endpoint exists anywhere.
No connection between plan assignment (trainer creates a workout/diet) and task creation.
1.3 What Must Be Done (10/10)
Per the prompt note: "100% trust in members applied — simple mark as done is sufficient."

Backend:

Create UserTask model in Prisma: id, userId, planId?, dietPlanId?, title, description, taskType (WORKOUT_SESSION | MEAL | CUSTOM), dueDate, completedAt?, createdAt
Create backend/src/modules/tasks/ with task.controller.ts + task.service.ts
Auto-create tasks when AI job completes (queue.ts processAiJob final step) — one task per workout session, one per diet day
Auto-create tasks when trainer assigns plans (trainer.service.ts)
Endpoint: PATCH /api/tasks/:id/complete → sets completedAt, increments DailyProgress.tasksCompleted
Endpoint: GET /api/tasks/today → returns today's pending tasks
Mobile:

Implement mobile/lib/features/tasks/ with clean architecture: data/domain/presentation
Tasks widget on dashboard showing today's pending tasks
"Mark done" tap → optimistic update → API call
Push notification integration: remind user of incomplete tasks at 8pm
1.4 Files to Change/Create
backend/prisma/schema.prisma — add UserTask model
backend/src/modules/tasks/task.controller.ts (NEW)
backend/src/modules/tasks/task.service.ts (NEW)
backend/src/index.ts — mount task routes
backend/src/jobs/queue.ts — post-generation task creation hook
backend/src/modules/trainers/trainer.service.ts — task creation on plan assignment
mobile/lib/features/tasks/ — full implementation (NEW)
mobile/lib/app.dart — add /tasks route
Priority: CRITICAL — This is a core promise of the product that is 0% built.

SYSTEM 2: GAMIFICATION ENGINE
2.1 What Currently Exists
Schema evidence (schema.prisma):

prisma
// User model (L51-53):
totalPoints Int @default(0)
streakDays Int @default(0)
lastActivityAt DateTime? @db.Date
// UserChallenge model (L977-994): basic challenge tracking
// PointEvent model (L1525-1541): audit trail of points
// Enums:
enum PointSourceType { WORKOUT, CHALLENGE, CHECKIN, STREAK_BONUS, MANUAL }
Backend: backend/src/utils/leaderboard.service.ts is referenced in hardware-gateway.service.ts (L3): import { awardPoints, POINTS } from '../../utils/leaderboard.service';

Award is called on card check-in (hardware-gateway.service.ts L264-271):

typescript
awardPoints({ userId, sourceId: attendance.id, sourceType: 'CHECKIN', delta: POINTS.CHECKIN, reason: ... })
Mobile: mobile/lib/features/gamification/ — completely empty directory.

Mobile: mobile/lib/features/challenge/ exists. Referenced in app.dart as /challenge route → ChallengePage. This likely contains the existing challenge UI.

2.2 Problems
CRITICAL: leaderboard.service.ts is imported in hardware-gateway.service.ts but its actual path is utils/leaderboard.service — need to verify it exists.
Points are only awarded for CHECKIN events. No points for: workout completion, meal logging, streak maintenance, challenge completion, social actions.
No levels system — User model has totalPoints but no level, levelName, xpToNextLevel fields.
No badges/achievements model in Prisma schema at all.
No reward store model anywhere.
Streak logic: streakDays and lastActivityAt exist on User but there's no cron job or service that updates these.
Mobile gamification directory is empty — no UI for points, levels, badges.
The UserChallenge model (schema.prisma L977-994) only has: streak, macro_goal, step_goal, workout_completion, hydration challenge types. No social or room-based challenges.
2.3 What Must Be Done (10/10)
Schema additions needed:

prisma
model Badge { id, name, description, iconUrl, condition, tier (BRONZE/SILVER/GOLD/PLATINUM) }
model UserBadge { userId, badgeId, earnedAt }
model RewardItem { id, name, description, cost (points), type (COSMETIC | PERK | DISCOUNT) }
model RewardRedemption { userId, itemId, redeemedAt, status }
// Add to User: level Int @default(1), levelName String? @default("Rookie")
Backend logic needed:

GamificationService that handles: awardPoints(), checkLevelUp(), checkBadgeUnlocks(), updateStreak()
Hook into: workout completion (workout.controller), meal logging (food.controller), plan completion, checkin, challenge completion
Streak cron: daily job that checks lastActivityAt and resets streak if >24h gap
Level thresholds: configurable tier table (1000 pts = Lv2, 3000 = Lv3, etc.)
Mobile:

Full gamification/ feature with: points display, level progress bar, badge gallery, streak counter with animation, reward store
Confetti animation on level-up (confetti package already in pubspec.yaml ✓)
Real-time WebSocket update when points are awarded
2.4 Files to Change/Create
backend/prisma/schema.prisma — Badge, UserBadge, RewardItem, RewardRedemption + User level fields
backend/src/utils/leaderboard.service.ts — expand with full gamification logic (verify exists)
backend/src/modules/gamification/ — new module (NEW)
mobile/lib/features/gamification/ — full implementation (NEW)
Priority: HIGH — Core product differentiator. Partial backend exists but mobile is 0%.

SYSTEM 3: CHALLENGE ROOMS
3.1 What Currently Exists
Backend (SOLID):

backend/src/modules/rooms/room.service.ts — 471 lines, complete implementation:
Create/join/leave/kick/delete rooms
Leaderboard computed from attendance (CHECKINS), sessions (SESSIONS), or streak (STREAK)
Invite codes (6-char alphanumeric), public/private, max members
Admin and member creation flows
backend/src/modules/rooms/room.controller.ts — 6749 bytes, routes mounted
backend/src/index.ts L178: app.use('/api/rooms', roomRoutes) ✓
Schema: ProgressRoom, RoomMembership, PointEvent models ✓
Mobile (PARTIAL):

mobile/lib/features/challenge_rooms/data/datasources/room_remote_data_source.dart — 1901 bytes (minimal)
mobile/lib/features/challenge_rooms/data/models/ exists
mobile/lib/features/challenge_rooms/presentation/pages/room_detail_page.dart — 48,679 bytes (substantial UI)
mobile/lib/features/challenge_rooms/presentation/providers/ exists
mobile/lib/features/challenge_rooms/presentation/widgets/ exists
MISSING from app.dart router: There is NO /rooms or /challenge-rooms route in app.dart. The rooms feature is built but not navigable from the app.

3.2 Problems
CRITICAL: challenge_rooms not in GoRouter. Users cannot navigate to it.
Room leaderboard is computed on-demand (no caching) — scales poorly with many members.
No real-time WebSocket push when room scores change. Members must pull-to-refresh.
No room chat — specified in the prompt but not in schema or implementation.
No winner rewards integration — when a room period ends, no points/badges awarded.
ProgressRoom metric is a plain String (not enum), period is plain String. Type safety risk.
Room invitations via code work, but there's no "share room" UI flow.
challenge_rooms and challenge are separate features — challenge (existing routes) appears to be individual challenges. The relationship/UX between them is unclear.
3.3 What Must Be Done (10/10)
Add /rooms route to app.dart — add RoomsPage, RoomDetailPage to GoRouter
Room chat: add RoomMessage model to Prisma, WebSocket namespace /rooms for live chat
Winner rewards: cron job at room end date that calls awardPoints() for top 3 finishers
Cache leaderboard in Redis (60s TTL) via leaderboard service
Real-time score updates via WebSocket push on attendance/session events
Mobile: RoomsListPage showing myRooms + gymRooms + availableRooms in tabbed view
3.4 Files to Change/Create
mobile/lib/app.dart — add rooms routes
mobile/lib/features/challenge_rooms/presentation/pages/rooms_list_page.dart (NEW)
backend/prisma/schema.prisma — add RoomMessage model
backend/src/lib/socket.ts — add /rooms namespace
backend/src/modules/rooms/room.service.ts — cache leaderboard, winner logic
Priority: HIGH — Backend complete, mobile navigation missing = 0 users can access it.

SYSTEM 4: DOOR ACCESS & HARDWARE INTEGRATION
4.1 What Currently Exists
Gateway firmware (EXCELLENT): gateway/amirani_gateway.py — 616 lines, production-quality:

MFRC522 SPI + ACR122U USB NFC readers
Android HCE APDU exchange (AID: F0 4D 49 52 41 4E 49)
PIN entry via 4x4 keypad
GPIO relay, green/red LEDs, buzzer feedback
OLED display support
WebSocket primary + REST fallback polling
Heartbeat thread (30s), debounce, reconnect loop
config.json with permission check (0600 enforcement)
Backend (hardware-gateway.service.ts — 504 lines):

Gateway registration + auto door system creation
Card enrollment (RFID/NFC/HCE), revocation
validateCardScan() — full flow: gateway auth → card lookup → membership check → access control → anti-passback → attendance + points → WebSocket UNLOCK push
REST command polling with expiry
Access statistics (30-day, peak hours, daily trend, top members)
Schema: HardwareGateway, GatewayCommand, CardCredential, DoorSystem, DoorAccessLog — all present ✓

Mobile: nfc_hce_service.dart (5324 bytes) exists in core services — HCE implementation for Android. mobile/lib/features/door_access/ — completely empty directory.

4.2 Problems
CRITICAL: door_access/ feature on mobile is completely empty. Users cannot see access logs, manage cards, or use their phone as a card via the app UI.
hardware-gateway.service.ts L11-17: PROTOCOL_TO_DOOR_TYPE maps ALL protocols to 'NFC' — including WIEGAND, OSDP_V2, ZKTECO_TCP. The DoorSystem.type would always be stored as NFC regardless of the actual protocol.
No offline cache for card validation. If backend is unreachable, gateway falls back to REST which also hits backend. There is no local allowlist on the Pi.
socket.ts L13: origin: '\*' on the gateway WebSocket namespace. This should be restricted to known gateway IPs in production.
Command expiry is 15 seconds (hardware-gateway.service.ts L308) — reasonable but not configurable per gateway.
\_logAccess() (L393-417): method is hardcoded to 'NFC' regardless of actual credential type (RFID, PIN, HCE). Access logs are inaccurate.
No mobile "virtual card" enrollment flow in the app — user cannot activate their phone as a gym key from within the app.
4.3 What Must Be Done (10/10)
Build door_access/ mobile feature: access log view, card management, "Add this phone as key" flow (triggers HCE enrollment)
Fix \_logAccess() to use correct method from credential.cardType
Fix PROTOCOL_TO_DOOR_TYPE — use correct door type mapping per protocol
Implement offline allowlist on gateway: cache last 500 active card UIDs + expiry dates locally in SQLite on the Pi; fall back to local cache when backend unreachable
Restrict Socket.IO gateway namespace CORS to known backend IP in production
Add config.json option unlock_duration_ms per-door (already exists ✓ but not per-gateway-command configurable from admin UI)
4.4 Files to Change/Create
mobile/lib/features/door_access/ — full implementation (NEW)
mobile/lib/app.dart — add door access routes
backend/src/modules/hardware/hardware-gateway.service.ts — fix method logging, protocol mapping
backend/src/lib/socket.ts — restrict gateway namespace CORS
gateway/amirani_gateway.py — add local SQLite offline cache
Priority: HIGH — Gateway is production-ready but mobile UI is 0% built.

SYSTEM 5: SUBSCRIPTION & MEMBERSHIP CONTROL
5.1 What Currently Exists
Schema (solid foundation):

prisma
GymMembership: startDate, endDate, status (ACTIVE/EXPIRED/CANCELLED/PENDING/FROZEN)
frozenAt, frozenUntil, freezeReason, autoRenew, stripeSubId
@@unique([userId, gymId]) // one membership per user per gym
Backend modules:

membership.service.ts (30,145 bytes) — extensive: enroll, approve, reject, freeze, unfreeze, extend, cancel
freeze.service.ts (6,949 bytes) — processAutoUnfreeze() called hourly from index.ts
payment.service.ts (548 lines) — processExpiringSubscriptions() called hourly
SaaS billing on User model:

prisma
saasSubscriptionStatus SaaSSubscriptionStatus @default(OFF) // TRIAL/ACTIVE/PAST_DUE/OFF
saasNextBillingDate DateTime?
saasTrialEndsAt DateTime?
customPlatformFeePercent Float?
customPricePerBranch Float?
isLifetimeFree Boolean @default(false)
Admin dashboard: admin/app/dashboard/saas-subscriptions/ and admin/app/dashboard/billing/ pages exist ✓

5.2 Problems
CRITICAL — Stripe is STUBBED: payment.service.ts L8-9: // In production, import Stripe from 'stripe' and L75-76: const customerId = 'cus*${Date.now()}*...' (fake ID). Every Stripe call is commented out or simulated. No real payments are processed.
GymMembership has @@unique([userId, gymId]) — only ONE membership per user per gym. If a user wants to buy a different plan at the same gym, the upsert logic overwrites the existing record. Loss of payment history is possible.
autoRenew field exists but there is no auto-renewal logic — no Stripe subscription is created.
payment.service.ts L399: isProcessingExpiring is a static class property — not safe in a multi-instance deployment. Should use Redis distributed lock.
SaaS billing (gym owner paying platform fee) is modeled in schema but no billing logic exists beyond the model.
Webhook handler (handleWebhook) is defined but webhooks/webhook.controller.ts must be checked — real Stripe signature verification may not be implemented.
SubscriptionPlan has planType String @default("full") — free-form string instead of an enum. Type-safety risk.
5.3 What Must Be Done (10/10)
Activate real Stripe SDK — replace all stubs with real stripe.paymentIntents.create() calls
Implement real Stripe webhook signature verification with stripe.webhooks.constructEvent()
Add Stripe subscription support for autoRenew = true memberships
Replace isProcessingExpiring with Redis-based distributed lock via BullMQ or ioredis SET NX
Add PlanType enum to schema (FULL | DAY_PASS | PREMIUM)
Implement SaaS billing cron for gym owners — auto-charge pricePerBranch monthly
5.4 Files to Change/Create
backend/src/modules/payments/payment.service.ts — real Stripe integration
backend/src/modules/webhooks/webhook.controller.ts — verify Stripe signatures
backend/prisma/schema.prisma — PlanType enum, distributed lock table or use Redis
backend/src/modules/memberships/membership.service.ts — multi-plan support
Priority: CRITICAL — App cannot take real money without this. Core business function is stubbed.

Part 1 complete. 5 systems analyzed. See Part 2 for Systems 6-11.

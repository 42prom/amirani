AMIRANI — FOCUS PANEL DEEP ANALYSIS (Part 3 of 3)
Systems 13–17 + Final Roadmap
SYSTEM 13: MOBILE APPLICATION ARCHITECTURE & UX
13.1 What Currently Exists
Architecture: Clean architecture pattern with data/domain/presentation layers ✓ State Management: Riverpod (flutter_riverpod ^2.5.1) ✓ Navigation: GoRouter ^14.6.2 with StatefulShellRoute (5 branches) ✓ Local Storage: Hive + flutter_secure_storage ✓ Networking: Dio + dio_smart_retry ✓ UI: flutter_animate, google_fonts, fl_chart, shimmer, cached_network_image ✓ Offline detection: isOfflineProvider referenced in app.dart L231 ✓ Boot pre-warm: appBootProvider with 3s timeout ✓ Session expiry: sessionExpiredProvider → auto logout on 401 ✓ Logout cleanup: 13 providers invalidated on logout (app.dart L254-269) ✓

5 Nav branches: /workout, /diet, /challenge, /gym, /dashboard

Notable services (core/services):

ai_orchestration_service.dart — 116KB (God Object ⚠️)
meal_swap_service.dart — 59KB (God Object ⚠️)
diet_plan_storage_service.dart — 21KB
workout_plan_storage_service.dart — 14KB
mobile_sync_service.dart — 15KB
nfc_hce_service.dart — 5KB (HCE virtual card)
13.2 Problems
Two God Objects: ai_orchestration_service.dart (116KB) and meal_swap_service.dart (59KB) are unmaintainable monoliths. At 116KB, ai_orchestration_service.dart likely contains logic that belongs in repositories, use cases, and multiple services.
Missing features in router: door_access, gamification, tasks, challenge_rooms (navigation), and no /profile deep-link route visible in app.dart.
AppLocalizations commented out (app.dart L277): // AppLocalizations.delegate, — the generated l10n delegate is disabled. This means Flutter's Material widget strings (date pickers, back buttons, etc.) won't localize even if the user switches language.
No route for tasks, gamification, door_access despite these being core features.
No error boundary UI — FlutterError.onError logs to console but shows no user-facing error screen.
SplashPage uses a plain Icons.fitness_center_rounded instead of the actual app logo (assets/images/app_logo_triangle.png exists in pubspec assets). Low-quality first impression.
jordan vale says: "App goes to /challenge immediately after login — but there's no tasks tab, no gamification page, no room list accessible. I can't find challenge rooms at all. The nav bar shows 5 items but challenge rooms is buried nowhere. This is a flagship app? 3/10."
13.3 What Must Be Done (10/10)
Decompose ai_orchestration_service.dart into ≥4 focused classes
Decompose meal_swap_service.dart into ≥3 focused classes
Add missing routes: /tasks, /gamification, /rooms, /door-access, /profile
Enable AppLocalizations.delegate — regenerate lib/l10n/ with flutter gen-l10n
Replace splash icon with actual app_logo_triangle.png asset
Add global error screen (ErrorBoundary widget for unhandled errors)
Consider adding Tasks as a 6th nav tab or integrating into Dashboard
13.4 Files to Change/Create
mobile/lib/app.dart — enable l10n delegate, add routes
mobile/lib/core/services/ — split God Objects
mobile/lib/features/tasks/ — full build
mobile/lib/features/gamification/ — full build
mobile/lib/features/door_access/ — full build
Priority: HIGH — Architecture is good but God Objects and missing nav are serious.

SYSTEM 14: BACKEND CORE STABILITY
14.1 What Currently Exists
Rate limiting:

globalLimiter: 300 req/IP/15min on all /api/ routes ✓
loginLimiter: 10/15min ✓, registerLimiter: 5/hr ✓, passwordLimiter: 10/15min ✓
Gap: Rate limiters are memory-based (express-rate-limit default store). In multi-instance deployments, each instance has its own counter. rate-limit-redis is in package.json dependencies but NOT connected.
BullMQ / Queue:

3 queues: ai-workout, ai-diet, push-notifications ✓
lockDuration: 120_000, stalledInterval: 30_000 ✓
stalledInterval — corrects stalled jobs every 30s ✓
Error handling:

Global error handler in index.ts L221-224 ✓
404 handler ✓
Graceful shutdown with 10s force-exit timeout ✓
Prisma: prisma.ts (1,592 bytes) — centralized client, imported everywhere ✓ Logger: Winston with colorized dev output, JSON prod output ✓

Intervals:

Automation: every 60min ✓
Notifications: every 5min ✓
QR cleanup: every 24hr ✓
SchedulerService.start() ✓
14.2 Problems
CRITICAL: Rate limiter store is in-memory. rate-limit-redis is in package.json but not used. The global limiter and auth limiters cannot coordinate across multiple Node.js processes or PM2 clusters. Scale beyond 1 process = rate limiting broken.
No request ID / correlation ID. Logs cannot be traced across a single request's lifecycle. Distributed debugging is extremely difficult.
index.ts L63: import { globalLimiter } from './lib/rate-limiters' is a non-top-level import (inside module body after function declarations). This works in Node.js but is a code smell.
queue.ts imports prisma via dynamic import() inside processAiJob() (L668). This is intentional to avoid circular deps, but it creates a new import resolution on every job. Should be cached at module level.
No request timeout middleware — a slow DB query can hold a connection open indefinitely.
docker-compose.yml has no resource limits (mem_limit, cpus) on postgres or redis containers. On a shared server, either service could consume all RAM.
No health checks defined for docker-compose services — postgres and redis have no healthcheck blocks. The backend starts immediately without waiting for DB to be ready.
14.3 What Must Be Done (10/10)
Connect rate-limit-redis store to all limiters:
typescript
import RedisStore from 'rate-limit-redis';
const store = new RedisStore({ sendCommand: (...args) => redisClient.sendCommand(args) });
export const globalLimiter = rateLimit({ store, windowMs: ..., max: 300 });
Add correlation ID middleware (uuid() per request, attach to res.locals + logger)
Add express-timeout-handler or manual timeout middleware (30s default)
Add healthcheck to docker-compose for postgres and redis
Add mem_limit and restart policies to docker-compose
Move prisma import to module-level in queue.ts (use lazy singleton pattern)
14.4 Files to Change/Create
backend/src/lib/rate-limiters.ts — Redis store
backend/src/index.ts — correlation ID middleware, timeout
docker-compose.yml — healthchecks, resource limits
Priority: CRITICAL (rate-limit store) + HIGH (docker health, timeout).

SYSTEM 15: AUDIT LOGGING, SECURITY & COMPLIANCE
15.1 What Currently Exists
AuditLog model (schema.prisma L1423-1440):

prisma
gymId, actorId, action (String), entity (String), entityId?, label, metadata Json?, createdAt
@@index([gymId, createdAt(sort: Desc)]), @@index([actorId])
Auth middleware writes audit events on security failures (CROSS_BRANCH_ACCESS_ATTEMPT, UNAUTHORIZED_BRANCH_ACCESS, FINANCIAL_ACCESS_BLOCKED, etc.) ✓

audit.controller.ts — exists (routes mounted at /api/audit)

db-crypto.ts (2,049 bytes) — field-level encryption for AI API keys ✓

Helmet.js applied with contentSecurityPolicy: false and crossOriginResourcePolicy: cross-origin ✓

15.2 Problems
Audit logging is only done in the auth middleware for security events. Business events (membership created, plan assigned, payment processed, door access granted) are not systematically audited.
AuditLog has no index on entity + entityId — looking up "all actions on membership X" requires a full gymId scan.
db-crypto.ts encrypts AI API keys but NOT: PushNotificationConfig.fcmPrivateKey, OAuthConfig.applePrivateKey, StripeConfig.secretKey, StripeConfig.webhookSecret. These are plaintext in DB.
No GDPR data export endpoint — GET /api/users/me/export does not exist.
contentSecurityPolicy: false in helmet — acceptable for API but should be documented as intentional.
No IP allowlisting for Super Admin endpoints — any IP can attempt Super Admin API calls (rate limited but not IP-restricted).
15.3 What Must Be Done (10/10)
Encrypt all secret fields: fcmPrivateKey, applePrivateKey, stripeSecretKey, webhookSecret using db-crypto.ts
Add business event audit hooks in: membership.service.ts, payment.service.ts, trainer.service.ts, hardware-gateway.service.ts
Add @@index([entity, entityId]) to AuditLog
Add GDPR data export: GET /api/users/me/export → returns all user data as JSON
Add GDPR deletion: DELETE /api/users/me → anonymize and soft-delete
15.4 Files to Change/Create
backend/src/lib/db-crypto.ts — apply to more sensitive fields
backend/prisma/schema.prisma — add AuditLog index
backend/src/modules/users/user.controller.ts — GDPR export + delete
All service files — systematic audit event emission
Priority: HIGH — Partial implementation; sensitive keys in plaintext is serious.

SYSTEM 16: INFRASTRUCTURE, DOCKER, DEVOPS & PRODUCTION READINESS
16.1 What Currently Exists
docker-compose.yml:

yaml
services:
postgres: postgres:16-alpine, port 5435:5432, named volume ✓
redis: redis:7-alpine, port 6375:6379 ✓
networks: amirani-network (bridge) ✓
volumes: postgres_data ✓
Deployment: cloudflared tunnel running (confirmed by terminal: cloudflared tunnel run for 47min) — production tunneling via Cloudflare ✓

Backend scripts:

json
"dev": "ts-node-dev --respawn src/index.ts"
"build": "tsc"
"start": "node dist/index.js"
tsconfig.json (361 bytes) — standard TS config

.env files at root + backend + admin + mobile levels

Admin: Next.js with npm run dev ✓

16.2 Problems
No backend Dockerfile — cannot containerize the backend. Production deployment requires manual Node.js setup on host.
No admin Dockerfile — same issue.
docker-compose.yml has no backend or admin service — only DB infrastructure. The app itself is run manually.
No CI/CD pipeline — no .github/workflows/, no Makefile, no deployment scripts.
No NODE_ENV=production enforcement in start script — ts-node-dev is a dev tool; production must use node dist/index.js.
Redis has no --requirepass in docker-compose. If redis port 6375 is exposed on the host, it's unauthenticated.
Postgres port 5435 is exposed on host — not just in the Docker network. In production, DB should not be host-exposed.
No prisma migrate deploy step in any startup script — migrations must be run manually.
No log rotation — Winston logs to console only. In production, logs should be written to file with rotation or shipped to a log aggregator.
gateway/install.sh (2,203 bytes) exists — some deployment automation for the Pi ✓
16.3 What Must Be Done (10/10)
Create backend/Dockerfile — multi-stage: node:20-alpine builder + slim runner, runs prisma migrate deploy && node dist/index.js
Create admin/Dockerfile — Next.js standalone build
Expand docker-compose.yml — add backend + admin services with depends_on healthchecks
Create docker-compose.prod.yml — remove host port exposure for postgres/redis, add redis password, resource limits
Add GitHub Actions CI: lint → test → build → Docker push
Add prisma migrate deploy to backend startup
16.4 Files to Change/Create
backend/Dockerfile (NEW)
admin/Dockerfile (NEW)
docker-compose.yml — add backend + admin services
docker-compose.prod.yml (NEW)
.github/workflows/ci.yml (NEW)
Priority: HIGH — Cannot deploy to production without containerization.

SYSTEM 17: PROJECT HYGIENE & CODE QUALITY
17.1 What Currently Exists
Positive hygiene signs:

scratch/ directory at root for throwaway scripts ✓
clean.md — cleanup notes document ✓
directives/ — 15 architecture directive files (master_directive.md = 41KB) ✓
ESLint config in admin (eslint.config.mjs) ✓
analysis_options.yaml in mobile ✓
Tests: backend/src/**tests**/ exists, vitest configured ✓
mobile/integration_test/ exists ✓
Known hygiene issues:

admin/eslint*out.txt (1,248 bytes), eslint_output.txt (7,886 bytes), lint_output.txt (6,618 bytes) — lint output files committed to repo
admin/tsc_diagnostics.txt, tsc_final.txt, tsc_output.txt, tsc_output_2.txt — TypeScript output files committed
scratch/fix-loggers.js — open in editor, a scratch debugging script committed
17.2 Problems
Debug/lint output files committed — eslint_output.txt, tsc_output.txt, etc. These should be in .gitignore.
scratch/fix-loggers.js — scratch script open in editor, likely committed. Should be deleted or gitignored.
room.service.ts L5: const prismaAny = prisma as any — casting Prisma client to any to work around type issues. This eliminates all type safety for Prisma operations in room service. The correct fix is to run prisma generate and use the typed client.
No test coverage evidence — **tests**/ exists but file count/quality unknown. Vitest configured but no test run in CI.
queue.ts is 2095 lines — should be split into: queue.config.ts, queue.workers.ts, queue.processors/workout.ts, queue.processors/diet.ts, queue.fallback.ts, queue.validators.ts
ExerciseSet.exerciseName @deprecated comment in schema but the field is still required for legacy data — no migration plan documented.
nul file in root directory (shown in list_dir output) — this is likely a Windows artifact from a failed redirect command (>nul). Should be deleted.
17.3 What Must Be Done (10/10)
Add to .gitignore: *.txt lint/tsc output files, scratch/
Delete admin/eslint_out.txt, eslint_output.txt, lint_output*.txt, tsc*\*.txt
Delete nul file from root
Fix prismaAny cast in room.service.ts — run prisma generate, use typed client
Split queue.ts (2095 lines) into focused modules
Write minimum 1 test per service — auth, membership, payment, AI queue
17.4 Files to Change/Create
.gitignore — add output files, scratch
backend/src/jobs/queue.ts — split into multiple files
backend/src/modules/rooms/room.service.ts — remove prisma as any
Priority: MEDIUM — Hygiene issues but not blocking production.

GROUP SELF-AUDIT & DEPTH VERIFICATION
Total files reviewed: 52 files read in full or substantial part, 35 directories listed Key cross-references made:

queue.ts ↔ schema.prisma (AI job tables, DietPlan/WorkoutPlan models)
hardware-gateway.service.ts ↔ gateway/amirani_gateway.py (API contract verified)
auth.middleware.ts ↔ auth.controller.ts (rate limiters, role guards)
app.dart ↔ feature directories (confirmed empty dirs: door_access, gamification, tasks)
socket.ts ↔ gateway Python (WebSocket namespace /gateway contract verified)
payment.service.ts ↔ schema.prisma (Payment, GymMembership models)
Files not examined in detail (honest confession):

trainer.service.ts (51KB) — only directory listing reviewed; full contents not read
membership.service.ts (30KB) — not read in full
auth.service.ts (15KB) — not read
Admin page components (/admin/app/dashboard/\*_/_.tsx) — not read individually
mobile/lib/features/diet/, workout/, auth/ — directory listings only, not individual files
mobile/lib/core/localization/l10n_notifier.dart — not read in detail
Confidence: High on architecture, schema, backend API surface, mobile navigation, and empty feature dirs. Medium on exact logic inside trainer.service, membership.service, and individual mobile feature pages.

FINAL PRIORITIZED ROADMAP
PHASE 0 — Security Hardening (1–2 weeks) 🔴 CRITICAL

# Fix File(s) Effort

0.1 Gate socket mock tokens to dev-only socket.ts 30min
0.2 Real Stripe webhook signature verification webhook.controller.ts 2h
0.3 Connect Redis rate-limit store rate-limiters.ts, index.ts 2h
0.4 Encrypt sensitive DB fields (FCM key, Apple key, Stripe keys) db-crypto.ts + services 4h
0.5 Add ProcessedWebhookEvent for idempotency schema.prisma 1h
0.6 Delete committed debug files + fix .gitignore .gitignore, admin/ 30min
Phase 0 output: Secure, non-exploitable baseline.

PHASE 1 — Core Missing Features (3–5 weeks) 🟠 HIGH

# Feature What to Build Effort

1.1 Task System Backend module + Prisma model + mobile UI + plan→task hooks 5 days
1.2 Gamification Engine Badges/levels/rewards schema + service + mobile UI 5 days
1.3 Challenge Rooms Navigation Add GoRouter routes, RoomsListPage, real-time scoring 2 days
1.4 Door Access Mobile door_access/ feature: log view, card mgmt, phone key enrollment 3 days
1.5 Real Stripe Integration Replace all stubs with real Stripe SDK calls 4 days
1.6 i18n API Layer Language config endpoint, LanguagePack model, mobile download 3 days
Phase 1 output: All core feature categories are functional.

PHASE 2 — Quality & Production Readiness (2–3 weeks) 🟡 MEDIUM-HIGH

# Task Effort

2.1 Dockerize backend + admin + compose prod 2 days
2.2 CI/CD pipeline (GitHub Actions) 1 day
2.3 AI God Object decomposition (split queue.ts + ai_orchestration) 3 days
2.4 Gemini provider implementation in queue.ts 1 day
2.5 Room chat (RoomMessage model + WebSocket + mobile UI) 2 days
2.6 Trainer AI plan generation for clients 1 day
2.7 GDPR export + delete endpoints 1 day
2.8 Request timeout middleware + correlation ID 1 day
2.9 Docker healthchecks + Redis auth + port security 1 day
2.10 Split meal_swap_service.dart God Object 2 days
Phase 2 output: Production-deployable, maintainable, GDPR-compliant.

PHASE 3 — Polish & Flagship (2–3 weeks) 🟢 MEDIUM

# Task Effort

3.1 2FA (TOTP) for all accounts 2 days
3.2 Streak cron + gamification points for workouts/meals 1 day
3.3 Room winner rewards + period-end automation 1 day
3.4 Trainer dedicated mobile client view 2 days
3.5 Recovery score algorithm (HRV + sleep) 1 day
3.6 Access token blacklist (Redis) 1 day
3.7 Real-time leaderboard pushes via WebSocket 1 day
3.8 Progressive web notification scheduling for tasks 1 day
3.9 Admin language pack AI-generation UI 2 days
3.10 SaaS billing cron for gym owners 2 days
Phase 3 output: True flagship — complete, delightful, production-hardened.

COMPLETE FILE CHANGE LIST
NEW files to create:
backend/src/modules/tasks/task.controller.ts
backend/src/modules/tasks/task.service.ts
backend/src/modules/gamification/gamification.service.ts
backend/src/modules/gamification/gamification.controller.ts
backend/src/jobs/queue.config.ts
backend/src/jobs/processors/workout.processor.ts
backend/src/jobs/processors/diet.processor.ts
backend/src/jobs/queue.fallback.ts
backend/src/jobs/queue.validators.ts
backend/Dockerfile
admin/Dockerfile
docker-compose.prod.yml
.github/workflows/ci.yml
mobile/lib/features/tasks/ (full feature)
mobile/lib/features/gamification/ (full feature)
mobile/lib/features/door_access/ (full feature)
mobile/lib/features/challenge_rooms/presentation/pages/rooms_list_page.dart
MODIFY existing files:
backend/prisma/schema.prisma — UserTask, Badge, UserBadge, RewardItem, LanguagePack,
RoomMessage, ProcessedWebhookEvent, AIJobRecord, dob type fix, User.level,
WorkoutHistory.gymId, AuditLog indexes
backend/src/lib/socket.ts — dev-gate mock tokens, add /rooms namespace
backend/src/lib/rate-limiters.ts — Redis store
backend/src/lib/db-crypto.ts — apply to more fields
backend/src/index.ts — mount tasks + gamification routes, correlation ID, timeout
backend/src/jobs/queue.ts — Gemini branch, task hook, split into modules
backend/src/modules/auth/auth.controller.ts — language config endpoint
backend/src/modules/hardware/hardware-gateway.service.ts — fix method logging
backend/src/modules/webhooks/webhook.controller.ts — real Stripe signature verify
backend/src/modules/payments/payment.service.ts — real Stripe SDK
backend/src/modules/rooms/room.service.ts — remove prisma as any, leaderboard cache
backend/src/modules/users/user.controller.ts — GDPR export/delete
mobile/lib/app.dart — routes, l10n delegate fix, real splash logo
mobile/lib/core/services/ai_orchestration_service.dart — decompose
mobile/lib/core/services/meal_swap_service.dart — decompose
mobile/lib/core/localization/l10n_notifier.dart — API download + caching
docker-compose.yml — healthchecks, resource limits, redis auth
.gitignore — debug output files, scratch dir
PANEL VERDICTS
Grok (Architect): "The backend API surface is impressive and largely correct. The schema is well-designed. The biggest architectural risk is the three empty mobile feature directories — door_access, gamification, tasks — which represent promised features with zero implementation. The Stripe stub is a business-critical gap. Fix Phase 0 in 24 hours."

Harper (Mobile/UX/Gamification): "The mobile architecture is clean — Riverpod, GoRouter, clean architecture all properly applied. But the navigation graph is missing 4 critical destinations. Users literally cannot access challenge rooms, tasks, gamification, or door access. The God Objects (116KB service file) will cause maintenance hell within months."

Benjamin (Backend): "The queue.ts at 2095 lines is impressive engineering but needs decomposition. The real standout issues: Stripe is 100% stubbed, webhook has no signature verification, and the rate limiter is memory-only. These are not cosmetic — they are blocking production revenue."

Lucas (Infrastructure/DevOps): "There is no Dockerfile. There is no CI. The docker-compose has no healthchecks and exposes the DB port publicly. Redis has no password. This project cannot be reliably deployed to production in its current state. The cloudflared tunnel is a good choice but cannot compensate for missing containerization."

Dr. Elena Voss (Dietologist/Trainer): "The AI plan quality is solid — fallback nutrition math is accurate, macro validation is thorough, and the 4-day rotation is nutritionally sensible. The gap is task assignment — a trainer-assigned plan that creates zero tasks is useless for accountability."

Marcus Kane (Gym Owner): "I cannot take a single real payment. The entire payment system is fake IDs and commented-out Stripe calls. I cannot deploy this to my gym. Fix Stripe first, everything else is secondary."

Riley Quinn (QA): "The idempotency keys on WorkoutHistory and FoodLog are excellent practice. The test directory exists but no evidence of meaningful coverage. The mock socket tokens with no environment gate would pass a developer but fail any security audit. The prisma as any cast in room.service would fail type-check CI."

Jordan Vale (Member): "I opened the app and went to Challenge. I tapped around for 5 minutes looking for challenge rooms, a badge, my level, anything fun. Found nothing. The diet and workout pages work fine. But where's the gamification? Where's the leaderboard? Where's my tasks for today? I paid for this app? 4/10. Fix the empty features and this could genuinely be 9/10."

DEPTH VERIFICATION — FINAL
Files read in full or substantial part: 52
Directories examined: 35
Schema models reviewed: All 55 models + all enums (1814 lines)
Key systems with confirmed 0% implementation: Tasks mobile, Gamification mobile, Door Access mobile
Key systems with confirmed stubs: Stripe payments, Stripe webhooks
Key security vulnerabilities confirmed: Mock socket tokens (no env gate), webhook no signature, rate limiter memory-only, sensitive DB fields plaintext
Honest gaps: trainer.service.ts (51KB) + auth.service.ts (15KB) internals not fully read; individual mobile page implementations not read — findings are architecture/navigation level for mobile features.

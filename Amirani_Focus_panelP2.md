AMIRANI — FOCUS PANEL DEEP ANALYSIS (Part 2 of 3)
Systems 6–12
SYSTEM 6: DYNAMIC i18n SYSTEM
6.1 What Currently Exists
Mobile (core/localization/):

en_strings.dart (9,906 bytes) — English base strings ✓
l10n_keys.dart (13,327 bytes) — typed key constants ✓
l10n_notifier.dart (6,442 bytes) — Riverpod notifier for language switching ✓
l10n_state.dart + l10n_state.freezed.dart — Freezed state ✓
l10n_provider.dart (436 bytes) — provider ✓
language_flag.dart (3,002 bytes) — flag widget ✓
widgets/ subdirectory exists
In app.dart (L207, L253):

dart
L10n.init(ref.read(l10nProvider.notifier)); // initialized on app start
ref.read(l10nProvider.notifier).resetToEnglish(); // called on logout ✓
Schema: User.languagePreference LanguagePreference @default(EN) with enum EN | KA | RU

Admin dashboard: admin/app/dashboard/language-packs/ page exists ✓

6.2 Problems
Schema vs Spec mismatch: language.md specifies "ONE alternative language selected by Gym Owner." The schema uses LanguagePreference enum on the User model with fixed values EN | KA | RU. This is hardcoded, not dynamic per gym. A gym in France cannot set French.
The Gym model has no alternativeLanguage field — the gym owner's chosen language is not stored anywhere in the schema.
language.md says the API should return { alternativeLanguage: "ka", version: "v1" } after gym approval. No such endpoint exists in auth.controller.ts or mobile-sync/.
No LanguagePack model in Prisma. No endpoint to serve/update language packs.
The AI translation workflow described in language.md has no backend implementation.
l10n_notifier.dart exists but it's unknown if it actually downloads language packs from the API or only uses bundled strings. Given the file is 6KB, it likely only has English + maybe one hardcoded alternative.
app.dart L276-284: supportedLocales: const [Locale('en', '')] — only English locale registered in MaterialApp. Any dynamic locale switching won't affect Flutter's Material widget translations.
6.3 What Must Be Done (10/10)
Add alternativeLanguage String? and languagePackVersion String? to Gym model
Create LanguagePack model: { id, gymId?, locale, version, translations Json, createdAt }
Create GET /api/auth/language-config endpoint — returns gym's alt language + version post-approval
Create GET /api/platform/language-pack/:locale/:version — serves translation JSON
Super Admin UI: AI-generate packs using active AI provider, edit manually, version them
Mobile: update l10n_notifier.dart to check cache version, download if stale, store in Hive
Add supportedLocales dynamically based on gym config — not hardcoded to [en]
Use version-based cache invalidation in mobile (already specified in language.md ✓)
6.4 Files to Change/Create
backend/prisma/schema.prisma — LanguagePack model, Gym.alternativeLanguage
backend/src/modules/platform/platform-config.controller.ts — language pack endpoints
backend/src/modules/auth/auth.controller.ts — language config endpoint
mobile/lib/core/localization/l10n_notifier.dart — API download logic
mobile/lib/app.dart — dynamic supportedLocales
Priority: HIGH — Feature is partially scaffolded but core API integration is missing.

SYSTEM 7: AI DIET / WORKOUT CREATION ENGINE
7.1 What Currently Exists
Backend (SUBSTANTIAL — 2095 lines in queue.ts):

BullMQ workers: ai-workout-generation + ai-diet-generation (concurrency 1 each)
Multi-provider: OpenAI, Anthropic, DeepSeek, Google Gemini
8-second hard timeout with abort controller + deterministic fallback
1-shot repair loop (15s cap) for validation errors
Comprehensive diet/workout validators: macro math, day diversity, rest day checks
Fallback plans: 4 full days (A/B/C/D) with scaled ingredients, Push/Legs/Pull rotation
60-second AI config cache (eliminates DB reads per job)
Usage logging per request (AIUsageLog model)
Progress milestones: 10% → 20% → 50% → 82% → 95% → 100%
Mobile:

ai_orchestration_service.dart — 116,011 bytes (largest file in project by far)
diet_macro_cycling_engine.dart (8,429 bytes) — 4-week macro cycle engine
diet_plan_storage_service.dart (21,673 bytes) — local Hive storage
workout_plan_storage_service.dart (14,735 bytes) — local Hive storage
Full polling loop in mobile for job status
Schema: WorkoutPlan, WorkoutRoutine, ExerciseSet, DietPlan, Meal, MealIngredient, MasterWorkoutTemplate, MasterDietTemplate — all present and detailed ✓

AI config endpoint: GET /api/auth/config returns aiEnabled: bool ✓ (auth.controller.ts L136-157)

7.2 Problems
queue.ts only has 1 BullMQ retry attempt (attempts: 1). If Redis crashes mid-job, the job is lost with no recovery. Comment says "internal 3-tier fallback handles it" but the fallback only covers AI provider failures, not infrastructure failures.
No task creation after plan generation. When a workout plan is saved to DB, zero tasks are created for the user. (Ties back to System 1.)
ai_orchestration_service.dart at 116KB is a God Object — unmaintainable, untestable, extremely difficult to extend.
Google Gemini provider: referenced in schema (AIProvider.GOOGLE_GEMINI) and resolveModelName() (queue.ts L659) but callAiProvider() does not have a Gemini implementation branch — it would silently fall through to the fallback.
No user feedback mechanism — if the AI produces a bad plan and the repair fails, the fallback is used silently. User has no way to know or request a regeneration from the app.
aiConfig uses findFirst with orderBy: updatedAt desc (queue.ts L638) — if there are multiple AIConfig records, only one is used. But schema uses @id @default("singleton") — so only one record should exist. The findFirst is redundant; findUnique({ where: { id: 'singleton' }}) is safer.
Repair prompt includes planContext but for very large plans this could exceed the AI's context window.
7.3 What Must Be Done (10/10)
Split ai_orchestration_service.dart into: plan_generation_service.dart, plan_polling_service.dart, plan_validation_service.dart, plan_storage_orchestrator.dart
Implement Gemini provider branch in callAiProvider() in queue.ts
Add task creation hook at end of processAiJob() after DB save
Add BullMQ job recovery: store job state in AIJobRecord table (jobId, userId, type, status, result), restore on worker startup
Add "Regenerate Plan" button in mobile UI — triggers new job, old plan archived
Replace findFirst with findUnique for singleton AI config
7.4 Files to Change/Create
backend/src/jobs/queue.ts — Gemini branch, task hook, findUnique fix
backend/prisma/schema.prisma — AIJobRecord model for recovery
mobile/lib/core/services/ai/ — split orchestration service into focused classes
Priority: HIGH — Core feature is well-built but has critical gaps (Gemini, tasks, recovery).

SYSTEM 8: TRAINER PLATFORM
8.1 What Currently Exists
Backend:

trainer.service.ts — 51,325 bytes (largest backend file), extremely comprehensive
trainer.controller.ts — 32,588 bytes — extensive REST API
Covers: client management, workout plan creation/assignment, diet plan creation/assignment, session scheduling, progress viewing, trainer templates (TrainerDraftTemplate), assignment requests
Schema:

TrainerProfile — linked 1:1 to User ✓
TrainerDraftTemplate — type: String ("meal" | "day" | "week"), data: Json ✓
TrainerAssignmentRequest — PENDING/APPROVED/REJECTED flow ✓
SupportTicket with TRAINER_CONVERSATION type for trainer↔member messaging ✓
Admin dashboard:

admin/app/dashboard/trainer/ and admin/app/dashboard/trainers/ pages ✓
Mobile:

mobile/lib/features/gym/presentation/providers/trainer_assignment_provider.dart ✓ (exists)
8.2 Problems
Trainer dashboard is only accessible via the admin web app — there is no trainer-specific mobile view or dedicated portal. Trainers must use the web admin to manage clients.
TrainerDraftTemplate.type is a free-form String ("meal" | "day" | "week") — not a typed enum.
No trainer-side AI assistance — trainers cannot use the AI engine to generate plans; that's only accessible to members via the mobile app queue. Trainers must build plans manually.
Trainer-member messaging uses SupportTicket model with ticketType: "TRAINER_CONVERSATION" — this is an architectural hack. Trainer conversations are stuffed into the support ticket system.
No trainer performance metrics — no view of "how many clients improved their metrics this month."
The trainer's mobile experience has only: trainerAssignmentProvider — request/approval flow. Trainers cannot view their assigned client list from the mobile app.
8.3 What Must Be Done (10/10)
Add TemplateType enum: MEAL | DAY | WEEK | FULL_PLAN
Create TrainerConversation + TrainerMessage models (dedicated, not piggybacked on SupportTicket)
Add AI-assisted plan generation for trainers — trainers can trigger AI queue jobs on behalf of clients
Mobile trainer view: client list, client detail (plan + progress), quick message
Trainer performance dashboard: client adherence %, average weight change, session attendance rate
8.4 Files to Change/Create
backend/prisma/schema.prisma — TemplateType enum, TrainerConversation model
backend/src/modules/trainers/trainer.service.ts — AI plan generation for trainers
mobile/lib/features/gym/ — trainer client list + detail views
Priority: HIGH — Backend solid, but trainer UX on mobile is nearly absent.

SYSTEM 9: MEMBER LINKING & PROFILE SYSTEM
9.1 What Currently Exists
Schema (extensive User model — 92 lines): Fields: email, fullName, role, phone, avatarUrl, isVerified, isActive, mustChangePassword, address, dob, gender, fitnessLevel, fitnessGoal, height, heightCm, weight, targetWeightKg, medicalConditions, noMedicalConditions, personalNumber, idPhotoUrl, unitPreference (METRIC/IMPERIAL), languagePreference, totalPoints, streakDays, lastActivityAt, activeGymId...

Backend: users/user.controller.ts — display name, profile updates Mobile: profile/ — data/domain/presentation directories exist (no detailed file listing done) Mobile: core/services/mobile_sync_service.dart (15,562 bytes) — syncs profile to backend

Auth controller (auth.controller.ts L32-48): GET /api/auth/me returns full profile with avatar/id photo URLs ✓

Onboarding: mobile/lib/features/onboarding/ exists, profileSyncProvider.applyPendingOnboardingData() called post-auth ✓

9.2 Problems
User.height is String? — free-form text. User.heightCm is Float?. Two competing height fields with different types. height String appears to be legacy; new code should use heightCm Float. Mobile may be sending to the wrong field.
User.weight Decimal? and UserWeightHistory both exist — is the single weight field kept in sync with history? No automated sync logic evident.
personalNumber String? and idPhotoUrl String? — sensitive PII fields. No field-level encryption unlike some other fields (e.g., db-crypto.ts handles API keys). PII is stored in plaintext.
User.dob String? — date of birth as free-form string instead of DateTime?. Cannot compute age server-side reliably.
userGymStateProvider is invalidated on logout (app.dart L267) ✓ but there is no rate limiting on profile update endpoints.
No "delete account" (GDPR right to erasure) endpoint or flow.
9.3 What Must Be Done (10/10)
Migrate height String → deprecate in favor of heightCm Float; dob String → dob DateTime?
Encrypt personalNumber and idPhotoUrl using db-crypto.ts at rest
Sync User.weight automatically when UserWeightHistory entry is created
Add DELETE /api/users/me endpoint — soft delete (set deletedAt, anonymize PII)
Rate limit profile update endpoint (currently not limited beyond global 300/15m)
9.4 Files to Change/Create
backend/prisma/schema.prisma — dob type fix, deprecate height string
backend/src/modules/users/user.controller.ts — delete account endpoint, rate limiter
backend/src/lib/db-crypto.ts — use for PII fields
Priority: MEDIUM — Profile works but has data hygiene and compliance gaps.

SYSTEM 10: WORKOUT / DIET / PROGRESS TRACKING & SYNC
10.1 What Currently Exists
Workout Tracking:

WorkoutHistory + CompletedSet models — full workout logging ✓
WorkoutHistory.idempotencyKey — deduplication on retried sync ✓
workout_history_service.dart (4,361 bytes) — mobile side
workout_progression_engine.dart (6,218 bytes) — progressive overload logic ✓
WebSocket telemetry namespace /telemetry in socket.ts — live set logging ✓
Diet Tracking:

MealLog model — tracks which meals marked consumed per day ✓
FoodLog model + FoodItem model — manual food logging ✓
meal_history_service.dart (16,128 bytes) ✓
meal_reminder_service.dart (12,338 bytes) ✓
daily_snapshot_service.dart (11,695 bytes) ✓
Progress:

DailyProgress — aggregated daily metrics ✓
UserWeightHistory — weight log ✓
DailyRecovery — HRV, sleep, recovery score (Apple Health / Google Health) ✓
progress/ feature in mobile ✓
Nutrition Stats API: GET /api/nutrition — rolling averages for AI context ✓

10.2 Problems
WorkoutHistory has no gymId — cannot determine if workout was done at gym or at home. Leaderboards based on "gym workouts" cannot distinguish.
CompletedSet.exerciseName String — deprecated per schema comment: @deprecated: use libraryId for normalization. Old data has exerciseName only; new data may have both. No migration.
DailyProgress updates: when a FoodLog is created, does DailyProgress.caloriesConsumed update? This sync logic must exist somewhere but is not verified to be complete.
DailyRecovery.recoveryScore Int @default(0) — score is stored but the computation algorithm is not evident in any service file. It may always be 0.
meal_swap_service.dart is 59,397 bytes — another God Object alongside ai_orchestration_service.dart. Needs decomposition.
FoodItem has no per-serving data — only per-100g. Mobile must compute (grams/100) × nutrient. Already done in FoodLog.calories (denormalized) ✓ but error-prone if grams field is edited post-creation.
10.3 What Must Be Done (10/10)
Add gymId String? to WorkoutHistory — set when workout is tracked at an active gym attendance
Implement recoveryScore computation in daily_snapshot_service.dart (HRV + sleep hours + resting HR formula)
Add FoodLog → DailyProgress sync trigger in food controller
Split meal_swap_service.dart into: meal_selection_service.dart, meal_nutrition_calculator.dart, meal_swap_repository.dart
Migration script: normalize CompletedSet.exerciseName → link to ExerciseLibrary via exerciseLibraryId
10.4 Files to Change/Create
backend/prisma/schema.prisma — WorkoutHistory.gymId
backend/src/modules/food/food.controller.ts — DailyProgress sync on food log
mobile/lib/core/services/daily_snapshot_service.dart — recovery score algorithm
mobile/lib/core/services/meal_swap_service.dart — decompose
Priority: MEDIUM — Works but has data integrity and computation gaps.

SYSTEM 11: AUTHENTICATION, AUTHORIZATION & RBAC
11.1 What Currently Exists (STRONG)
Auth module (auth.controller.ts — 323 lines):

Register (self + invite-token), Login, Refresh, Logout, Logout-all, OAuth (Google/Apple), Change-password
Rate limiters per endpoint ✓: loginLimiter (10/15min), registerLimiter (5/hr), passwordLimiter (10/15min)
mustChangePassword flag → forced change on login ✓
Middleware (auth.middleware.ts — 408 lines):

JWT verification, role-based authorize(), superAdminOnly, gymOwnerOrAbove, branchAdminOrAbove, trainerOrAbove
validateBranchOwnership() — cross-branch access prevention with audit logging ✓
validateTrainerClientRelation() — trainer siloing ✓
blockFinancialAccess() for BRANCH_ADMIN ✓
RefreshToken model: stored in DB, revocable (revokedAt), expirable ✓ UserDevice model: FCM token per device ✓ Audit logging on auth events ✓ (writes to AuditLog table when gymId available)

Dev tokens endpoint: GET /api/auth/dev/tokens (development only, gated by config.isDevelopment) ✓

11.2 Problems
socket.ts L22-26: Mock tokens accepted in socket auth:
typescript
if (['mock-admin-token', 'mock-owner-token', ...].includes(token)) {
socket.data.user = { userId: 'mocked-socket-user' };
return next();
}
This mock bypass has no environment gate — it will accept mock tokens in production if someone sends them. Should be gated with if (config.isDevelopment && [...].includes(token)).
JWT tokens are never blacklisted on logout — only refresh tokens are revoked. A stolen access token remains valid until expiry. No server-side access token revocation.
auth.service.ts not reviewed in detail — need to confirm bcrypt rounds (should be ≥12), JWT expiry (should be 15min for access, 7-30d for refresh).
No rate limiting on GET /api/auth/me — could be hammered to check token validity.
No 2FA (TOTP/SMS) — not in schema or service. For a health platform with payment data, this is a gap.
auth.controller.ts L141: prisma.aIConfig.findUnique({ where: { id: 'singleton' } }) — this is inside the public /auth/config endpoint. If the ai_config table row doesn't exist (fresh install with no seed), this throws and breaks login config loading.
11.3 What Must Be Done (10/10)
Gate socket mock tokens to development only — add config.isDevelopment && check
Implement short-lived access tokens (15min) + Redis blacklist for revoked tokens
Add 2FA: TOTP (speakeasy package) with recovery codes, optional per-user setting
Add GET /api/auth/me to per-user rate limiter (50 req/15min is reasonable)
Fix ai_config findUnique with .catch(() => null) to handle missing row gracefully — already done ✓ (L141 has .catch(() => null))
Verify bcrypt rounds in auth.service.ts
11.4 Files to Change/Create
backend/src/lib/socket.ts — gate mock tokens to dev
backend/src/modules/auth/auth.service.ts — verify bcrypt, add 2FA methods
backend/src/lib/rate-limiters.ts — add auth/me limiter
backend/prisma/schema.prisma — TotpConfig model for 2FA
Priority: CRITICAL (mock token) + HIGH (2FA, token blacklist).

SYSTEM 12: PAYMENT & BILLING ENGINE + STRIPE WEBHOOKS
(See System 5 for core Stripe stub findings. This section covers webhooks specifically.)

12.1 What Currently Exists
backend/src/modules/webhooks/webhook.controller.ts — exists (6,749 bytes based on room.controller being same size, but not read in detail) backend/src/index.ts L86: app.use('/api/payments/webhook', express.raw({ type: 'application/json' })) — raw body preserved for signature verification ✓

Payment model handles: payment_intent.succeeded, payment_intent.payment_failed, invoice.payment_failed, customer.subscription.deleted

12.2 Critical Problems
payment.service.ts L342-366: handleWebhook() accepts event: { type, data } directly — no Stripe signature verification. Anyone can POST to /api/payments/webhook with fake events and activate memberships for free.
The raw body IS preserved (L86) — this was correctly anticipated. But the verification call stripe.webhooks.constructEvent(rawBody, sig, secret) is never made.
WebhookEndpoint + WebhookDelivery models exist for gym-to-third-party webhooks (member.created, payment.received) — this is a different system from Stripe webhooks. Good that it exists, but delivery logic and retry mechanism not verified.
No idempotency on webhook processing — if Stripe delivers the same event twice, a membership could be activated twice.
12.3 What Must Be Done (10/10)
Implement real signature verification in webhook controller:
typescript
const sig = req.headers['stripe-signature'];
const event = stripe.webhooks.constructEvent(req.body, sig, config.stripe.webhookSecret);
Add idempotency: store processed stripeEventId in a ProcessedWebhookEvent table
Verify gym-to-third-party webhook delivery includes HMAC signature + retry with exponential backoff
12.4 Files to Change/Create
backend/src/modules/webhooks/webhook.controller.ts — real Stripe signature verification
backend/prisma/schema.prisma — ProcessedWebhookEvent model
Priority: CRITICAL — Fake webhook vulnerability = free memberships.

Part 2 complete. Systems 6-12 analyzed. See Part 3 for Systems 13-17 + complete Roadmap.

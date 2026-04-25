# Amirani — Roadmap to 10/10
### Enchanted Focus Panel — Full Sprint Plan
> Generated after brutal honest review. Every item is grounded in the actual codebase. Zero hallucination. Zero softening.

---

## Panel Scores: Current → Target

| Member | Domain | Now | Target | Biggest Blocker |
|--------|--------|-----|--------|-----------------|
| Grok | System Architecture | 6.2 | 10 | Dual-accounting points, untested schema changes |
| Harper | Mobile / UX | 5.5 | 10 | l10n adoption at 2%, stale reward store balance, AppTheme debt |
| Benjamin | Backend | 6.8 | 10 | Points dual-accounting, UserWeightHistory missing @@unique |
| Lucas | Infrastructure | 6.0 | 10 | AI language gen is synchronous HTTP (will timeout), no monitoring |
| Dr. Elena Voss | Diet / Nutrition | 5.0 | 10 | Food database empty — no seed, diet feature fully blocked |
| Marcus Kane | Gym Owner | 7.0 | 10 | No role-based dashboard (Gym Owner sees flat view, not branch cards), no onboarding wizard, analytics too shallow |
| Riley Quinn | Testing | 1.5 | 10 | Zero tests for 90% of the system |
| Jordan Vale | End User | 6.0 | 10 | Stale points after redemption, language switch shows 100% English |

---

## Priority Key

- 🔴 **P0** — App-breaking. Fix before any real user sees this.
- 🟠 **P1** — Core feature doesn't work end-to-end. Fix within first sprint.
- 🟡 **P2** — Production reliability and code quality. Fix before scale.
- 🟢 **P3** — Growth, monetization, viral loops. Build after stability.

---

# 🔴 P0 — Critical Fixes (Week 1)

---

## P0-1 · Points Dual-Accounting — Data Integrity Time Bomb

**Panel: Benjamin, Grok, Jordan Vale**

### What's broken

Two completely separate points ledgers running in parallel:

**Mobile ledger** (`mobile/lib/core/providers/points_provider.dart`):
- Awards 10 pts per meal, 50 pts per workout, 2 pts per set, plus streak bonuses
- Stored in `SharedPreferences` (`user_points_total`, `user_streak_days`)
- Has its OWN streak day calculation based on local last-activity date
- `updateFromSync()` bridge exists but only fires on manual sync

**Backend ledger** (`backend/src/utils/leaderboard.service.ts` → `User.totalPoints`):
- Awards points via `awardPoints()` called from `logMeal()` and `logWorkoutHistory()`
- Different point values, different triggers
- PointEvent creates an audit trail the mobile never sees

**Result:** A user who logs 5 sets gets +10 pts on mobile and nothing on the backend. A user who redeems a reward loses pts on backend but sees full balance in the challenge page. Leaderboard rankings are guaranteed wrong for every user who uses the mobile app.

### Exact fix

**Step 1 — Deprecate local award logic in mobile:**

File: `mobile/lib/core/providers/points_provider.dart`

Remove `awardMealLogged()`, `awardWorkoutCompleted()`, `awardSetCompleted()` from `PointsNotifier`. These methods should no longer increment local state. Keep the state class, keep `updateFromSync()`, keep `_load()`.

Add a new method:
```dart
Future<void> syncFromBackend(Ref ref) async {
  try {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/gamification/profile');
    final data = res.data['data'] as Map<String, dynamic>;
    updateFromSync(
      (data['totalPoints'] as num).toInt(),
      (data['streakDays'] as num).toInt(),
    );
  } catch (_) { /* keep cached value */ }
}
```

**Step 2 — Call `syncFromBackend` after any action that awards points:**

Files to update:
- `mobile/lib/features/diet/presentation/providers/food_provider.dart` → after `logFood()` succeeds, call `ref.read(pointsProvider.notifier).syncFromBackend(ref)`
- `mobile/lib/features/workout/presentation/providers/workout_provider.dart` → after workout completion saves, same call
- `mobile/lib/features/challenge/presentation/widgets/reward_store_sheet.dart` → after `redeem()` succeeds in `RewardStoreNotifier`, also call sync

**Step 3 — Remove all callers of old award methods:**

Search for `awardMealLogged`, `awardWorkoutCompleted`, `awardSetCompleted` across `mobile/lib/` and remove every call site.

**Effort:** 3–4 hours | **Risk:** Low — backend already awards correctly, we're just removing the conflicting mobile logic.

---

## P0-2 · Reward Store Shows Stale Balance

**Panel: Harper, Jordan Vale**

### What's broken

After redeeming a reward in `RewardStoreSheet`:
- Backend correctly deducts points from `User.totalPoints`
- `RewardStoreState.totalPoints` is updated optimistically ✅
- **But** `pointsProvider.totalPoints` in `challenge_page.dart` still shows the OLD value
- The challenge page points card reads from `pointsProvider` (SharedPreferences), never from the backend

### Exact fix

In `mobile/lib/features/challenge/presentation/providers/reward_provider.dart`, inside `RewardStoreNotifier.redeem()` `onSuccess` path, after updating state, call:
```dart
// After successful redemption, sync backend balance to local cache
_ref.read(pointsProvider.notifier).updateFromSync(
  state.totalPoints - (reward?.pointsCost ?? 0),
  _ref.read(pointsProvider).streakDays,
);
```

This requires passing `Ref` to `RewardStoreNotifier`. Update the constructor to accept `Ref` and add it as a field.

**Effort:** 1 hour | **Risk:** Trivial.

---

## P0-3 · l10n Adoption — Language Switch Shows 100% English

**Panel: Harper, Jordan Vale, Marcus Kane**

### What's broken

`tr()` is called in exactly **3 places** in `mobile/lib/features/` — all inside `language_toggle.dart`. The entire app uses hardcoded English strings. Gym owners have paid for a Georgian language feature. It does nothing.

### Exact fix — minimum viable l10n pass

**Target: all 5 bottom-nav feature pages + shared widgets**

For each file, replace hardcoded UI strings with `tr()` calls. The L10n notifier is already wired via `l10n_provider.dart` — just call it.

Access pattern in any ConsumerWidget:
```dart
final l10n = ref.watch(l10nProvider.notifier);
// then: l10n.tr('button.save')
```

**Files to update (priority order):**

1. `mobile/lib/features/workout/presentation/pages/workout_page.dart`
   - "Start Workout", "Finish Workout", "Rest", "Sets", "Reps", "Weight", "Rest Day"
   
2. `mobile/lib/features/diet/presentation/pages/diet_page.dart`
   - "Breakfast", "Lunch", "Dinner", "Snack", "Log food", "Daily Target", "Calories", "Protein"
   
3. `mobile/lib/features/challenge/presentation/pages/challenge_page.dart`
   - "My Progress", "Rooms", "Bonus Challenges", "Hydration Today", "Goal Met"
   
4. `mobile/lib/features/profile/presentation/pages/profile_page.dart`
   - "Profile", "Settings", "Language", "Logout", "Delete Account"
   
5. `mobile/lib/core/widgets/` — all shared buttons and labels

6. Auth screens: login, register, forgot password

**Effort:** 8–10 hours (mechanical but thorough) | **Risk:** Zero — tr() falls back to English if key missing.

---

## P0-4 · UserWeightHistory Missing @@unique — Silent Duplicate Rows

**Panel: Benjamin**

### What's broken

`backend/prisma/schema.prisma` — `UserWeightHistory` has `@@index([userId, date(sort: Desc)])` but NO `@@unique`. The `findFirst` + `create/update` workaround in `mobile.controller.ts` `logWeightEntry()` has a race condition: two concurrent requests (e.g., double-tap) will create two rows for the same user/date.

### Exact fix

**Step 1 — Add to schema:**
```prisma
model UserWeightHistory {
  id        String   @id @default(uuid())
  userId    String
  weight    Decimal
  date      DateTime
  createdAt DateTime @default(now())
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, date])   // ADD THIS
  @@index([userId, date(sort: Desc)])
  @@map("user_weight_history")
}
```

**Step 2 — New migration:**

Create `backend/prisma/migrations/20260425000000_weight_history_unique/migration.sql`:
```sql
-- Deduplicate: keep the most recent row per userId+date before adding constraint
DELETE FROM user_weight_history a
USING user_weight_history b
WHERE a."userId" = b."userId"
  AND a.date = b.date
  AND a."createdAt" < b."createdAt";

CREATE UNIQUE INDEX IF NOT EXISTS "user_weight_history_userId_date_key"
ON user_weight_history ("userId", date);
```

**Step 3 — Switch to upsert in controller:**

File: `backend/src/modules/mobile-sync/mobile.controller.ts`, `logWeightEntry()`:
```typescript
await prisma.userWeightHistory.upsert({
  where: { userId_date: { userId, date: dateKey } },
  update: { weight: weightKg },
  create: { userId, weight: weightKg, date: dateKey },
});
```

**Effort:** 1.5 hours | **Risk:** Low — dedup migration is safe with the DELETE+CREATE pattern.

---

# 🟠 P1 — Core Feature Gaps (Week 2)

---

## P1-1 · Food Database — Empty, Diet Feature Fully Blocked

**Panel: Dr. Elena Voss, Jordan Vale**

### What's broken

`FoodItem` table exists with `countryCodes[]`, `availabilityScore`, barcode field, full nutrition schema. Barcode lookup falls through to Nutritionix/Open Food Facts at runtime — but `GET /api/food/search` returns **zero results** until items are seeded.

The diet feature is the second most-used screen in any fitness app. It currently returns an empty list.

### Exact fix

**File to create:** `backend/prisma/seed-food.ts`

Seed 500+ common food items across 5 cultural packs:
- Universal (150 items): chicken breast, rice, eggs, banana, oatmeal, protein powder, olive oil, etc.
- Georgian (50 items): khachapuri, lobiani, badrijani, churchkhela, tkemali, etc.
- Russian (50 items): grechka, kefir, tvorog, borscht ingredients, etc.
- Western European (100 items): croissant, avocado, quinoa, etc.
- Middle Eastern (50 items): hummus, falafel, pita, tahini, etc.

Each item needs: `name`, `calories`, `proteinG`, `carbsG`, `fatG` (per 100g), `countryCodes[]`, `availabilityScore`.

Add to `package.json` scripts:
```json
"seed:food": "ts-node prisma/seed-food.ts"
```

**Also add** a one-time `POST /api/food/import` endpoint (super admin only) that accepts a JSON array of food items for bulk import — gym owners can upload their local food database.

**Effort:** 6–8 hours (data entry + seed script) | **Risk:** Zero — additive.

---

## P1-2 · AI Language Generation — Synchronous HTTP Will Timeout

**Panel: Lucas, Grok**

### What's broken

`backend/src/modules/admin/language-packs.controller.ts` — `POST /admin/language-packs/ai-generate` makes a synchronous Anthropic API call inside an Express route handler. Claude Haiku generating 135 translations takes 15–45 seconds. On slow networks or busy inference, this will hit the 120s Express timeout. The client sees a timeout error while the DB write may or may not have committed.

The admin frontend already has a polling UI (`POLL_INTERVAL_MS = 5000`, `POLL_TIMEOUT_MS = 90000`) — it was designed for async. The backend should match.

### Exact fix

**Step 1 — Add job type to BullMQ queue**

File: `backend/src/jobs/queues.ts` (or wherever queues are defined) — add `LANG_PACK_GENERATE` to the job types enum.

**Step 2 — Create processor**

New file: `backend/src/jobs/processors/lang-pack-generate.processor.ts`
```typescript
export async function processLangPackGenerate(job: Job<{
  language: string;
  targetLanguage: string;
  countryCode: string;
  requestedBy: string;
}>) {
  const { language, targetLanguage, countryCode } = job.data;
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  // ... same AI call logic, same DB write
  // On completion: mark job done
}
```

**Step 3 — Update controller to enqueue instead of await**

`backend/src/modules/admin/language-packs.controller.ts` — `POST /admin/language-packs/ai-generate`:
```typescript
const job = await langPackQueue.add('generate', { language, targetLanguage, countryCode, requestedBy: userId });
return success(res, { jobId: job.id, status: 'queued' });
```

**Step 4 — Add job status endpoint**

`GET /admin/language-packs/jobs/:jobId` → check BullMQ job state → return `{ status: 'queued' | 'active' | 'completed' | 'failed', packCode? }`.

The existing admin frontend polling already calls `GET /admin/language-packs` to detect the new pack — no frontend change needed.

**Effort:** 3 hours | **Risk:** Low.

---

## P1-3 · Trainer–Member Real-Time Chat

**Panel: Marcus Kane, Benjamin**

### What's missing

Trainers and members currently communicate via `SupportTicket` with `trainer` relation — a ticket system, not a chat. There's no real-time messaging, no typing indicators, no read receipts in a conversational context.

`Socket.IO` is already initialized (`backend/src/lib/socket.ts`). `RoomMessage` already implements real-time messaging for challenge rooms. The infrastructure exists.

### Exact fix

**Backend — new file:** `backend/src/modules/trainers/trainer-chat.controller.ts`

Routes:
- `GET /trainers/conversations` — list trainer's conversations (one per assigned member)
- `GET /trainers/conversations/:memberId/messages` — message history (paginated)
- `POST /trainers/conversations/:memberId/messages` — send message → Socket.IO emit to room `chat:${trainerId}:${memberId}`
- `PATCH /trainers/conversations/:memberId/messages/read` — mark read

**Schema addition** (minimal — reuse `TicketMessage` or add `ChatMessage`):
```prisma
model ChatMessage {
  id         String   @id @default(uuid())
  senderId   String
  receiverId String
  content    String
  readAt     DateTime?
  createdAt  DateTime @default(now())
  sender     User     @relation("SentMessages", fields: [senderId], references: [id])
  receiver   User     @relation("ReceivedMessages", fields: [receiverId], references: [id])
  @@index([senderId, receiverId])
  @@index([receiverId, readAt])
  @@map("chat_messages")
}
```

**Mobile — new widget** inside `mobile/lib/features/workout/presentation/widgets/trainer_chat_sheet.dart` (lives in workout feature, since trainer is workout context — satisfies no new features/ folder rule).

**Effort:** 8 hours | **Risk:** Medium (schema addition, Socket.IO room management).

---

## P1-4 · Notifications Preferences UI in Mobile

**Panel: Jordan Vale, Marcus Kane**

### What's missing

`NotificationPreference`, `PushNotificationConfig`, and `UserDevice` all exist in the backend. FCM/APNs are wired. But there is no notification preferences screen in mobile — users cannot control what they receive.

### Exact fix

Add to `mobile/lib/features/profile/presentation/pages/profile_page.dart` (inside Settings section):
- Toggle: Push notifications on/off
- Toggle: Workout reminders
- Toggle: Diet reminders
- Toggle: Challenge room updates
- Quiet hours picker (time range)

Backed by `PATCH /api/notifications/preferences` which already exists.

**Effort:** 4 hours | **Risk:** Low — UI only, backend already complete.

---

## P1-5 · Onboarding Flow — Content Is Missing

**Panel: Marcus Kane, Jordan Vale**

### What's found

`mobile/lib/features/onboarding/presentation/pages/onboarding_flow_page.dart` exists but based on the scan, the actual onboarding content screens (fitness goals, body metrics collection, gym selection) may be incomplete.

### Exact fix

Onboarding must collect (in order):
1. **Welcome screen** — app value proposition, "Get Started"
2. **Basic profile** — name, date of birth, gender
3. **Body metrics** — height, weight (feeds into BMI + goal calculations)
4. **Fitness goal** — Weight Loss / Muscle Gain / Endurance / General Fitness
5. **Fitness level** — Beginner / Intermediate / Advanced
6. **Equipment access** — Home / Gym / Both
7. **Gym connection** — QR scan or "Skip for now"
8. **Plan generation** — trigger AI plan generation with collected data

All data POSTs to `PATCH /api/users/profile` and `POST /api/sync/ai/generate-plan`.

On completion: store `onboarding_complete = true` in SharedPreferences + navigate to main shell.

**Effort:** 10–12 hours | **Risk:** Medium (multiple screens, state management).

---

## P1-6 · Admin Dashboard Rebuild — Role-Based Branch Intelligence View

**Panel: Marcus Kane, Grok, Benjamin**

### What's broken

`admin/app/dashboard/page.tsx` renders a generic dashboard regardless of role. A Gym Owner with 5 branches has no way to see branch-level performance at a glance. A Super Admin has no platform-wide KPI view. Both roles see the same flat data in the same format — making the admin panel feel like a CRUD tool, not a business intelligence product. `dashbord.md` defines the full spec.

### Architecture

Single entry page, two fully-separated components:

**File: `admin/app/dashboard/page.tsx`**
```typescript
const { user } = useAuth(); // existing hook
if (user.role === 'SUPER_ADMIN') return <SuperAdminDashboard />;
return <GymOwnerDashboard />;
```

### Super Admin View — `admin/components/dashboard/SuperAdminDashboard.tsx`

**4 KPI StatCards** (use existing `StatCard` component):
- Total Gym Owners
- Total Branches
- Total Platform Revenue This Month (sum of completed payments)
- Avg Revenue per Gym Owner

**Charts** (Recharts, dark theme `#121721`, accent `#F1C40F`):
- Revenue Trend — line chart, last 30/90 days toggle → `GET /analytics/revenue-trend?days=30`
- New Gym Owners Growth — monthly bar chart → `GET /analytics/member-growth`
- Top 10 Gym Owners by Revenue — horizontal bar chart → `GET /analytics/top-owners?limit=10`

**Real-time active gyms counter** — WebSocket event `gym:active_count` (already emitted by gym-entry module on check-in/out).

**AI Summary box** → `GET /analytics/ai-summary?scope=platform` — one-sentence insight: "+28% revenue this month, 3 gyms at churn risk."

**Gym Owners table** (bottom) — sortable by revenue / branches / members, searchable by name, CSV export button.

### Gym Owner View — `admin/components/dashboard/GymOwnerDashboard.tsx`

**Header:** Date range picker (Week / Month / Custom) — controls all branch cards.

**Branch Cards grid** (responsive: 1 col mobile → 2 col tablet → 3 col desktop).

**Reusable card: `admin/components/ui/BranchCard.tsx`** — each card shows:
- Branch name + city
- Today's Check-ins (live, real-time)
- Monthly Revenue (this branch only)
- Total Visitors: Today / This Month
- Door Activity Today (entries + exits)
- Active Members (valid membership)
- Staff Performance: trainer session count + completion rate

Click → navigates to `admin/app/dashboard/gyms/[gymId]/branches/[branchId]`.

Real-time updates via WebSocket: events `entry:checkin` and `door:activity` update the matching branch card in-place.

**AI Summary box per branch** → `GET /analytics/ai-summary?scope=branch&branchId=X`.

### New backend endpoints required

Add to `backend/src/modules/analytics/analytics.controller.ts`:
- `GET /analytics/platform-kpis` — total gym owners, total branches, total revenue this month, avg per owner (Super Admin only)
- `GET /analytics/top-owners?limit=10` — top gym owners sorted by revenue (Super Admin only)
- `GET /analytics/ai-summary?scope=platform|branch&branchId?` — Claude Haiku one-sentence insight

Add to `backend/src/modules/gym-management/gym-owner.controller.ts`:
- `GET /gym-owner/branches/dashboard` — per-branch aggregate: today_checkins, monthly_revenue, total_visitors_today, total_visitors_month, door_activity_today, active_members, staff_performance `[{trainerId, sessions, completionRate}]`

### Design constraints (from `dashbord.md`)
- Dark theme: `bg-[#121721]`, `border-zinc-800`, accent `#F1C40F`
- Use existing `StatCard` component — no new design primitives
- Recharts or Tremor for charts (match existing dark theme)
- Fully responsive, real-time WebSocket updates

**Effort:** 14–16 hours | **Risk:** Medium — multiple new backend aggregation queries, WebSocket event coordination.

---

# 🟡 P2 — Production Hardening (Weeks 3–4)

---

## P2-1 · Test Coverage — From 1.5/10 to 8/10

**Panel: Riley Quinn (bleeding)**

### Existing tests
- `backend/src/__tests__/auth/auth.flow.test.ts` ✅
- `backend/src/__tests__/auth/rate-limiter.test.ts` ✅
- `backend/src/__tests__/lib/db-crypto.test.ts` ✅
- `backend/src/__tests__/payments/stripe-webhook.test.ts` ✅
- `backend/src/__tests__/progress/tasks_pipeline.test.ts` ✅
- `mobile/test/navigation/five_nav_test.dart` ✅

### Missing tests — priority order

**Backend unit tests to add:**

| File to create | What to test |
|---|---|
| `__tests__/gamification/leaderboard.test.ts` | `awardPoints()` with null roomId, deduplication, streak calc |
| `__tests__/gamification/points-dual.test.ts` | Verify backend totalPoints is the authoritative source |
| `__tests__/food/food-ranking.test.ts` | `rankByCountry()` tier ordering, country match → global → other |
| `__tests__/food/food-search.test.ts` | Search returns results, empty query returns [], barcode fallback |
| `__tests__/language-packs/crud.test.ts` | CRUD, version bump on save, push propagation |
| `__tests__/progress/weight-history.test.ts` | logWeightEntry upsert idempotency (concurrent writes) |
| `__tests__/sync/progress-summary.test.ts` | getProgressSummary with/without weight history |

**Mobile widget tests to add:**

| File to create | What to test |
|---|---|
| `test/features/challenge/reward_store_test.dart` | Redeem updates balance in both providers |
| `test/features/diet/food_log_test.dart` | Log food → DailyProgress increments |
| `test/features/workout/workout_complete_test.dart` | Workout save → DailyProgress increments |
| `test/localization/tr_coverage_test.dart` | tr() returns non-key string for every key in kEn |
| `test/providers/points_sync_test.dart` | pointsProvider reflects backend after sync |

**Effort:** 16–20 hours | **Priority:** Block all P3 work behind this.

---

## P2-2 · AppTheme → AppTokens Migration

**Panel: Harper**

### Files still using deprecated AppTheme

Search: `grep -r "AppTheme\." mobile/lib/features/` returns hits in:
- `mobile/lib/features/challenge/presentation/pages/challenge_page.dart` (most of it)
- `mobile/lib/features/workout/presentation/pages/` (multiple files)
- `mobile/lib/features/diet/presentation/pages/` (multiple files)
- `mobile/lib/features/gym/presentation/pages/`
- `mobile/lib/features/dashboard/presentation/pages/`

### Migration pattern

For every `AppTheme.X`, the mapping is:
| AppTheme | AppTokens |
|---|---|
| `AppTheme.backgroundDark` | `AppTokens.colorBgPrimary` |
| `AppTheme.surfaceDark` | `AppTokens.colorBgSurface` |
| `AppTheme.primaryBrand` | `AppTokens.colorBrand` |
| `AppTheme.primaryBrand.withValues(alpha: 0.2)` | `AppTokens.colorBrandDim` |
| `AppTheme.primaryBrand.withValues(alpha: 0.4)` | `AppTokens.colorBrandBorder` |

After migration, delete `mobile/lib/theme/app_theme.dart`.

**Effort:** 5–6 hours (mechanical) | **Risk:** Low — visual regression only, easily caught.

---

## P2-3 · Analytics Expansion

**Panel: Marcus Kane, Grok**

### What exists

`/backend/src/modules/analytics/churn.service.ts` — churn prediction
`/backend/src/modules/analytics/revenue.service.ts` — revenue by plan/period

### Missing analytics

**Backend — add to analytics.controller.ts:**

1. `GET /analytics/member-growth` — new members per day/week/month, cohort retention
2. `GET /analytics/engagement` — DAU/MAU, avg sessions/week, top features used
3. `GET /analytics/workout-completion` — plan adherence rate, dropout days, top missed workouts
4. `GET /analytics/diet-adherence` — meal log rate, macro target hit rate
5. `GET /analytics/leaderboard-health` — points distribution, inactive users by tier

**Admin page:** Add cards/charts to `admin/app/dashboard/analytics/page.tsx` using the new endpoints.

**Effort:** 10–12 hours | **Risk:** Low — read-only queries.

---

## P2-4 · Branch Management Completion

**Panel: Benjamin, Marcus Kane**

### What exists

`Branch` model in schema. `BRANCH_ADMIN` role. Basic hierarchy: Gym → Branches → Admins.

### What's missing

- Branch-specific membership pricing (separate plans per branch)
- Branch-specific trainer assignment
- Branch capacity/schedule management
- Admin UI for branch CRUD (check if `/admin/app/dashboard/gyms/[gymId]/branches/` exists)
- Mobile: gym page shows which branch the member belongs to

**Effort:** 12–15 hours | **Risk:** Medium (schema additions for branch-scoped pricing).

---

## P2-5 · Rate Limiting on Expensive Endpoints

**Panel: Lucas**

### What's missing

`backend/src/lib/rate-limiters.ts` has `globalLimiter`. But AI endpoints have no specific limiter:
- `POST /api/sync/ai/generate-plan` — no per-user rate limit
- `POST /api/admin/language-packs/ai-generate` — no rate limit

A single user can exhaust the Anthropic API budget in minutes.

### Exact fix

```typescript
// In rate-limiters.ts
export const aiLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3,                    // 3 AI generations per hour per user
  keyGenerator: (req) => (req as AuthenticatedRequest).user?.userId ?? req.ip,
  message: 'AI generation rate limit exceeded. Try again in an hour.',
});
```

Apply to:
- `backend/src/modules/mobile-sync/sync.routes.ts`: `router.post('/ai/generate-plan', aiLimiter, AIController.generatePlan)`
- `backend/src/modules/admin/language-packs.controller.ts`: `router.post('/ai-generate', aiLimiter, handler)`

**Effort:** 1 hour.

---

## P2-6 · Health Check & Monitoring Endpoints

**Panel: Lucas**

### Exact fix

New file: `backend/src/modules/health/health.controller.ts`
```typescript
GET /health        → { status: 'ok', uptime, version }
GET /health/deep   → { db: 'ok'|'err', redis: 'ok'|'err', queue: 'ok'|'err' }
```

Integrate with uptime monitoring (Uptime Robot, Better Uptime, etc.).

Add `X-Request-ID` header middleware for distributed tracing.

**Effort:** 2 hours.

---

# 🟢 P3 — Growth, Viral Loops & Monetization (Month 2)

---

## P3-1 · Referral System

**Panel: Marcus Kane, Grok**

### What's missing

No referral code tracking anywhere. Room invite codes exist but no member-to-member referral incentives.

### Design

```prisma
model ReferralCode {
  id          String   @id @default(uuid())
  code        String   @unique
  ownerId     String
  usedCount   Int      @default(0)
  pointsEarned Int     @default(0)
  createdAt   DateTime @default(now())
  owner       User     @relation(fields: [ownerId], references: [id])
  uses        ReferralUse[]
  @@map("referral_codes")
}

model ReferralUse {
  id          String   @id @default(uuid())
  codeId      String
  newUserId   String
  joinedAt    DateTime @default(now())
  code        ReferralCode @relation(fields: [codeId], references: [id])
  newUser     User     @relation(fields: [newUserId], references: [id])
  @@unique([newUserId])
  @@map("referral_uses")
}
```

**Flow:** User gets a referral code → shares it → new user enters code during registration → both get points (e.g., referrer +200pts, new user +100pts) → points awarded via `awardPoints()`.

**Mobile:** Share sheet in profile page with deeplink `amirani://join?ref=CODE`.

**Backend:** `POST /api/auth/register` checks `referralCode` field, awards on first successful gym approval.

**Effort:** 8 hours | **ROI:** High — viral coefficient multiplier.

---

## P3-2 · Admin Onboarding Wizard for New Gym Owners

**Panel: Marcus Kane**

### What's missing

A new gym owner who just signed up sees the admin dashboard cold — no guided setup. They must discover: Stripe Connect, FCM push credentials, exercise library, trainer invitations, membership plan creation.

### Design

New file: `admin/app/dashboard/onboarding/page.tsx`

Steps:
1. **Business info** — gym name, logo, address, phone (pre-filled from registration)
2. **Billing setup** — Stripe Connect flow (or skip for trial)
3. **Language** — pick alternative language for members
4. **Plans** — create first membership plan (pricing, duration)
5. **Exercise library** — confirm seeded exercises are visible, option to add custom
6. **Trainers** — invite first trainer via email
7. **Push notifications** — paste FCM server key (with step-by-step guide)
8. **Done** — first member QR code, shareable gym invite link

Track completion in `User.metadata` or a new `GymSetupProgress` model.

Show onboarding checklist widget on dashboard home until all 8 steps are complete.

**Effort:** 12–15 hours | **ROI:** Critical for activation rate.

---

## P3-3 · Viral Sharing for Challenge Rooms

**Panel: Marcus Kane, Grok**

### What exists

Challenge rooms have invite codes. Real-time leaderboards. Room messages.

### What's missing

- Share card generation (image with room name, current rank, points)
- Deep link: `amirani://rooms/join?code=XYZ` → opens app, joins room
- "Challenge a friend" flow: pick room → generate share link → native share sheet
- Weekly room winner announcement with share prompt
- Public room discovery (browse rooms without invite — optional join)

**Backend:** `GET /api/rooms/:id/share-card` → returns shareable metadata (OG tags for web preview).

**Mobile:** `Share.share()` in Flutter with room deeplink + user's rank.

**Effort:** 8 hours | **ROI:** Core viral loop — network effects.

---

## P3-4 · Premium Badge System + Streak Multipliers

**Panel: Grok, Jordan Vale**

### What exists

`BadgeDefinition`, `UserBadge` in schema. `calcLevel()` in `badge.service.ts`.

### What's missing

- Badge display UI in mobile profile page
- Streak multiplier logic: after 7-day streak, all points ×1.5
- Premium badge tiers: gold borders, animated effects for top badges
- "You just earned X badge" celebration modal (confetti animation)
- Badge share card (shareable achievement)

**Mobile:** Add badge shelf to profile page. `BadgeNotificationOverlay` widget that appears on top of any screen when a badge is earned (Socket.IO event: `badge:earned`).

**Backend:** `leaderboard.service.ts` already calls `recalculateUserStats()` — add streak multiplier logic there.

**Effort:** 10 hours | **ROI:** High retention signal — badges create daily return behavior.

---

## P3-5 · Gym Owner Analytics Deep Dive (Builds on P1-6)

**Panel: Marcus Kane**

**Prerequisite:** P1-6 (Dashboard Rebuild) must be complete — P3-5 adds deeper analytics layers on top of the `BranchCard` foundation.

### Design

Add a dedicated analytics drill-down view at `admin/app/dashboard/analytics/` (linked from branch cards):

1. **Member Pulse** — live active members, check-ins today, occupancy heatmap per hour
2. **Revenue Forecast** — MRR trend, next 30-day projection based on renewal dates
3. **Retention Heatmap** — weekly check-in patterns (which days lose members most)
4. **Top Trainers** — by client retention rate, not just session count
5. **Plan Mix** — which membership plans are most popular, trial → paid conversion rate

All backed by new analytics endpoints from P2-3 above.

**Effort:** 8 hours | **ROI:** Reduces churn on the B2B side (gym owner retention). The BranchCard grid in P1-6 is the hook that makes owners want to go deeper into these charts.

---

# Compliance Check (Enchanted Focus Panel Rules)

| Rule | Status |
|------|--------|
| Exactly 5 bottom nav pages | ✅ PASS — no new nav pages in any roadmap item |
| `mobile/lib/features/tasks/` does not exist | ✅ PASS — no tasks folder proposed |
| No `UserTask` model in schema | ✅ PASS — schema changes above add ReferralCode/ChatMessage only |
| `DailyProgress` is the only task counter | ✅ PASS — all progress tracking flows through existing DailyProgress |
| Meals stay in `diet/`, exercises in `workout/` | ✅ PASS — no violations in any item |
| No new top-level folders in `mobile/lib/features/` | ✅ PASS — trainer chat goes inside `workout/presentation/widgets/` |
| Schema changes only when required by language.md or existing directive | ✅ PASS — UserWeightHistory unique is a correctness fix; ChatMessage is for trainer feature (in scope); ReferralCode is new growth feature (explicit callout) |
| Admin dashboard rebuild uses existing components (StatCard, lucide-react) | ✅ PASS — P1-6 explicitly mandates reusing existing StatCard, no new design primitives |
| Zero battery impact on mobile changes | ✅ PASS — l10n adoption is pure text replacement; `syncFromBackend` is a single Dio call post-action |

---

# Effort & ROI Summary Table

| Item | Priority | Effort | Panel Unlocked | Score Impact |
|------|----------|--------|----------------|--------------|
| P0-1 Points dual-accounting | 🔴 P0 | 4h | Benjamin, Harper, Jordan | +1.5 avg |
| P0-2 Reward store balance sync | 🔴 P0 | 1h | Harper, Jordan | +0.5 avg |
| P0-3 l10n adoption | 🔴 P0 | 10h | Harper, Jordan, Marcus | +1.5 avg |
| P0-4 UserWeightHistory @@unique | 🔴 P0 | 1.5h | Benjamin | +0.3 avg |
| P1-1 Food database seed | 🟠 P1 | 8h | Dr. Elena Voss, Jordan | +1.2 avg |
| P1-2 AI lang gen → BullMQ | 🟠 P1 | 3h | Lucas, Grok | +0.5 avg |
| P1-3 Trainer chat | 🟠 P1 | 8h | Marcus, Benjamin | +0.4 avg |
| P1-4 Notifications prefs UI | 🟠 P1 | 4h | Jordan | +0.3 avg |
| P1-5 Onboarding flow | 🟠 P1 | 12h | Marcus, Jordan | +0.6 avg |
| P1-6 Dashboard rebuild (role-based) | 🟠 P1 | 16h | Marcus, Grok, Benjamin | +1.2 avg |
| P2-1 Test suite | 🟡 P2 | 20h | Riley | +2.5 avg |
| P2-2 AppTheme migration | 🟡 P2 | 6h | Harper | +0.4 avg |
| P2-3 Analytics expansion | 🟡 P2 | 12h | Marcus | +0.4 avg |
| P2-4 Branch management | 🟡 P2 | 15h | Marcus, Benjamin | +0.3 avg |
| P2-5 Rate limiting on AI | 🟡 P2 | 1h | Lucas | +0.2 avg |
| P2-6 Health check endpoints | 🟡 P2 | 2h | Lucas | +0.2 avg |
| P3-1 Referral system | 🟢 P3 | 8h | Marcus, Grok | +0.3 avg |
| P3-2 Admin onboarding wizard | 🟢 P3 | 15h | Marcus | +0.4 avg |
| P3-3 Viral room sharing | 🟢 P3 | 8h | Marcus, Grok | +0.3 avg |
| P3-4 Badge system + multipliers | 🟢 P3 | 10h | Jordan, Grok | +0.4 avg |
| P3-5 Analytics dashboard upgrade | 🟢 P3 | 8h | Marcus | +0.3 avg |

**Total effort to 10/10:** ~173 hours across 4 weeks

---

# Projected Panel Scores After Completion

| Member | Domain | Current | After P0 | After P1 | After P2 | After P3 (10/10) |
|--------|--------|---------|----------|----------|----------|------------------|
| Grok | System Architecture | 6.2 | 7.5 | 8.2 | 9.0 | 10.0 |
| Harper | Mobile / UX | 5.5 | 8.0 | 8.8 | 9.5 | 10.0 |
| Benjamin | Backend | 6.8 | 8.0 | 8.8 | 9.5 | 10.0 |
| Lucas | Infrastructure | 6.0 | 6.5 | 7.5 | 9.0 | 10.0 |
| Dr. Elena Voss | Diet / Nutrition | 5.0 | 5.0 | 8.5 | 9.0 | 10.0 |
| Marcus Kane | Gym Owner | 7.0 | 7.5 | 9.0 | 9.5 | 10.0 |
| Riley Quinn | Testing | 1.5 | 1.5 | 1.5 | 8.0 | 9.5 |
| Jordan Vale | End User | 6.0 | 8.5 | 9.0 | 9.5 | 10.0 |

---

# Sprint Plan

## Week 1 — P0 Fire Extinguisher Sprint (16.5h)
- [ ] P0-1 Fix points dual-accounting (4h)
- [ ] P0-2 Fix reward store balance sync (1h)
- [ ] P0-3 l10n adoption pass across 5 pages (10h)
- [ ] P0-4 UserWeightHistory @@unique + migration (1.5h)

**Gate:** Do not move to P1 until all P0 items pass manual QA on a real device.

## Week 2 — P1 Feature Completion Sprint (51h)
- [ ] P1-1 Food database seed (8h)
- [ ] P1-2 AI language gen → BullMQ (3h)
- [ ] P1-3 Trainer-member chat (8h)
- [ ] P1-4 Notifications preferences UI (4h)
- [ ] P1-5 Onboarding flow content (12h)
- [ ] P1-6 Dashboard rebuild — role-based branch intelligence view (16h)

## Weeks 3–4 — P2 Production Hardening Sprint (56h)
- [ ] P2-1 Test suite — backend unit tests (10h)
- [ ] P2-1 Test suite — mobile widget tests (10h)
- [ ] P2-2 AppTheme → AppTokens full migration (6h)
- [ ] P2-3 Analytics expansion (12h)
- [ ] P2-4 Branch management completion (15h)
- [ ] P2-5 Rate limiting on AI endpoints (1h)
- [ ] P2-6 Health check endpoints (2h)

## Month 2 — P3 Growth Sprint (49h)
- [ ] P3-1 Referral system (8h)
- [ ] P3-2 Admin onboarding wizard (15h)
- [ ] P3-3 Viral room sharing (8h)
- [ ] P3-4 Badge system + streak multipliers (10h)
- [ ] P3-5 Analytics dashboard upgrade (8h)

---

# Viral Growth Checklist

When all P0–P3 items are done, these network-effect flywheels are active:

- [ ] **Referral loop** — every member can invite; both get points → grows user base
- [ ] **Room viral loop** — share your rank → friends join → rooms grow → more competition → more sharing
- [ ] **Badge share loop** — earn badge → share achievement → friend downloads app
- [ ] **Streak multiplier** — 7-day streak = 1.5× points → daily return behavior
- [ ] **Gym language lock-in** — gym owner picks Georgian → every member gets Georgian UI → differentiation vs. global apps
- [ ] **Leaderboard network effect** — more members in a gym → more competition → higher engagement → word of mouth
- [ ] **Trainer platform lock-in** — trainer creates diet/workout templates → assigned to members → switching cost for trainer is high

---

# Files Changed / Created Summary

### Backend
| File | Action | Priority |
|------|--------|----------|
| `backend/src/modules/mobile-sync/mobile.controller.ts` | Edit: switch `logWeightEntry()` to upsert | P0-4 |
| `backend/prisma/schema.prisma` | Edit: add `@@unique` to UserWeightHistory, add ChatMessage, add ReferralCode/ReferralUse | P0-4 / P1-3 / P3-1 |
| `backend/prisma/migrations/20260425_weight_unique/` | Create: dedup + unique migration | P0-4 |
| `backend/prisma/seed-food.ts` | Create: 500+ food items across 5 cultural packs | P1-1 |
| `backend/src/jobs/processors/lang-pack-generate.processor.ts` | Create: BullMQ AI translation job | P1-2 |
| `backend/src/modules/admin/language-packs.controller.ts` | Edit: replace sync AI call with queue enqueue | P1-2 |
| `backend/src/modules/trainers/trainer-chat.controller.ts` | Create: chat endpoints | P1-3 |
| `backend/src/lib/rate-limiters.ts` | Edit: add `aiLimiter` | P2-5 |
| `backend/src/modules/health/health.controller.ts` | Create: health endpoints | P2-6 |
| `backend/src/modules/analytics/analytics.controller.ts` | Edit: add platform-kpis, top-owners, ai-summary + 5 analytics endpoints | P1-6, P2-3 |
| `backend/src/modules/gym-management/gym-owner.controller.ts` | Edit: add `/branches/dashboard` aggregate endpoint | P1-6 |
| `backend/src/index.ts` | Edit: register new routes | P1-2, P1-3, P2-6 |
| `backend/src/__tests__/gamification/leaderboard.test.ts` | Create | P2-1 |
| `backend/src/__tests__/food/food-ranking.test.ts` | Create | P2-1 |
| `backend/src/__tests__/language-packs/crud.test.ts` | Create | P2-1 |
| `backend/src/__tests__/progress/weight-history.test.ts` | Create | P2-1 |

### Admin (Next.js)
| File | Action | Priority |
|------|--------|----------|
| `admin/app/dashboard/page.tsx` | Edit: role-based render (SuperAdmin vs GymOwner) | P1-6 |
| `admin/components/dashboard/SuperAdminDashboard.tsx` | Create: KPI cards, charts, AI summary, gym owners table | P1-6 |
| `admin/components/dashboard/GymOwnerDashboard.tsx` | Create: branch cards grid, date range picker, real-time updates | P1-6 |
| `admin/components/ui/BranchCard.tsx` | Create: reusable branch stat card with real-time socket support | P1-6 |
| `admin/app/dashboard/onboarding/page.tsx` | Create: 8-step wizard | P3-2 |
| `admin/app/dashboard/analytics/page.tsx` | Edit: add new charts | P2-3, P3-5 |

### Mobile (Flutter)
| File | Action | Priority |
|------|--------|----------|
| `mobile/lib/core/providers/points_provider.dart` | Edit: remove local award methods, add syncFromBackend | P0-1 |
| `mobile/lib/features/diet/presentation/providers/food_provider.dart` | Edit: call syncFromBackend after logFood | P0-1 |
| `mobile/lib/features/workout/presentation/providers/workout_provider.dart` | Edit: call syncFromBackend after workout complete | P0-1 |
| `mobile/lib/features/challenge/presentation/providers/reward_provider.dart` | Edit: sync points after redemption | P0-2 |
| `mobile/lib/features/workout/presentation/pages/workout_page.dart` | Edit: tr() adoption | P0-3 |
| `mobile/lib/features/diet/presentation/pages/diet_page.dart` | Edit: tr() adoption | P0-3 |
| `mobile/lib/features/challenge/presentation/pages/challenge_page.dart` | Edit: tr() adoption + AppTokens migration | P0-3, P2-2 |
| `mobile/lib/features/profile/presentation/pages/profile_page.dart` | Edit: tr() adoption + notifications prefs | P0-3, P1-4 |
| `mobile/lib/features/onboarding/presentation/pages/onboarding_flow_page.dart` | Edit: add all content steps | P1-5 |
| `mobile/lib/features/workout/presentation/widgets/trainer_chat_sheet.dart` | Create: trainer chat UI | P1-3 |
| `mobile/lib/theme/app_theme.dart` | Delete after migration | P2-2 |
| `mobile/test/features/challenge/reward_store_test.dart` | Create | P2-1 |
| `mobile/test/features/diet/food_log_test.dart` | Create | P2-1 |
| `mobile/test/providers/points_sync_test.dart` | Create | P2-1 |

---

*Last updated: 2026-04-25 (rev 2 — added P1-6 Dashboard Rebuild from dashbord.md) · Enchanted Focus Panel · Zero hallucination mode*

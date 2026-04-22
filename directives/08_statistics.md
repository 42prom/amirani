# Directive 08 — Statistics & Dashboards

## Overview

Statistics surfaces are split by user role. All charts use `fl_chart` package.
Data is fetched from backend and cached locally for offline viewing.

**Mobile features**:
- Member stats: `features/progress/` and `features/dashboard/`
- Progress page: `progress_page.dart` (route: `/progress`)
- Dashboard page: `dashboard_page.dart` (route: `/dashboard`)
- Recovery data: `recovery_provider.dart`

**Backend**: `backend/src/modules/analytics/`, `backend/src/modules/sessions/`, `backend/src/modules/audit/`
**Admin dashboard analytics**: `/dashboard/analytics`

---

## Member Dashboard (`dashboard_page.dart`)

Route: `/dashboard`

Main stats hub showing:
- **Daily Score Summary** — Score ring + today's breakdown (workout %, diet %, hydration %)
- **Calorie & Macro Overview** — Consumed vs. target (from `SessionProgressState`)
- **Recovery Status** — `recovery_provider.dart` data (sleep quality, rest day gauge)
- **Workout History Preview** — Last few sessions from `workout_history_service.dart`
- **Body Progress Teaser** — Latest weight entry + trend arrow

### Recovery Provider (`recovery_provider.dart`)

Fetches user recovery data (sleep, soreness self-report, readiness score).
Displayed as "Recovery Status" card on dashboard.

---

## Progress Page (`progress_page.dart`)

Route: `/progress` (nested under dashboard branch in GoRouter)

Detailed progress:
- **Weight & Body Trend Chart** (`fl_chart` line chart) — historical weight logs
- **Macro Adherence** — Weekly diet tracking adherence rate
- **Workout Attendance** — Calendar heatmap view
- **Strength PRs** — Per-exercise personal records
- **Body Measurements Table** — Chest/waist/hips/arm over time

Provider: `progress_provider.dart` → `/analytics/progress` endpoint.

---

## Session History

`workout_history_service.dart` in `core/services/`:
- Fetches historical workout sessions.
- Used by dashboard + progress page for trend visualization.

`meal_history_service.dart` in `core/services/`:
- Records meal completed/skipped events.
- Powers meal variety scoring and AI swap suggestions.
- Used by `MealSwapService` to detect patterns.

---

## Shopping Basket (`shopping_basket_provider.dart`)

`features/diet/presentation/providers/shopping_basket_provider.dart`:
- Manages weekly shopping list (derived from `MonthlyDietPlanEntity.shoppingLists`).
- `virtualPantryProvider` — tracks pantry stock, auto-updated when meals are completed.
- Displayed in diet page shopping list section.

---

## Daily Score Calculation

Computed live in `SessionProgressState.dailyScore` (in `session_progress_provider.dart`):

```
dailyScore = (workoutProgress × 50) + (dietProgress × 40) + (hydrationProgress × 10)
```

Clipped to [0, 100]. Rest days count as full workout contribution (1.0 × 50 = 50 pts).

Score is:
1. Displayed in `ScoreRing` widget on challenge page
2. Synced to backend via `MobileSyncService.syncUp()` with `tasksTotal`, `tasksCompleted`, `score`
3. Stored in backend for trend analytics

---

## Admin Analytics Dashboard (`/dashboard/analytics`)

Gym Owner web dashboard analytics:

| Section                    | Data                                  |
| -------------------------- | ------------------------------------- |
| Active Members             | Current active subscription count     |
| Revenue (MTD/YTD)          | Stripe payment aggregates             |
| Attendance Peak Hours      | Visit distribution by hour of day     |
| Member Churn Rate          | Monthly subscription cancellations    |
| Equipment Utilization      | Most reserved/used equipment          |
| New Member Acquisition     | Monthly signups trend                 |

All powered by `backend/src/modules/analytics/` and displayed in Next.js admin dashboard.

---

## Chart Styling (ALL charts)

- Background: transparent (sits on `GlassCard`).
- Line/bar color: `AppTokens.colorAccent` (`#F1C40F`) for primary data.
- Grid color: `rgba(255,255,255,0.05)`.
- Axis labels: `AppTokens.colorTextMuted`.
- Tooltip: dark surface background, white text, yellow highlight for value.
- All charts: animate on first render (800ms ease-in-out).
- Empty state: `AppEmptyState` widget + "Not enough data yet" message — NEVER blank.
- Loading state: `ShimmerLoader` skeleton of chart dimensions.

---

## Agent Rules for Statistics

- All charts: use `fl_chart` — never Canvas/CustomPainter for charts.
- Chart data models: freezed, from API response.
- `progress_provider.dart` is the ONLY provider for the progress page — do not add analytics fetching to `session_progress_provider`.
- Recovery data is separate from daily session progress — use `recovery_provider.dart`.
- Empty states MUST show a meaningful message + illustration, never a blank screen.
- Admin stats require role check (web middleware) — mobile does not expose gym owner analytics.

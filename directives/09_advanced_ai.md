# Directive 09 — Advanced AI Intelligence

## Overview

Advanced AI features are the innovation differentiators of Amirani.
They elevate the platform from a tracking app to a predictive health companion.

These features are currently in various stages of implementation. Core AI orchestration
is fully built (`ai_orchestration_service.dart`). Advanced features listed here are
post-MVP roadmap items unless already present in code.

**AI generation**: All via `core/services/ai_orchestration_service.dart` (strategy pattern)
**AI backend config**: `/dashboard/ai-config` (admin panel to tune AI parameters)
**Backend AI module**: `backend/src/modules/ai/` — BullMQ workers + AI provider calls

---

## 1. AI Plan Generation (IMPLEMENTED)

See Directive 03 for full details. Key facts:

- Plans are generated via BullMQ async job queue on backend.
- Mobile polls with exponential backoff (up to 60 attempts, 10s max delay).
- Backend has a **3-tier fallback**: AI attempt → 1-shot repair → deterministic fallback.
- Worker timeout: ~250s for generation. Mobile polling timeout: ~400s total.
- Plans are cached in Hive immediately after parsing.

### Zero-Hallucination Constraints (Backend AI Prompt Rules)

These are enforced in the backend AI system prompts in `backend/src/modules/ai/`:

1. **Canonical ingredient naming** — Use full canonical names (e.g., "Greek Yogurt" not "yogurt").
2. **Ingredient schema**: Always `name`, `amount`, `unit`, `calories`, `protein`, `carbs`, `fat`.
3. **Macro math validation** — Total meal calories must match sum of ingredient calories (±10%).
4. **No duplicate meals** — Same meal name must not appear more than once per day.
5. **No generic names** — Exercise/meal names must be descriptive (e.g., "Incline Dumbbell Press" not "Chest Exercise 1").

---

## 2. Smart Meal Swap (IMPLEMENTED)

**Service**: `lib/core/services/meal_swap_service.dart` (58KB)

- AI-powered meal replacement respecting user dietary preferences.
- Scores alternatives by: caloric similarity, macro balance, user history, variety score.
- Persists swaps in `MonthlyDietPlanEntity` via Hive.
- Records events to `MealHistoryService` for ongoing learning.
- `meal_variety_service.dart` — scores meal variety to prevent repetitive suggestions.

---

## 3. Workout Progression Engine (IMPLEMENTED)

**Service**: `lib/core/services/workout_progression_engine.dart`

- Applies **wave periodization** across 4 weeks: Build → Intensity → Peak → Deload
- Per workout goal:
  - Strength: 6→5→4→6 reps with +1 set at peak
  - Hypertrophy: 10→12→14→10 reps with volume increase
  - Endurance: 15→18→21→15 reps
  - Fat Loss: 12→14→16→12 reps

Used internally by `AIOrchestrationService` for offline generation and as a reference
for what the AI backend produces.

---

## 4. Macro Cycling Engine (IMPLEMENTED)

**Service**: `lib/core/services/diet_macro_cycling_engine.dart`

28-day macro cycling applied at the plan level:
- Week 1: Maintenance calories
- Week 2: Slight surplus (muscle building phase)
- Week 3: Deload / cut (calorie reduction)
- Week 4: Recovery (back to maintenance)

Calorie targets derived from Mifflin-St Jeor TDEE formula using `UserBodyMetrics`.

---

## 5. Long-Term Body Transformation Prediction (ROADMAP)

AI projects user's trajectory at 30 / 90 / 365 days based on:
- Current body metrics (weight, body fat)
- Daily calorie adherence trend
- Workout consistency score
- Historical rate of change

**Output**: `TransformationProjection` entity with projected weights + AI narrative per timeframe.
**Screen**: `TransformationPredictionScreen` (not yet built).

---

## 6. Injury Prevention Layer (ROADMAP)

AI detects overtraining signals and surfaces warnings:

| Signal                                 | Threshold   | Response                                     |
| -------------------------------------- | ----------- | -------------------------------------------- |
| Same muscle 3+ consecutive days        | Auto        | "You've been pushing chest hard — rest day?" |
| Load increase >20% per week            | Auto        | "Rapid load increase — injury risk"          |
| Recovery score <30 for 3+ days         | Score-based | "Active rest recommended"                    |

Warning card to appear at top of workout page — `colorWarning` (#E67E22), not red.

---

## 7. Loyalty Intelligence (ROADMAP)

Backend computes loyalty tier from attendance logs:

| Tier     | Attendance/Month | Rewards                        |
| -------- | ---------------- | ------------------------------ |
| Bronze   | 1–8 visits       | —                              |
| Silver   | 9–16 visits      | 5% renewal discount            |
| Gold     | 17–23 visits     | Free guest pass                |
| Platinum | 24+ visits       | Priority booking + 10% off     |

Tier-up: celebration animation (confetti package) + FCM push.

---

## 8. Emotional AI & Inactivity Recovery (ROADMAP)

- 3+ days inactivity → `ai_motivation` FCM push (see directive 07).
- 7+ days inactivity → `RESTART` plan (3-day light full-body) auto-generated.
- All AI motivational messages: never guilt-trip, always empathetic, use user's name.

---

## 9. Smart Gym Insights for Owners (ROADMAP)

Server-side AI analysis exposed in admin dashboard:
- Most used equipment → "Consider adding another cable machine — 87% utilization"
- Peak load hours → "Offer morning discount to redistribute"
- Member churn signals → "15 members haven't visited in 14 days"

---

## Agent Rules for Advanced AI

- All AI generation goes through `AIOrchestrationService` — never call backend AI endpoints from a provider directly.
- Zero-hallucination rules are backend prompt constraints — if plan JSON arrives malformed, mobile must gracefully fall back to offline generation.
- Injury warnings: `colorWarning` orange, not `colorDanger` red — Amirani is a wellness app, not a medical device.
- Loyalty tier changes: always confirmed by backend event — never computed client-side from local attendance data.
- Advanced roadmap features must not block shipping of core plan generation + tracking functionality.
- `workout_progression_engine.dart` is the **reference implementation** — it defines what quality AI output should look like.

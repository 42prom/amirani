# Directive 03 — AI Coach Engine

## Overview

The AI Coach is the heart of Amirani. It runs across all user types and continuously
adapts based on behavioral signals.

**Key file**: `lib/core/services/ai_orchestration_service.dart` (107KB — the central AI engine)

The AI system does NOT live in a `features/ai_coach/` folder. It is implemented as
a **service** in `core/services/` and consumed by each feature's providers.

---

## AI Architecture: Strategy Pattern

```dart
enum AIStrategy {
  offline,   // Enhanced mock generation (local exercise/meal database)
  api,       // BullMQ backend queue → AI worker (DeepSeek/Claude)
  directAI,  // Direct DeepSeek API calls from mobile
}

class AIConfig {
  final AIStrategy strategy;
  final String model;     // 'deepseek-chat'
  final Duration timeout; // defaults to 180 seconds
}
```

Strategy implementations in `core/services/ai/`:
- `api_strategy.dart` — Backend BullMQ job enqueueing + polling
- `deepseek_strategy.dart` — Direct DeepSeek API calls

**Default strategy**: `AIStrategy.api` in production.

---

## Plan Generation Flow (AIStrategy.api)

```
1. User completes onboarding wizard (WorkoutPreferencesEntity / DietPreferencesEntity)
2. Provider calls AIOrchestrationService.generateWorkoutPlan() or .generateDietPlan()
3. Service POSTs to /ai/generate/workout or /ai/generate/diet → Backend enqueues BullMQ job
4. Backend responds: { data: { status: "QUEUED", jobId: "..." } }
5. Service calls _pollJobStatus(jobId, type):
   - Polls GET /ai/status/:jobId/:type
   - Exponential backoff: immediate → 2s → 4s → 8s → capped at 10s
   - Max 60 attempts (~10 minutes total)
   - Backend 3-tier fallback: AI attempt → 1-shot repair → deterministic fallback
6. On COMPLETED: job.result contains the raw AI JSON plan
7. Service parses the plan into MonthlyWorkoutPlanEntity or MonthlyDietPlanEntity
8. Provider saves plan to Hive via WorkoutPlanStorageService / DietPlanStorageService
9. SessionProgressNotifier.refreshFromStorage() loads the plan into session state
```

---

## Plan Calendar Anchoring

> [!IMPORTANT]
> Diet plans are anchored to **Monday of the current week**, regardless of what day
> generation is triggered on. This ensures `templateDays[0]` (Monday food) always
> lands on an actual Monday in the calendar.
>
> Workout plans start from the current date or Monday, depending on context.

```dart
// In _parseDietPlanFromApiResponse:
final startDate = today.subtract(Duration(days: today.weekday - 1)); // prev Monday
final endDate = startDate.add(const Duration(days: 27));
```

---

## AI-Generated Plan JSON Format

Backend AI generates a **flat 7-day `days[]` array** (not nested weeks):

```json
{
  "planMeta": {
    "dailyCalories": 2200,
    "macros": { "protein": 165, "carbs": 275, "fat": 73 }
  },
  "days": [
    {
      "day": "MONDAY",
      "meals": [
        {
          "name": "Greek Yogurt Protein Bowl",
          "type": "breakfast",
          "time": "08:00",
          "calories": 420,
          "protein": 38,
          "carbs": 45,
          "fat": 9,
          "instructions": "...",
          "ingredients": [
            { "name": "Greek Yogurt", "amount": "200", "unit": "g", "calories": 130, "protein": 22, "carbs": 8, "fat": 1 }
          ]
        }
      ]
    }
  ]
}
```

The mobile client **repeats this 7-day template 4 times** to create the 28-day monthly plan.

---

## Offline Plan Generation (AIStrategy.offline)

Used as fallback when backend is unavailable. Generates plans from the local databases:
- **Exercises**: `lib/core/data/exercise_database.dart` (~54KB of exercise data)
- **Meals**: `lib/core/data/meal_database.dart` (~17KB of meal data)

Offline mode applies:
- **Progressive overload**: Wave periodization (build → peak → deload across 4 weeks)
- **Body-aware logic**: Adjusts reps/weight based on `UserBodyMetrics`
- **Muscle assignment**: Assigns muscle groups to days based on `preferredDays` + `targetMuscles`

---

## 1. Adaptive Workout Planner

### Key Entities

```dart
// WorkoutPreferencesEntity fields (in workout_preferences_entity.dart):
WorkoutGoal goal              // strength / muscleGain / weightLoss / endurance / generalFitness
TrainingLocation location     // gym / home / outdoor
TrainingSplit trainingSplit   // fullBody / upperLower / pushPullLegs / ppl / etc.
List<int> preferredDays       // 0=Mon ... 6=Sun
int sessionDurationMinutes    // 30 / 45 / 60 / 75 / 90
List<String> targetMuscles    // ['chest', 'back', 'shoulders']
List<Equipment> availableEquipment
List<String> likedExercises
List<String> dislikedExercises
```

### Exercise Selection Logic

1. If `targetMuscleNames` provided → muscle-aware path (selects exercises for those muscles)
2. Otherwise → split-based path (push/pull/legs/etc.)
3. Filtered by `availableEquipment` and `dislikedExercises`
4. Sorted: liked exercises first, then target muscles
5. Progressive overload applied across 4 weeks (`_applyProgressiveOverload`)

### Plan Swap (Exercise Swap)

```dart
// In AIOrchestrationService:
Future<List<PlannedExerciseEntity>> swapDayExercises({
  required DailyWorkoutPlanEntity currentDay,
  required WorkoutPreferencesEntity preferences,
  int count = 3,
});
```

---

## 2. Adaptive Diet Planner

### Key Entities

```dart
// DietPreferencesEntity fields (in diet_preferences_entity.dart):
DietGoal goal              // loseWeight / gainMuscle / maintain / eatHealthy
List<String> allergies     // ['gluten', 'lactose', ...]
List<String> preferences   // ['lowCarb', 'highProtein', ...]
String? budgetLevel        // 'low' / 'medium' / 'high'
bool mealPrepFriendly
int mealsPerDay            // 3 / 4 / 5 / 6
```

### Macro Cycling

`diet_macro_cycling_engine.dart` provides **28-day macro cycling**:
- Week 1: Build phase (normal macros)
- Week 2: Surplus phase (slight increase)
- Week 3: Peak/deload phase
- Week 4: Recovery (maintenance)

### Meal Swap Service

`meal_swap_service.dart` (58KB) handles AI-powered meal replacements:
- Detects dietary conflicts (allergies, preferences)
- Scores alternatives by nutritional similarity
- Persists swaps in the monthly plan (Hive)
- Records to `MealHistoryService` for learning

### Ingredient Key Convention

> [!IMPORTANT]
> AI returns `name` for ingredient name (NOT `item`). Legacy `item` key is supported as
> fallback in parsing. Always use `name` in new AI prompts.

```dart
// Parsing in _parseDietPlanFromApiResponse:
name: (ingJson['name'] ?? ingJson['item'] ?? 'Ingredient') as String,
amount: ((ingJson['amount'] ?? ingJson['grams'])?.toString() ?? '100'),
```

---

## 3. Session Progress & Scoring

`session_progress_provider.dart` is the **single source of truth** for daily session state.

### Score Formula (dailyScore 0–100)

```
dailyScore = (workoutProgress × 50) + (dietProgress × 40) + (hydrationProgress × 10)
```

Where:
- `workoutProgress` = completedExercises / totalExercises (or 1.0 if no exercises = rest day)
- `dietProgress` = completedMeals / totalMeals (or 1.0 if no meals assigned)
- `hydrationProgress` = completedCups / targetCups (default 8 cups)

### Cloud Sync

`SessionProgressNotifier.triggerCloudSync()`:
- Debounced (2s) to batch rapid state changes
- Calls `MobileSyncService.syncUp()` with `dailyProgress[]` payload
- Payload: `{ date, caloriesConsumed, proteinConsumed, waterConsumed, activeMinutes, tasksTotal, tasksCompleted, score }`

---

## 4. Points & Gamification

`points_provider.dart` — `PointsState`:
- `awardSetCompleted()` — per exercise set
- `awardMealLogged()` — per meal completed
- `awardWorkoutCompleted(setsLogged)` — workout session bonus
- `totalPoints` and `streakDays` synced to cloud via `MobileSyncService`

---

## 5. Smart Reminders

- `meal_reminder_service.dart` — Local meal reminders (tied to `scheduledTime` in plan)
- `push_notification_service.dart` — FCM push notification setup (called on auth)
- `app_lifecycle_sync_service.dart` — Triggers `syncDown` on foreground resume

---

## 6. Workout Session Tracking

`active_workout_session_provider.dart` — Tracks live in-gym session:
- Records actual sets per exercise (`loggedSets`: weight, reps, RPE)
- `finishWorkout()` in `SessionProgressNotifier` POSTs to `/sync/workout-session`
- Points awarded on session completion

---

## Data Persistence Rules

> [!IMPORTANT]
> - Plans MUST be cached in Hive immediately after fetching.
> - NEVER call the AI service on every screen load — use cached plan, refresh in background.
> - `WorkoutPlanStorageService` handles all Hive reads/writes for workout plans.
> - `DietPlanStorageService` handles all Hive reads/writes for diet plans.
> - Set/meal completion is persisted to Hive immediately (not just in-memory).

---

## Agent Rules for AI Coach

- All AI plan generation goes through `AIOrchestrationService` — never call backend AI endpoints directly from a provider.
- Polling logic lives only in `AIOrchestrationService._pollJobStatus()` — do not duplicate.
- `SessionProgressNotifier` is the only class that should call `DietPlanStorageService.loadPlan()` or `WorkoutPlanStorageService.loadPlan()` during session initialization.
- `MealSwapService` is the only class that should write swapped meals to persistent storage.
- After any AI plan is saved to Hive, call `_ref.invalidate(savedWorkoutPlanProvider)` or equivalent to refresh UI.

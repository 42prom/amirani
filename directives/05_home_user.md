# Directive 05 — Home User Mode & Onboarding

## Overview

Home Users have no gym linked. They get the full AI coaching experience
using bodyweight, resistance band, and minimal equipment exercises.
They can upgrade to link to a gym at any time.

Both `GYM_MEMBER` and `HOME_USER` roles go through onboarding flows before AI plan generation.
Onboarding is implemented as dedicated wizard pages (not in `features/home_user/`):

- **Workout onboarding**: `features/workout/presentation/pages/workout_onboarding_page.dart`
- **Diet onboarding**: `features/diet/presentation/pages/diet_onboarding_page.dart`
- **App onboarding** (first launch): `features/onboarding/presentation/pages/onboarding_flow_page.dart`

---

## Home User Capabilities

| Feature                            | Available |
| ---------------------------------- | --------- |
| AI Workout Plans (bodyweight/home) | ✅        |
| Diet Plans & Calorie Tracking      | ✅        |
| Water Tracking                     | ✅        |
| Behavioral Scores (dailyScore)     | ✅        |
| Smart Reminders                    | ✅        |
| Body Progress Logs                 | ✅        |
| Challenge / Score Hub              | ✅        |
| Gym Door Access                    | ❌        |
| Gym Inventory Plans                | ❌        |
| Trainer Assignment                 | ❌        |

---

## Onboarding Architecture

### First Launch Onboarding (`onboarding_flow_page.dart`)
Routes: `/onboarding`

Multi-step introductory flow shown to NEW users only:
- Introduces the app concept
- Collects basic user type (gym member / home user)
- On completion: sets `SharedPreferences('onboarding_complete', true)`
- Redirects to `/login`

### Workout Preferences Wizard (`workout_onboarding_page.dart`)
Provider: `workout_onboarding_provider.dart`

Steps collect `WorkoutPreferencesEntity`:
1. **Goal**: strength / muscle gain / weight loss / endurance / general fitness
2. **Location**: Gym / Home / Outdoor
3. **Training Split**: Full Body / Upper-Lower / Push-Pull-Legs / etc.
4. **Equipment**: Available equipment checkboxes (filtered by location)
5. **Schedule**: Preferred days (Mon–Sun) + session duration
6. **Muscle Focus**: Target muscle groups (optional)
7. **Liked/Disliked Exercises**: (optional preferences)

On wizard completion → `AIOrchestrationService.generateWorkoutPlan()` is called.

### Diet Preferences Wizard (`diet_onboarding_page.dart`)
Provider: `diet_onboarding_provider.dart` (86KB — comprehensive wizard)

Steps collect `DietPreferencesEntity`:
1. **Goal**: Lose weight / Gain muscle / Maintain / Eat healthy
2. **Dietary restrictions**: Allergies, vegetarian/vegan, halal, keto, etc.
3. **Meals per day**: 3 / 4 / 5 / 6
4. **Budget level**: Low / Medium / High
5. **Meal prep preference**
6. **Calorie target**: TDEE-based or manual

On wizard completion → `AIOrchestrationService.generateDietPlan()` is called.

---

## Home Exercise Database

- Location: `lib/core/data/exercise_database.dart` (~54KB)
- Used by `AIOrchestrationService` for offline plan generation
- Categories: bodyweight, resistance_band, dumbbell, yoga, cardio_home, gym equipment
- Each exercise: `PlannedExerciseEntity` with name, targetMuscles, sets, equipment, video URL, instructions

---

## Water Tracking

- Provider: `features/home/presentation/providers/water_tracker_provider.dart`
- Daily goal: default 8 cups (2L), adjustable.
- State lives in `HydrationProgress` within `SessionProgressState`.
- Progress tracked in `SessionProgressNotifier`:
  - contributes 10% to `dailyScore`
  - synced to cloud via `MobileSyncService`

---

## Challenge Page (Home / Main Hub)

Route: `/challenge` (default route after login)
File: `features/challenge/presentation/pages/challenge_page.dart`

This is the **primary home screen** for all users. Displays:
- Daily score ring & breakdown (workout / diet / hydration)
- Today's workout summary
- Today's diet summary
- Water tracker widget
- Points & streak status
- AI motivational message

`SessionProgressNotifier.refreshFromStorage()` is called when this page loads to ensure
progress rings are accurate even before visiting Workout or Diet tabs.

---

## Body Progress Logs

- Provider under `features/progress/` — `progress_provider.dart`
- Screen: `features/progress/presentation/pages/progress_page.dart`
- Displays weight trend chart (fl_chart), measurement table
- Log new entry via FAB → bottom sheet
- Route: `/progress` (nested under dashboard branch)

---

## Upgrade to Gym Flow

```
Upgrade CTA tapped (shown in gym page or dashboard)
→ GymSearchScreen: search by name, city, or QR scan gym code
→ GymDetailScreen: preview gym, subscription plans, pricing
→ Subscribe → PaymentScreen (Stripe via backend)
→ On success → role changes to GYM_MEMBER
→ Nav bar state refreshes (gym tabs now active)
→ AI plan regenerated using gym inventory equipment
```

Gym self-registration deep link: `/gym-register?gymId=XXX&code=YYY`

---

## Points & Gamification

`lib/core/providers/points_provider.dart`:

```dart
class PointsState {
  final int totalPoints;
  final int streakDays;
  // Awards:
  void awardSetCompleted()   // +XP per set
  void awardMealLogged()     // +XP per meal
  void awardWorkoutCompleted({required int setsLogged}) // session bonus
}
```

Points displayed on challenge page. Synced to backend via `MobileSyncService.syncUp(profileChanges: {...})`.

---

## Tier Limits (Subscription Gates)

`lib/core/providers/tier_limits_provider.dart` — reads user's subscription tier and gates features:

| Tier         | Plan Generation | Meal Swaps | Trainer Assignment | Advanced Analytics |
| ------------ | --------------- | ---------- | ------------------ | ------------------ |
| Free         | Limited         | ❌         | ❌                 | ❌                 |
| Basic        | ✅ Monthly      | Limited    | ❌                 | ❌                 |
| Premium      | ✅ Monthly      | ✅ Unlimited | ✅              | ✅                 |

Use `TierLimitsProvider` and `PremiumStateCard` widget before showing gated features.

---

## User Body Metrics

`lib/core/models/user_body_metrics.dart`:

```dart
class UserBodyMetrics {
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final String? sex; // 'male' | 'female'
}
```

Passed to `AIOrchestrationService` during plan generation for:
- Mifflin-St Jeor TDEE calculation (calorie targets)
- Body-aware exercise weight adjustments

---

## Agent Rules for Home User Mode

- Home user and gym member share the same workout/diet features — no separate feature folder.
- Equipment selection during onboarding sets `WorkoutPreferencesEntity.availableEquipment` immediately.
- After role upgrade to `GYM_MEMBER`, invalidate `userGymStateProvider` and re-fetch gym data.
- Never show gym door access UI to users without an active gym — check `userGymStateProvider`.
- Water tracker state MUST persist between app sessions (synced via session state cloud sync).
- `SessionProgressNotifier.refreshFromStorage()` MUST be called on challenge page load and after any plan change.

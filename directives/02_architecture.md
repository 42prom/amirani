# Directive 02 — System Architecture

## Architectural Style

**Structure**: Monorepo (one root, multiple sibling projects)
**Mobile**: Flutter (iOS + Android) for Users
**Backend**: Node.js/TypeScript (Local process during dev — `npm run dev` in `backend/`)
**Admin**: Next.js/React (Web application — `npm run dev` in `admin/`)
**Infrastructure**: PostgreSQL, Redis (Dockerized via `docker-compose.yml`)
**Public Access**: Cloudflared tunnel exposes local backend for mobile device connectivity

---

## Monorepo Structure

```text
amirani/
├── mobile/             # Flutter (Users/Members)
├── admin/              # Next.js (Gym Owners/Trainers/Super Admins)
├── backend/            # Node.js/TS (Core API)
├── docker-compose.yml  # Infrastructure (PostgreSQL, Redis)
├── .env                # Global Environment Config
└── directives/         # AI Guidance & Architectural Standards
```

---

## Flutter Clean Architecture Layers

```
Domain (Pure Dart — no Flutter imports)
  └── Entities (freezed), Repository Interfaces, UseCases

Data (implements Domain)
  └── DTOs/Models (freezed), DataSources (Remote), Repository Impls

Presentation (Flutter)
  └── Riverpod Providers/Notifiers, Widgets, Screens/Pages
```

**Rule**: Presentation → Domain ← Data. Presentation NEVER imports Data directly.

---

## Actual Mobile Folder Structure

```
mobile/lib/
│
├── main.dart                        # ProviderScope, Hive init, env load
├── app.dart                         # MaterialApp.router, GoRouter, theme, lifecycle
│
├── theme/
│   └── app_theme.dart               # AppTheme.darkTheme, AppTheme.primaryBrand
│
├── design_system/
│   ├── design_system.dart           # Barrel export
│   ├── tokens/
│   │   └── app_tokens.dart          # All design tokens
│   └── components/
│       ├── glass_card.dart
│       ├── primary_button.dart
│       ├── shimmer_loader.dart
│       ├── score_ring.dart
│       └── app_icon_badge.dart
│
├── core/
│   ├── config/
│   │   ├── app_config.dart          # Environment config, base URL
│   │   └── service_availability.dart
│   ├── data/
│   │   ├── exercise_database.dart   # Local exercise DB (used by offline AI)
│   │   ├── meal_database.dart       # Local meal/food DB
│   │   └── local_db_service.dart    # sqflite wrapper
│   ├── error/
│   │   └── failures.dart            # Sealed Failure classes
│   ├── models/
│   │   └── user_body_metrics.dart   # UserBodyMetrics (height, weight, age, sex)
│   ├── network/
│   │   ├── dio_provider.dart        # Dio singleton + Riverpod provider
│   │   └── auth_interceptor.dart    # JWT injection + 401 session expiry
│   ├── providers/
│   │   ├── app_boot_provider.dart           # Pre-warm cache on app start
│   │   ├── day_selector_providers.dart      # Selected day state
│   │   ├── diet_profile_sync_provider.dart  # Diet preferences from backend
│   │   ├── points_provider.dart             # Gamification points & streaks
│   │   ├── session_progress_provider.dart   # Daily workout+diet session state
│   │   ├── storage_providers.dart           # Hive box providers
│   │   ├── tier_limits_provider.dart        # Subscription tier feature gates
│   │   ├── unit_system_provider.dart        # kg/lbs, cm/ft preference
│   │   ├── user_gym_state_provider.dart     # User's gym + membership status
│   │   └── workout_profile_sync_provider.dart
│   ├── services/
│   │   ├── ai_orchestration_service.dart    # ALL AI plan generation (107KB — core engine)
│   │   ├── ai/
│   │   │   ├── api_strategy.dart            # Backend BullMQ job strategy
│   │   │   └── deepseek_strategy.dart       # Direct DeepSeek API strategy
│   │   ├── app_lifecycle_sync_service.dart  # App foreground/background sync
│   │   ├── diet_macro_cycling_engine.dart   # 28-day macro cycling logic
│   │   ├── diet_plan_storage_service.dart   # Hive persistence for diet plans
│   │   ├── gym_equipment_service.dart       # Gym equipment fetching
│   │   ├── meal_history_service.dart        # Meal learning & history
│   │   ├── meal_reminder_service.dart       # Local meal reminder scheduling
│   │   ├── meal_swap_service.dart           # AI-powered meal swapping
│   │   ├── meal_variety_service.dart        # Meal variety scoring
│   │   ├── mobile_sync_service.dart         # Cloud sync (dailyProgress, profileChanges)
│   │   ├── nfc_hce_service.dart             # NFC HCE for door access
│   │   ├── push_notification_service.dart   # FCM push notification setup
│   │   ├── user_equipment_service.dart      # User's available equipment
│   │   ├── workout_history_service.dart     # Workout session history
│   │   ├── workout_plan_storage_service.dart # Hive persistence for workout plans
│   │   └── workout_progression_engine.dart  # Progressive overload engine
│   ├── usecases/                            # (minimal — most logic in services)
│   └── widgets/                             # Shared utility widgets (see 01_ui_ux.md)
│
├── features/
│   ├── auth/
│   │   ├── data/datasources/auth_remote_data_source.dart
│   │   ├── data/models/
│   │   ├── data/repositories/
│   │   ├── domain/entities/
│   │   ├── domain/repositories/
│   │   ├── domain/usecases/
│   │   └── presentation/
│   │       ├── pages/login_page.dart
│   │       ├── providers/auth_provider.dart   # AuthState machine
│   │       └── widgets/
│   │
│   ├── onboarding/
│   │   └── presentation/pages/onboarding_flow_page.dart
│   │
│   ├── challenge/
│   │   └── presentation/pages/challenge_page.dart   # Home/score hub (default route after login)
│   │
│   ├── dashboard/
│   │   ├── data/ domain/
│   │   └── presentation/
│   │       ├── pages/dashboard_page.dart
│   │       └── providers/
│   │           ├── dashboard_provider.dart
│   │           └── recovery_provider.dart
│   │
│   ├── workout/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   │   ├── exercise_model.dart
│   │   │   │   ├── routine_model.dart
│   │   │   │   ├── workout_plan_model.dart (+ .freezed.dart + .g.dart)
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── exercise_entity.dart (+ .freezed.dart)
│   │   │   │   ├── monthly_workout_plan_entity.dart (+ .freezed.dart + .g.dart)
│   │   │   │   ├── routine_entity.dart (+ .freezed.dart)
│   │   │   │   ├── workout_plan_entity.dart (+ .freezed.dart)
│   │   │   │   ├── workout_preferences_entity.dart (+ .freezed.dart + .g.dart)
│   │   │   └── usecases/workout_usecases.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── workout_page.dart              # Plan view + day selector
│   │       │   ├── workout_onboarding_page.dart   # Workout preferences wizard
│   │       │   ├── workout_plan_builder_page.dart # AI plan builder UI
│   │       │   └── active_workout_session_page.dart # Live session tracker
│   │       ├── providers/
│   │       │   ├── workout_provider.dart
│   │       │   ├── workout_onboarding_provider.dart
│   │       │   └── active_workout_session_provider.dart
│   │       └── widgets/
│   │
│   ├── diet/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   │   ├── diet_plan_model.dart
│   │   │   │   ├── meal_model.dart
│   │   │   │   └── daily_macro_model.dart
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── monthly_plan_entity.dart (+ .freezed.dart) # Core diet plan entity
│   │   │   │   ├── diet_preferences_entity.dart (+ .freezed.dart)
│   │   │   │   ├── meal_entity.dart (+ .freezed.dart)
│   │   │   │   ├── meal_ingredient_entity.dart (+ .freezed.dart + .g.dart)
│   │   │   │   ├── meal_reminder_entity.dart (+ .freezed.dart)
│   │   │   │   ├── diet_plan_entity.dart (+ .freezed.dart)
│   │   │   │   └── daily_macro_entity.dart (+ .freezed.dart)
│   │   │   ├── usecases/diet_usecases.dart
│   │   │   └── utils/                        # diet_shopping_utils.dart, etc.
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── diet_page.dart             # Main diet UI (130KB)
│   │       │   └── diet_onboarding_page.dart  # Diet preferences wizard (96KB)
│   │       └── providers/
│   │           ├── diet_provider.dart
│   │           ├── diet_onboarding_provider.dart
│   │           └── shopping_basket_provider.dart
│   │
│   ├── gym/
│   │   ├── data/ domain/
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── gym_page.dart               # Main gym hub (139KB)
│   │       │   ├── gym_entry_page.dart          # QR/NFC entry screen
│   │       │   ├── gym_self_registration_page.dart # Member self-register
│   │       │   └── trainer_chat_page.dart       # Chat with trainer
│   │       └── providers/
│   │           ├── gym_provider.dart
│   │           ├── gym_access_provider.dart
│   │           ├── gym_register_provider.dart
│   │           ├── membership_provider.dart
│   │           ├── sessions_provider.dart
│   │           ├── support_provider.dart
│   │           ├── trainer_assignment_provider.dart
│   │           └── announcements_provider.dart
│   │
│   ├── profile/
│   │   └── presentation/
│   │       ├── providers/profile_sync_provider.dart
│   │       └── widgets/
│   │
│   ├── progress/
│   │   └── presentation/
│   │       ├── pages/progress_page.dart
│   │       └── providers/progress_provider.dart
│   │
│   ├── home/
│   │   └── presentation/
│   │       └── providers/water_tracker_provider.dart
│   │
│   ├── dashboard/
│   ├── rooms/                          # Gym room booking (data + presentation)
│   └── challenge/                      # Daily challenge / score hub
│
└── l10n/                               # Localisation (en - English only currently)
```

---

## State Management: Riverpod

- Use `AsyncNotifier` for async operations (API calls).
- Use `StateNotifier` (`extends StateNotifier<T>`) for complex synchronous state (e.g., `SessionProgressNotifier`).
- Use `Notifier` for simpler synchronous state.
- Use `StreamNotifier` for real-time data.
- Use `Provider` only for pure DI (repositories, services, use cases).
- **`StateProvider` only for simple leaf state** (single bool/int) — not complex objects.

```dart
// Preferred async pattern
@riverpod
class WorkoutNotifier extends _$WorkoutNotifier {
  @override
  FutureOr<WorkoutState?> build() => null;

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(workoutServiceProvider).fetchPlan());
  }
}
```

---

## Dependency Injection

Use **Riverpod providers** as DI. No get_it.

Standard DI chain example:
```
dioProvider → authRemoteDataSourceProvider → authRepositoryProvider
                                           → loginUseCaseProvider
                                           → authNotifierProvider
```

Service-layer providers are typically `Provider<ServiceClass>`:
```dart
final aiOrchestrationServiceProvider = Provider<AIOrchestrationService>((ref) {
  return AIOrchestrationService(dio: ref.watch(dioProvider));
});
```

---

## Navigation: go_router

```dart
// Route guard pattern (in app.dart):
redirect: (context, state) async {
  final authState = ref.read(authNotifierProvider);
  if (authState is AuthInitial || authState is AuthLoading) return '/';
  if (authState is AuthAuthenticated) return '/challenge'; // default post-login
  // ... unauthenticated → /onboarding or /login
}
```

- Named routes only. Route definitions in `app.dart` (`goRouterProvider`).
- `StatefulShellRoute.indexedStack` for the 5-tab bottom nav branches.
- Deep link support for push notifications (FCM).

---

## Networking

- **Dio** with `BaseOptions` (base URL from `app_config.dart`, dynamic timeouts).
- `AuthInterceptor` (`auth_interceptor.dart`): Injects `Bearer` JWT; emits `sessionExpiredProvider` on 401.
- `dioProvider` in `core/network/dio_provider.dart`.
- No Retrofit — raw Dio with typed response parsing in services.

---

## Local Storage

| Data Type                              | Storage                                      |
| -------------------------------------- | -------------------------------------------- |
| JWT tokens                             | `flutter_secure_storage`                     |
| Monthly workout plan (28 days)        | `Hive` — typed box via `WorkoutPlanStorageService` |
| Monthly diet plan (28 days)           | `Hive` — typed box via `DietPlanStorageService`    |
| Exercise/completion state persistency | `Hive` — per-set completion written on each tap    |
| Large exercise/food DB                 | `sqflite` via `local_db_service.dart`        |
| User preferences, onboarding state    | `SharedPreferences`                          |

---

## Key Data Models

### Diet Plan Hierarchy (Domain Layer)

```
MonthlyDietPlanEntity
  └── List<WeeklyPlanEntity> (4 weeks)
        └── List<DailyPlanEntity> (7 days)
              ├── List<PlannedMealEntity>
              │     ├── MealType (breakfast/lunch/dinner/snack/morningSnack/afternoonSnack)
              │     ├── NutritionInfoEntity (calories, protein, carbs, fats)
              │     └── List<IngredientEntity> (name, amount, unit, macros)
              ├── targetCalories / targetProtein / targetCarbs / targetFats
              └── List<SmartBagEntryEntity>
```

### Workout Plan Hierarchy (Domain Layer)

```
MonthlyWorkoutPlanEntity
  └── List<WeeklyWorkoutPlanEntity> (4 weeks)
        └── List<DailyWorkoutPlanEntity> (7 days)
              └── List<PlannedExerciseEntity>
                    └── List<ExerciseSetEntity> (setNumber, targetReps, targetWeight, restSeconds, isCompleted)
```

### Session Progress (In-Memory, synced on change)

`SessionProgressState` in `session_progress_provider.dart`:
- `List<ExerciseProgress>` — set completion tracked via `SetStatus` enum
- `List<MealProgress>` — each with `List<MealIngredient>`
- `HydrationProgress` — cups target vs completed
- `dailyScore` (0–100): 50% workout + 40% diet + 10% hydration

---

## Environment Variables (Environment Config)

Loaded at startup via `app_config.dart` (reads from `.env` / build config):

```
API_BASE_URL=http://localhost:3000     # or cloudflare tunnel URL for device testing
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
```

NEVER hardcode any of these values in Dart files.

---

## Backend Module Map (`backend/src/modules/`)

| Module              | Purpose                                            |
| ------------------- | -------------------------------------------------- |
| `ai/`               | BullMQ AI job queue + workers (workout & diet)     |
| `auth/`             | JWT auth, login, register                          |
| `users/`            | User profiles                                      |
| `workouts/`         | Workout plan CRUD                                  |
| `diets/`            | Diet plan CRUD                                     |
| `sessions/`         | Active session tracking                            |
| `gym-management/`   | Gym CRUD                                           |
| `memberships/`      | Subscription management                            |
| `payments/`         | Stripe payment processing                          |
| `trainers/`         | Trainer management                                 |
| `assignment/`       | Trainer-member assignment                          |
| `attendance/`       | Entry/exit logs                                    |
| `door-access/`      | Door hardware & QR/NFC tokens                      |
| `notifications/`    | Push notifications (FCM)                           |
| `mobile-sync/`      | `/sync/daily-progress`, `/sync/workout-session`    |
| `analytics/`        | Stats & trends                                     |
| `announcements/`    | Gym announcements                                  |
| `equipment/`        | Gym equipment inventory                            |
| `food/`             | Food/ingredient database                           |
| `rooms/`            | Gym room management                                |
| `deposits/`         | Deposit tracking                                   |
| `admin/`            | Super-admin platform management                    |
| `platform/`         | SaaS subscriptions & tier limits                   |

---

## Admin Dashboard (`admin/app/dashboard/`)

| Section               | Route                          |
| --------------------- | ------------------------------ |
| Dashboard overview    | `/dashboard`                   |
| Members               | `/dashboard/members`           |
| Trainers              | `/dashboard/trainers`          |
| Trainer view          | `/dashboard/trainer`           |
| Gyms                  | `/dashboard/gyms`              |
| Gym Owners            | `/dashboard/gym-owners`        |
| Payments              | `/dashboard/payments`          |
| Subscriptions         | `/dashboard/subscriptions`     |
| Door Access           | `/dashboard/access`            |
| Equipment             | `/dashboard/equipment`         |
| Analytics             | `/dashboard/analytics`         |
| Billing               | `/dashboard/billing`           |
| Notifications config  | `/dashboard/notifications-config` |
| AI Config             | `/dashboard/ai-config`         |
| Tier Limits           | `/dashboard/tier-limits`       |
| Settings              | `/dashboard/settings`          |

---

## Agent Rules for Architecture

- One feature = one folder in `features/`. Never create cross-feature imports.
- Shared UI between features goes in `core/widgets/` (utility) or `design_system/components/` (primitives).
- Service-layer logic goes in `core/services/` — not inside feature presentation layers.
- Every new DataSource must have a corresponding abstract interface in `domain/`.
- Every new screen must be registered in `app.dart` (`goRouterProvider`) or within its branch.
- After any `freezed`/`hive` change: `dart run build_runner build --delete-conflicting-outputs`.
- `session_progress_provider.dart` is the single source of truth for in-session workout + diet progress.

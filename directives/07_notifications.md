# Directive 07 — Smart Notification Engine

## Overview

Notifications are smart, contextual, and behavior-driven. They must never feel like spam.
Every notification triggers from a specific user behavioral event or AI recommendation.

**Mobile service**: `lib/core/services/push_notification_service.dart`
**Meal reminders**: `lib/core/services/meal_reminder_service.dart`
**Backend module**: `backend/src/modules/notifications/`
**Admin config**: `/dashboard/notifications-config`

---

## Notification Services

### Push Notification Service (`push_notification_service.dart`)

- FCM (Firebase Cloud Messaging) for server-triggered pushes.
- Initialized on first successful login: `PushNotificationService.init(ref, router)` in `app.dart`.
- Handles FCM token registration with backend.
- Parses incoming FCM payload and navigates to correct route via `GoRouter`.

### Meal Reminder Service (`meal_reminder_service.dart`)

- Local meal reminders scheduled based on `scheduledTime` in `PlannedMealEntity`.
- Uses `flutter_local_notifications`.
- Re-schedules whenever a new diet plan is loaded or a meal is swapped.

---

## Notification Types

| Type                      | Trigger                              | Urgency     | Source     |
| ------------------------- | ------------------------------------ | ----------- | ---------- |
| `workout_reminder`        | Scheduled time per plan              | Normal      | Local      |
| `meal_reminder`           | Scheduled meal time in plan          | Normal      | Local (meal_reminder_service) |
| `water_reminder`          | Interval-based (configurable)        | Low         | Local      |
| `subscription_expiring`   | 7 days and 2 days before expiry      | High        | FCM        |
| `subscription_expired`    | Day of expiry                        | Urgent      | FCM        |
| `ai_motivation`           | Long inactivity (3+ days)            | Normal      | FCM        |
| `ai_achievement`          | Milestone reached                    | Celebration | FCM        |
| `plan_updated`            | Trainer modified plan                | Info        | FCM        |
| `gym_announcement`        | Gym owner posts announcement         | Info        | FCM        |

---

## Deep Link Navigation

All notification taps navigate via `GoRouter`. Supported routes:

| Notification Type       | Deep Link Route        |
| ----------------------- | ---------------------- |
| `workout_reminder`      | `/workout`             |
| `meal_reminder`         | `/diet`                |
| `subscription_expiring` | `/gym` (gym hub)       |
| `plan_updated`          | `/workout` or `/diet`  |
| `ai_motivation`         | `/challenge`           |
| `ai_achievement`        | `/challenge`           |
| `gym_announcement`      | `/gym` (gym hub)       |

---

## App Lifecycle Sync

`lib/core/services/app_lifecycle_sync_service.dart`:

- **On foreground resume**: `syncDown()` pulls latest state from backend.
- **On authentication**: `onAuthenticated()` triggers immediate plan and profile sync.
- `syncDown()` checks for trainer plan updates, subscription changes, and gym announcements.

---

## Announcement Feed

`announcements_provider.dart` in `features/gym/presentation/providers/`:
- Fetches gym announcements on gym page load.
- Displayed in the gym hub page "My Gym" section.

---

## Agent Rules for Notifications

- `flutter_local_notifications` for all scheduled (reminder) types.
- FCM for all server-triggered types (AI, subscription, announcements, trainer actions).
- `PushNotificationService.init()` must only be called after successful authentication.
- Notification tap MUST navigate to the correct screen — test every deep link route.
- Meal reminders MUST be re-scheduled after any diet plan is saved to Hive.
- Re-schedule meal reminders in `DietPlanStorageService.savePlan()`.
- NEVER show a notification if the user has disabled that category (respect backend preferences).

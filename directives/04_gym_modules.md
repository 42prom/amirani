# Directive 04 — Gym Modules

## Overview

Gym modules handle the operational side: equipment inventory, door access, attendance tracking,
trainer management, and gym self-registration. These affect `GYM_OWNER`, `TRAINER`, and
`GYM_MEMBER` experience.

**Mobile feature location**: `features/gym/`
**Backend modules**: `backend/src/modules/gym-management/`, `door-access/`, `attendance/`, `trainers/`, `assignment/`, `equipment/`, `rooms/`

---

## Mobile Feature Structure (`features/gym/`)

```
features/gym/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── pages/
    │   ├── gym_page.dart                  # Main gym hub (139KB) — tabbed UI
    │   ├── gym_entry_page.dart            # QR/NFC door entry screen
    │   ├── gym_self_registration_page.dart # Member self-register via QR/link
    │   └── trainer_chat_page.dart         # In-app chat with assigned trainer
    ├── providers/
    │   ├── gym_provider.dart              # Gym info fetch
    │   ├── gym_access_provider.dart       # QR/NFC token generation & validation
    │   ├── gym_register_provider.dart     # Self-registration flow
    │   ├── membership_provider.dart       # Member subscription status
    │   ├── sessions_provider.dart         # Gym sessions history
    │   ├── support_provider.dart          # Support ticket submission
    │   ├── trainer_assignment_provider.dart # Assigned trainer info
    │   └── announcements_provider.dart    # Gym announcements feed
    └── widgets/
```

---

## 1. Gym Hub Page (`gym_page.dart`)

The `GymPage` is a comprehensive tabbed screen with multiple sections:

- **My Gym** — Gym info, announcements, current subscription status
- **Door Access** — QR code / NFC entry token + entry history log
- **Sessions** — Past gym session history
- **Trainer** — Assigned trainer card + chat entry point
- **Equipment** — Available gym equipment browser (from gym inventory)
- **Support** — Submit support tickets

---

## 2. Door Access Integration

### Architecture: Adapter Pattern (MANDATORY)

```
IDoorAccessAdapter (abstract)
  └── QrCodeAdapter       implements IDoorAccessAdapter
  └── NfcHceAdapter       implements IDoorAccessAdapter  ← nfc_hce_service.dart
  └── (future adapters...)

GymOwner selects adapter in admin → stored in backend → loaded at runtime
```

**Never hardcode a specific door system.** New door systems = new adapter class only.

### Access Flow (Member)

```
Member opens GymPage → [Door Access] tab
→ Check membership status (expired? → show renewal screen)
→ If active → request QR/NFC token from backend (signed, time-limited)
→ Display animated QR code + NFC animation (gym_entry_page.dart)
→ Token presented to door hardware
→ Door grants access → backend logs entry
```

### NFC HCE Service (`core/services/nfc_hce_service.dart`)

- Implements NFC Host Card Emulation for door access
- Used by `GymEntryPage` when NFC mode is active
- Encrypted token managed by `gym_access_provider.dart`

### Offline Fallback

- Last valid token cached securely.
- Visual indicator: amber "Offline Mode" banner from `offline_banner.dart`.

---

## 3. Gym Self-Registration (`gym_self_registration_page.dart`)

Flow triggered by deep link or QR scan:

```
/gym-register?gymId=XXX&code=YYY
→ GymSelfRegistrationPage
→ Validates the registration code with backend
→ User selects subscription plan
→ Payment (Stripe) → role upgraded to GYM_MEMBER
→ Nav bar refreshes to show gym tabs
```

Route registered in `app.dart`:
```dart
GoRoute(
  path: '/gym-register',
  builder: (context, state) {
    final gymId = state.uri.queryParameters['gymId'] ?? '';
    final code = state.uri.queryParameters['code'] ?? '';
    return GymSelfRegistrationPage(gymId: gymId, registrationCode: code);
  },
),
```

---

## 4. Attendance Tracking

- Entry/exit events logged server-side when door token is used.
- Mobile reads attendance via `sessions_provider.dart` (`/sessions` endpoint).
- Displayed in the **Sessions** tab of `GymPage`.
- AI reads attendance frequency from backend analytics for `consistencyScore` computation.

---

## 5. Trainer Management (Mobile Side)

### Member's Trainer View

- `trainer_assignment_provider.dart` fetches the member's assigned trainer.
- Trainer card displayed in gym page with name, photo, specialization.
- **"Chat"** button navigates to `TrainerChatPage` (`trainer_chat_page.dart`).
- Trainer can push plan modifications from admin dashboard → mobile receives via `syncDown`.

### Admin Side (Web Dashboard — `admin/`)

- Trainer accounts created by Gym Owner in admin dashboard.
- Trainer-member assignment via `/dashboard/trainers` + `/dashboard/members`.
- Trainers access member stats, can override plans, add session notes.
- Trainer dashboard route: `/dashboard/trainer`.

---

## 6. Equipment Management (Mobile Side)

- `gym_equipment_service.dart` in `core/services/` — fetches gym's equipment list.
- `user_equipment_service.dart` — fetches user's own available equipment.
- Equipment list is passed to `AIOrchestrationService` during workout plan generation.
- If equipment status changes (broken/unavailable) → plan should be regenerated.

---

## 7. Rooms Feature (`features/rooms/`)

```
features/rooms/
├── data/
└── presentation/
    ├── data/ (room availability)
    └── presentation/ (room booking UI)
```

Minimal implementation — gym room browsing and booking. Backend: `backend/src/modules/rooms/`.

---

## Agent Rules for Gym Modules

- Subscription check MUST happen before generating or displaying access token — never skip.
- `GymAccessProvider` is the only provider that should request door tokens.
- Trainer role guards: verify trainer assignment before showing trainer-specific UI.
- Attendance is **read-only** from mobile — the app never writes attendance entries directly.
- Equipment changes from admin must trigger a Riverpod invalidation so workout plan screens react.
- The gym self-registration route `/gym-register` supports both query params AND NFC handoff.
- `TrainerChatPage` currently uses direct API messaging — not a real-time socket. Poll-based.

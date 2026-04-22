# Directive 06 — Payments & Subscriptions

## Overview

Payments are handled exclusively via **Stripe**. Payment logic is isolated to the backend
and the `features/gym/` payment flow on mobile. No Stripe secret keys ever touch Flutter.

**Backend module**: `backend/src/modules/payments/`, `backend/src/modules/memberships/`, `backend/src/modules/deposits/`
**Admin dashboard**: `/dashboard/payments`, `/dashboard/subscriptions`, `/dashboard/billing`, `/dashboard/saas-subscriptions`

---

## Supported Payment Methods

- Credit / Debit card (via Stripe PaymentSheet)
- Google Pay
- Apple Pay

**Package**: `flutter_stripe` (official Stripe Flutter SDK).

---

## Subscription Tiers

| Plan              | Who        | Duration                              |
| ----------------- | ---------- | ------------------------------------- |
| Home User Free    | HOME_USER  | Unlimited (basic features only)       |
| Home User Premium | HOME_USER  | Monthly / Yearly                      |
| Gym Membership    | GYM_MEMBER | Monthly / Yearly (set by gym owner)   |
| Gym Owner License | GYM_OWNER  | Monthly (platform fee to Super Admin) |

Feature gates per tier are enforced by `tier_limits_provider.dart` and backend middleware.

---

## Subscription Lifecycle

```
New Member → SelectPlanScreen → PaymentSheet (Stripe) → Backend Webhook Confirms
                                                       → Subscription Active
                                                       → Gym Access Unlocked

Subscription Active:
  - 7 days before expiry → Push notification "Renewing soon"
  - 2 days before expiry → Push + in-app MembershipProvider warning
  - Day of expiry → Final push + gym access blocked

Subscription Expired:
  - Gym access token generation blocked (checked in gym_access_provider.dart)
  - AI Coach still accessible (soft lock)
  - RenewalSheet shown on next gym access attempt

Subscription Renewed → Gym access re-enabled immediately
```

`membership_provider.dart` in `features/gym/presentation/providers/` holds current subscription status.

---

## Stripe Integration Architecture

```
GymSelfRegistrationPage / PaymentScreen (Presentation)
  → PaymentSheet (flutter_stripe)
    → Backend /payments/create-intent endpoint
    → Backend creates Stripe PaymentIntent (server-side secret key)
    → Returns { clientSecret }
  → flutter_stripe.PaymentSheet.show(clientSecret)
  → On success → Stripe webhook fires to backend
  → Backend confirms subscription → membershipProvider refreshes
```

> [!IMPORTANT]
> **Server-side only**: Stripe secret key NEVER touches Flutter code.
> Flutter only receives `clientSecret` from backend.
> App waits for backend webhook confirmation — not just Stripe client-side success event.

---

## Deposits Module

`backend/src/modules/deposits/` — used for gym deposit tracking (separate from subscriptions).
Admin dashboard: `/dashboard/deposits`.

---

## Payment Failure Handling

```dart
// Always handle these Stripe error cases:
switch (stripeError.code) {
  case 'card_declined':       // Show friendly message + retry
  case 'insufficient_funds':  // Suggest alternative method
  case 'expired_card':        // Prompt to update card
  default:                    // Generic error with support contact
}
```

- On failure: bottom sheet with clear message + retry CTA.
- Never crash or show raw Stripe error to user.
- Log payment errors to backend analytics.

---

## Subscription Status Display

`membership_provider.dart` provides `SubscriptionStatus` to the gym page:

- **Active**: Green chip with expiry date (shown in gym page header + profile).
- **Expiring Soon** (≤7 days): Amber chip with days remaining.
- **Expired**: Red chip with "Renew Now" CTA.

---

## Agent Rules for Payments

- NEVER store card data locally — all handled by Stripe SDK.
- `STRIPE_PUBLISHABLE_KEY` loaded from environment config via `app_config.dart` only.
- Subscription check order when generating door access: 1) Auth valid → 2) Subscription active → 3) Generate token.
- `membershipProvider` must be invalidated on logout (already done in `app.dart`).
- Payment success must ALWAYS wait for backend webhook — never unlock access based only on client-side success.

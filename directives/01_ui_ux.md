# Directive 01 — UI/UX Design System

## Design Identity

**Aesthetic**: Dark, premium, AI-native. Think: Whoop × Nike Training App × Ultrahuman.
**Feel**: Every screen must feel like a personal cockpit for your health.

---

## Color Palette

> [!IMPORTANT]
> All color tokens are defined in `lib/design_system/tokens/app_tokens.dart`.
> Never hardcode hex values in widget files — always use `AppTokens.*` or `AppTheme.*`.

| Token                | Hex                      | Usage                                         |
| -------------------- | ------------------------ | --------------------------------------------- |
| `colorBackground`    | `#121721`                | Primary screen background                     |
| `colorSurface`       | `#1A2035`                | Card / surface background                     |
| `colorSurfaceGlass`  | `rgba(255,255,255,0.06)` | Glassmorphic cards                            |
| `colorAccent`        | `#F1C40F`                | Lemon yellow — CTA, highlights, active states |
| `colorAccentSoft`    | `#F4D03F`                | Softer yellow for secondary UI                |
| `colorTextPrimary`   | `#FFFFFF`                | Primary body text                             |
| `colorTextSecondary` | `#A0AABF`                | Muted labels, captions                        |
| `colorTextMuted`     | `#5A6478`                | Disabled / placeholder text                   |
| `colorSuccess`       | `#2ECC71`                | Positive indicators                           |
| `colorWarning`       | `#E67E22`                | Warnings, recovery flags                      |
| `colorDanger`        | `#E74C3C`                | Errors, overtraining alerts                   |
| `colorBorderGlass`   | `rgba(255,255,255,0.10)` | Glass card borders                            |

**Gradient (primary)**: `LinearGradient(#121721 → #0A0D14)` top-to-bottom.
**Gradient (accent)**: `LinearGradient(#F1C40F → #F39C12)`.

---

## Typography

**Font**: `Inter` (Google Fonts)
**Fallback**: `SF Pro Display` (iOS), `Roboto` (Android)

| Style            | Size | Weight | Usage          |
| ---------------- | ---- | ------ | -------------- |
| `displayLarge`   | 32sp | 700    | Hero titles    |
| `headlineMedium` | 24sp | 600    | Screen titles  |
| `titleLarge`     | 20sp | 600    | Card headers   |
| `bodyLarge`      | 16sp | 400    | Primary body   |
| `bodyMedium`     | 14sp | 400    | Secondary text |
| `labelSmall`     | 11sp | 500    | Badges, tags   |

Letter spacing: `-0.3` for headings, `0` for body.

---

## Spacing & Radius

| Token        | Value | Usage                     |
| ------------ | ----- | ------------------------- |
| `spacingXS`  | 4dp   | Icon gaps                 |
| `spacingS`   | 8dp   | Inner padding tight       |
| `spacingM`   | 16dp  | Standard internal padding |
| `spacingL`   | 24dp  | Section gaps              |
| `spacingXL`  | 32dp  | Screen edge padding       |
| `radiusS`    | 8dp   | Chips, badges             |
| `radiusM`    | 12dp  | Cards, modals             |
| `radiusL`    | 20dp  | Full screens, sheets      |
| `radiusPill` | 999dp | Pill buttons              |

---

## Design System Files

```
lib/design_system/
├── design_system.dart         # Barrel export
├── tokens/
│   └── app_tokens.dart        # All design tokens (colors, spacing, radius)
└── components/
    ├── glass_card.dart        # Standard glassmorphic card
    ├── primary_button.dart    # Primary / secondary / ghost / danger variants
    ├── shimmer_loader.dart    # Skeleton loading placeholders
    ├── score_ring.dart        # Animated arc score ring
    └── app_icon_badge.dart    # Icon with count/status badge
```

Additionally, shared utility widgets live in `lib/core/widgets/`:

```
lib/core/widgets/
├── app_navigation_shell.dart  # Bottom nav bar + tab state
├── app_confirm_dialog.dart    # Confirmation dialogs
├── app_day_selector.dart      # Horizontal day selector strip
├── app_empty_state.dart       # Empty state illustration + message
├── app_error_banner.dart      # Inline error card
├── app_section_header.dart    # Section label + optional action
├── app_spinner.dart           # Branded loading spinner
├── offline_banner.dart        # Amber offline mode strip
├── plan_source_badge.dart     # "AI" / "Trainer" source chip
├── premium_state_card.dart    # Upgrade / locked feature card
├── trainer_avatar_chip.dart   # Trainer profile chip
└── user_avatar.dart           # User profile avatar
```

---

## Navigation

**Bottom Nav Bar** (`AppNavigationShell`) with 5 tabs for authenticated users:

| Index | Route        | Label     | Icon                        |
| ----- | ------------ | --------- | --------------------------- |
| 0     | `/workout`   | Workout   | `fitness_center_rounded`    |
| 1     | `/diet`      | Nutrition | `restaurant_menu_rounded`   |
| 2     | `/challenge` | Challenge | (center hero tab)           |
| 3     | `/gym`       | Gym       | `door_front_rounded`        |
| 4     | `/dashboard` | Dashboard | `bar_chart_rounded`         |

Additional routes (outside shell):
- `/` — Splash / Boot screen
- `/login` — Login page
- `/onboarding` — Onboarding flow
- `/gym-register` — Gym self-registration (QR/deep link)
- `/workout/session` — Active workout session (full-screen overlay)
- `/progress` — Progress detail page (nested under dashboard branch)

---

## Core Components

### Buttons (`lib/design_system/components/primary_button.dart`)

- **Primary**: Pill-shaped, yellow gradient fill, black text, 48dp height.
- **Secondary**: Transparent fill, yellow border, yellow text.
- **Ghost**: Transparent, white text, no border.
- **Danger**: Red gradient, white text.
- All buttons: `const` constructors, haptic feedback on tap.

### Cards (Glassmorphic) (`lib/design_system/components/glass_card.dart`)

```dart
// Standard glass card spec — always use GlassCard widget, not raw BoxDecoration:
decoration: BoxDecoration(
  color: Color(0x0FFFFFFF), // ~6% white
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Color(0x1AFFFFFF)),
  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24)],
)
```

### Bottom Sheets

- Use for all modals and action flows (never AlertDialog for primary flows).
- Dark surface, 20dp top radius.
- `DraggableScrollableSheet` for complex content.

### Score Ring (`lib/design_system/components/score_ring.dart`)

- Animated arc ring (0–100 score).
- Used for daily habit score display on challenge/dashboard pages.

---

## Animations & Motion

| Interaction       | Animation                                        |
| ----------------- | ------------------------------------------------ |
| Screen transition | Fade + subtle slide (200ms ease-out)             |
| Card tap          | Scale 0.97 → 1.0 (100ms) + haptic light          |
| Score rings       | Animated arc draw on load (800ms ease-in-out)    |
| Bottom sheet open | Slide up + fade (300ms cubic bezier)             |
| Progress charts   | Draw-in animation left-to-right (600ms)          |

Use `flutter_animate` package for declarative animations.
Always prefer `AnimatedWidget` / `AnimatedBuilder` over manual `AnimationController` where possible.
Use `HapticFeedback.lightImpact()` on button press.
Use `HapticFeedback.mediumImpact()` on milestone achievements.

---

## Accessibility

- All interactive elements: min 48×48dp tap target.
- All images/icons: `Semantics` label.
- Color contrast: min 4.5:1 for text on backgrounds.
- Never rely on color alone for state communication — always pair with icon/text.
- Support `textScaleFactor` up to 1.4 without breaking layouts.

---

## Offline UI States

- Offline banner: `OfflineBanner` widget appears at top of screen from `offline_banner.dart`.
- Loading: Use `ShimmerLoader` skeleton loaders, never spinner on full screen.
- Error: Inline error card with retry button via `AppEmptyState`/`AppErrorBanner` — never `SnackBar` for critical errors.

---

## Agent Rules for UI

- ALWAYS import from `design_system/tokens/app_tokens.dart` and use tokens — no hardcoded colors or sizes.
- NEVER use `Colors.yellow` — always use `AppTokens.colorAccent` or `AppTheme.primaryBrand`.
- NEVER use `Text('...')` without explicit `style` from theme.
- Use `const` on every widget that doesn't depend on runtime data.
- All lists must use `ListView.builder` or `SliverList` — never `Column` with mapped children for dynamic data.
- New shared widgets go in `lib/core/widgets/` (utility) or `lib/design_system/components/` (design primitives).

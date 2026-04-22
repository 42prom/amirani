# Implementation Plan: Backend & Admin Completion

## Execution Order (Dependency-Optimized)

### Phase 1: Core Infrastructure (Foundation)
- [x] **1.1** Attendance Module - CRUD endpoints for check-in/check-out
- [x] **1.2** Door Access Module - CRUD + adapter pattern for unlock systems

### Phase 2: Communication Layer
- [x] **2.1** Notifications Service - Base infrastructure (DB + service)
- [x] **2.2** Email/Push notification providers

### Phase 3: Revenue Engine
- [x] **3.1** Payments Module - Stripe integration
- [x] **3.2** Subscription lifecycle (create, renew, cancel, expire)
- [x] **3.3** Payment failure handling + notifications

### Phase 4: Feature Enhancement
- [x] **4.1** Trainer-specific endpoints (view assigned members, stats)
- [x] **4.2** Enhanced Statistics (revenue, peak hours, retention)
- [x] **4.3** Admin UI pages for new modules

### Phase 4.5: Super Admin Platform Configuration (Completed 2026-02-21)
- [x] **4.5.1** Platform Config schema (AI, Notifications, Tier Limits, Stripe)
- [x] **4.5.2** Platform Config service and controller
- [x] **4.5.3** Super Admin sidebar with all config links
- [x] **4.5.4** AI Configuration page (provider selection, API keys, usage stats)
- [x] **4.5.5** Tier Limits page (FREE, GYM_MEMBER, HOME_PREMIUM)
- [x] **4.5.6** Push Notification config page (FCM, APNs, Email)
- [x] **4.5.7** Stripe config page (API keys, Connect, webhooks)
- [x] **4.5.8** Platform Settings page (branding, maintenance mode)
- [x] **4.5.9** Platform Analytics page

### Phase 4.6: Gym Owner Enhanced Features (Completed 2026-02-21)
- [x] **4.6.1** Subscription Plan schema with time-based access restrictions
- [x] **4.6.2** Stripe Connect for gym owners (accept payments directly)
- [x] **4.6.3** Enhanced Equipment model with images and descriptions
- [x] **4.6.4** Access control validation service (time/day restrictions)
- [x] **4.6.5** Gym Owner API routes (`/gym-owner/*`)
- [x] **4.6.6** Subscription Plans management UI with templates
- [x] **4.6.7** Payments & Payouts page (Stripe Connect onboarding)

### Phase 4.7: Platform Fixes & Enhancements (Completed 2026-02-21)
- [x] **4.7.1** Super Admin visibility fix - read-only gym summary view (no drill-down)
- [x] **4.7.2** Gym Owner invitation flow - token-based registration instead of direct creation
- [x] **4.7.3** DeepSeek AI provider integration (cost-effective alternative)
- [x] **4.7.4** Global Equipment Catalog (Super Admin) + Per-Gym Inventory
- [x] **4.7.5** Simplified Trainer addition form (Name, Age, Picture, Resume)
- [x] **4.7.6** Equipment Dashboard UI transformation (search, grid layout)

### Phase 5: AI Integration
- [ ] **5.1** AI Service Module structure
- [ ] **5.2** Workout/Diet plan generation endpoints
- [ ] **5.3** Behavioral scoring system

---

## Completed Modules

### Backend Modules Created (2026-02-21)

1. **Attendance Module** (`/attendance/*`)
   - Check-in/check-out endpoints
   - Gym attendance statistics
   - User attendance history
   - Missed days detection
   - Peak hours analysis

2. **Door Access Module** (`/door-access/*`)
   - Adapter pattern for multiple door systems (QR, NFC, Bluetooth, PIN)
   - Door system CRUD for gyms
   - Unlock code generation
   - Access logs
   - Health monitoring

3. **Notifications Service** (`/notifications/*`)
   - Multi-channel support (Push, Email, SMS, In-App)
   - User preferences management
   - Quiet hours support
   - Scheduled notifications
   - Payment reminder templates

4. **Payments Module** (`/payments/*`)
   - Stripe integration (mocked for dev)
   - Payment intent creation
   - Subscription purchase flow
   - Subscription cancellation
   - Revenue statistics
   - Webhook handlers
   - Expiring subscription processor

5. **Trainer Module** (`/trainers/*`)
   - Trainer profile management
   - Assigned members list
   - Member statistics view
   - Dashboard with inactive member alerts
   - Availability toggle

6. **Platform Configuration Module** (`/platform/*`) - Super Admin Only
   - Platform config (branding, maintenance mode)
   - AI config (provider selection, API keys, models)
   - Push notification config (FCM, APNs, Email)
   - Stripe config (API keys, Connect, webhooks)
   - User tier limits (FREE, GYM_MEMBER, HOME_PREMIUM)
   - AI usage tracking and statistics

7. **Gym Owner Module** (`/gym-owner/*`)
   - Stripe Connect onboarding and account management
   - Enhanced subscription plans with time-based access
   - Plan templates (Full, Morning, Evening, Weekend, Student)
   - Equipment management with images/descriptions
   - Earnings and payout tracking
   - Access control validation service
   - Browse global equipment catalog (read-only)
   - Add equipment from catalog

8. **Invitation Module** (`/admin/invitations/*`) - Super Admin Only
   - Create, resend, delete invitations
   - Token-based validation
   - Expiry handling (7 days)
   - Invitation-based Gym Owner registration

9. **Equipment Catalog Module** (`/equipment-catalog/*`) - Super Admin Only
   - Global equipment catalog management
   - Category and brand filtering
   - Usage statistics
   - Per-gym inventory linking

### Admin UI Pages Created (2026-02-21)

**Super Admin Pages:**
- `/dashboard` - Platform overview
- `/dashboard/gyms` - Read-only gym summary (no drill-down)
- `/dashboard/invitations` - Gym Owner invitation management
- `/dashboard/equipment-catalog` - Global equipment catalog
- `/dashboard/ai-config` - AI provider configuration (with DeepSeek)
- `/dashboard/tier-limits` - User tier limits management
- `/dashboard/notifications-config` - Push notification setup
- `/dashboard/stripe-config` - Stripe payment configuration
- `/dashboard/settings` - Platform branding and settings
- `/dashboard/analytics` - Platform-wide analytics

**Gym Owner Pages:**
- `/dashboard/gyms` - Gym list with drill-down capability
- `/dashboard/gyms/[gymId]` - Gym details
- `/dashboard/gyms/[gymId]/plans` - Subscription plans with time restrictions
- `/dashboard/gyms/[gymId]/payments` - Stripe Connect onboarding & payouts
- `/dashboard/equipment` - Equipment inventory with search & grid
- `/dashboard/trainers` - Simplified trainer management

**Auth Pages:**
- `/login` - Admin login
- `/register` - Invitation-based Gym Owner registration

### Database Schema Updates
- Added `Invitation` model (token-based gym owner invitations)
- Added `EquipmentCatalog` model (global equipment catalog)
- Added `Notification` model
- Added `NotificationPreference` model
- Added `Payment` model
- Added `PlatformConfig` model (singleton for platform settings)
- Added `AIConfig` model (singleton for AI provider settings)
- Added `PushNotificationConfig` model (singleton for FCM/APNs/Email)
- Added `StripeConfig` model (singleton for payment settings)
- Added `UserTierLimits` model (per-tier AI and feature limits)
- Added `AIUsageLog` model (tracks AI token usage per user)
- Added enums: `NotificationType`, `NotificationChannel`, `PaymentStatus`, `PaymentMethod`, `AIProvider` (with DEEPSEEK), `UserTier`, `DayOfWeek`, `EquipmentCategory`, `InvitationStatus`
- Updated `User` model with `stripeCustomerId`, `tier`, and notification relations
- Updated `Gym` model with Stripe Connect fields
- Updated `SubscriptionPlan` model with time-based access
- Updated `Equipment` model with catalog reference (`catalogItemId`)
- Updated `AIConfig` model with DeepSeek fields (`deepseekApiKey`, `deepseekModel`, `deepseekBaseUrl`)

---

## Remaining Work

### AI Integration (Phase 5) - NOT STARTED
- AI service module structure
- OpenAI/Claude/DeepSeek integration
- Workout plan generation
- Diet plan generation
- Behavioral scoring (Habit, Consistency, Recovery, Motivation)

---

## API Endpoints Summary

```
Auth:           POST /auth/login, POST /auth/register, POST /auth/register-invite
Admin:          /admin/gym-owners, /admin/trainers
Invitations:    /admin/invitations (Super Admin only)
Gyms:           GET/POST/PATCH/DELETE /gyms
Members:        /memberships/gyms/:gymId/members
Equipment:      /equipment/gyms/:gymId
Catalog:        /equipment-catalog (Super Admin only)
Attendance:     /attendance/check-in, /attendance/gyms/:gymId
Door Access:    /door-access/systems/:id/unlock, /door-access/gyms/:gymId/access-check
Notifications:  /notifications, /notifications/preferences
Payments:       /payments/subscribe, /payments/history, /payments/gyms/:gymId/revenue
Trainers:       /trainers/me, /trainers/me/members, /trainers/me/dashboard
Platform:       /platform/config, /platform/ai, /platform/tiers (Super Admin)
Gym Owner:      /gym-owner/gyms/:id/stripe, /gym-owner/gyms/:id/plans, /gym-owner/catalog
```

---

## Multi-Tenant Isolation

**Super Admin:**
- Can view high-level gym summary (name, status, metadata)
- Cannot drill down into gym internals (members, trainers, equipment)
- Manages global platform configuration
- Manages global equipment catalog
- Sends invitations to new Gym Owners

**Gym Owner:**
- Full access to their own gyms
- Can manage members, trainers, equipment, plans
- Uses Stripe Connect for payments
- Can browse (read-only) global equipment catalog
- Registers via invitation link only

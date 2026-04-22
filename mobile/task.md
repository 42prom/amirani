# Member Management & Dynamic Registration

## Planning & Investigation
- [x] Understand `registrationRequirements` schema in the backend.
- [x] Locate the "Members" page and "Add Member" modal in the Admin App.
- [x] Locate the Registration flow in the Mobile App.
- [x] Define Implementation Plan.

## Backend Execution
- [x] Add/update endpoints for editing member profiles (by branch admin).
- [x] Add/update endpoints for removing a member from a gym (revoke membership).
- [x] Ensure `registrationRequirements` is properly validated in backend paths.
- [x] Fix Trainer image visibility in `/gym/details` (Base URL & User fallback).


## Admin Portal (Next.js) Execution
- [x] Implement Dynamic Manual Registration form reading `registrationRequirements`.
- [x] Add Edit Member Profile modal/action.
- [x] Add Remove Member action.

## Mobile App (Flutter) Execution
- [x] Update Online Registration form to strictly adhere to `registrationRequirements`.
- [x] Add `refreshProfile` to `AuthNotifier` to sync data after branch join.
- [x] Implement `ThemedDatePicker` or integrate `showDatePicker` for premium DOB selection.
- [x] Ensure `GymSelfRegistrationPage` refreshes profile on success.
- [x] Test the dynamic fields on Android/Web.
- [x] Fix Flutter build errors and regenerate Freezed models.

## Phase 2: QR Join & Onboarding Persistence
- [x] Debug "Date of birth is required" error during QR scan join.
- [x] Implement onboarding persistence (skip if already seen).
- [x] Ensure auto-login skips onboarding/login screen if session is valid.
- [x] Fix profile data persistence (DOB, weight, height) across app restarts.

## Phase 3: E2E Persistence Refinement
- [x] Implement robust initial redirection (Splash/Wait for Auth).
- [x] Ensure `ProfileSyncNotifier` reactively restores data on auth.
- [x] Remove hardcoded "Alex Doe" defaults in Profile state.
- [x] Verify `onboarding_complete` flag reliability.
- [x] Ensure `AuthNotifier` user state is updated after onboarding sync.

## Phase 4: Offline-First Architecture (Hive)
- [x] Implement `ProfileLocalDataSource` and integrate into `ProfileRepositoryImpl`
- [x] Update `ProfileSyncNotifier` to load from cache on startup
- [x] Register `UserModelAdapter` and initialize Hive profile box

## Phase 5: Premium UI/UX (Animations & Validation)
- [x] Implement "Format-as-you-type" for Phone & DOB
- [x] Add micro-animations to onboarding/registration fields
- [x] Add real-time "Cloud Sync" status indicator

## Phase 6: Final Flagship Polish & Bug Fixes
- [x] Fix Trainer Image mapping (absolute URLs)
- [x] Implement flagship animations in `GymPage`
- [x] Integrate `_CloudSyncIndicator` in `GymPage`
- [x] Verify structural integrity & resolve syntax errors

## Phase 7: System Stability & Persistence Fixes
- [x] Resolve `DropdownButton` assertion crash in Profile Settings
- [x] Fix data loss on app restart (Initialization Guard & Cache Loading)
- [x] Prevent race condition in Onboarding Sync (Await Core initialized)
- [x] Implement Identity Protection Guard (Prevent empty name overwriting)
- [x] Bridge Sync and Auth state in Registration pre-filling (Fix "DOB Required")

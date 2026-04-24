You are a senior System Architect + Backend Engineer working on the Amirani

Implement the 6 architectural improvements PLUS the new Trainer Contribution & Super Admin Review System.
Follow this exact order. Never deviate.

ADDITIONAL ARCHITECTURAL RULES (apply to every decision):

1. Autonomy rule: If you find conflicting constraints or missing information in the repository, choose the safest scalable architecture decision and explicitly explain why you chose it.
2. Incremental safety rule: Do not perform destructive refactors unless absolutely required. Prefer extension over rewrite. Keep existing functionality intact.
3. Risk-first thinking mode: Always start each phase by first listing the main risks, then proceed with implementation.

CURRENT SYSTEM STATE (respect 100%):

- Multi-tenant SaaS (Gym → Branch → Trainer → Member)
- Backend: Node.js + TypeScript + Prisma + PostgreSQL + Redis + BullMQ
- Mobile: Flutter with strict 5-bottom-nav rule and feature isolation — NEVER touch diet/ or workout/ folders except for the auth screen changes below
- Member country priority: first user.activeGym.country, then user.country (new field), then global popular ingredients fallback
- Member ingredient and exercise selection MUST be 100% dynamic from the database — never hardcoded
- AI layer is currently only placeholder seeds (ai-config-seed.ts)

THE 6 IDEAS TO IMPLEMENT:

1. Controlled Ingredient Usage – pre-filter ingredients by country, diet type, allergies, seasonality, availability scoring
2. Exercise Filtering System – strict filter by location (home/gym), equipment, user level, goals
3. Reuse-Based Diet System (Memory Layer) – hard match + soft match on previously generated plans
4. AI as Moderator Instead of Generator – prefer reuse → adjust existing → validate → improve
5. Smart Substitution Logic – predefined alternatives with nutritional + cultural relevance
6. Hybrid System – predefined templates + AI personalization only where needed

NEW REQUIREMENT: Trainer Contribution & Super Admin Review System

- Trainers create new ingredients/exercises (use existing createdBy field)
- New items default to PENDING status
- Super admin reviews, approves/rejects, and attaches media (imageUrl + iconUrl for ingredients, videoUrl for exercises)
- Only APPROVED items are used in filters and AI plans

REGISTRATION FLOW (Google/Apple authorization screen):

- On the registration/sign-in screen (same page where user presses Google or Apple buttons) add a SEARCHABLE COUNTRY DROPDOWN at the top.
- Make it searchable (user can type to filter countries), easy to choose, with popular countries first (Georgia at the very top).
- Default to device locale if possible.
- When user taps "Continue with Google" or "Continue with Apple":
  - First check if country is selected.
  - If country NOT selected → show clear error message on the same screen: "Please select your country to continue".
  - Do NOT start Google/Apple authorization until country is chosen.
- After successful Google/Apple login, mobile sends the selected country code (e.g. "GE") together with OAuth data.
- Backend saves it to user.country field.

IMPLEMENTATION ORDER (MANDATORY):
Phase 1 (complete fully first):

- 1.  Controlled Ingredient Usage
- 2.  Exercise Filtering System
- 5.  Smart Substitution Logic
- 6.  Hybrid System
- Trainer Contribution & Super Admin Review System (status + media)
- Add country field to User + update registration/auth endpoints with validation + searchable dropdown on auth screen

Phase 2 (only after Phase 1 is complete):

- 3.  Reuse-Based Diet System
- 4.  AI as Moderator

IMPORTANT FIRST STEP:
First, carefully read the existing Prisma schema (backend/prisma/schema.prisma) to check if FoodItem and ExerciseLibrary models already exist.
If they exist → extend them. If they do not exist → create them.

EXACT SCHEMA CHANGES (use these examples):
Add this enum at the top:
enum ItemStatus {
PENDING
UNDER_REVIEW
APPROVED
REJECTED
}

Add to User model: country String? // e.g. "GE", "US"

Extend or create FoodItem like this:
model FoodItem {
id String @id @default(cuid())
status ItemStatus @default(PENDING)
imageUrl String?
iconUrl String?
countryCodes String[] // e.g. ["GE", "US"]
seasonality String[] // e.g. ["winter", "summer"]
availabilityScore Int @default(50) // 0-100
allergyTags String[]
substitutionGroup String?
createdById String?
createdBy User? @relation(fields: [createdById], references: [id])
// keep or add all existing fields
}

For ExerciseLibrary: add only status ItemStatus @default(PENDING) (videoUrl already exists).
Create two new tables: SubstitutionMap and MasterTemplate (for Hybrid System).
Add proper indexes on status, countryCodes, availabilityScore, etc.

NEW SERVICES (create in src/modules/):

- IngredientFilterService.ts
- ExerciseFilterService.ts
- SubstitutionEngine.ts
- TemplateService.ts
- TrainerContributionService.ts (or extend food/exercise modules)
- (Phase 2 only) PlanMemoryService.ts + AIModeratorService.ts

NEW DATA FLOW:
User profile → FilterService (country priority: activeGym.country → user.country → global popular fallback) → SubstitutionEngine → TemplateService → Memory check (Redis) → Moderator LLM → Store plan + archive

NON-NEGOTIABLE RULES:

- Never touch Flutter or mobile code except adding the searchable country dropdown and validation on the auth screen
- Use Redis for caching filters and plan memory
- Trainer-created items default to PENDING
- Super admin can change status + attach media
- Add graceful fallback for "no ingredients/exercises left"
- Update seeds to status=APPROVED
- Add full JSDoc and inline comments

After each phase output exactly:

1. List of files created/modified
2. Exact Prisma migration command
3. Summary of new data flow
4. Remaining risks

Start with Phase 1 only.
First confirm in one sentence that you understand the order and all requirements, then begin Phase 1.

╔══════════════════════════════════════════════════════════════════════════════╗
║ AMIRANI — MASTER PRODUCT SUPREMACY DIRECTIVE ║
║ "The world's first unified health operating system" ║
╚══════════════════════════════════════════════════════════════════════════════╝

You are the lead architect of Amirani — a Flutter/Node.js/PostgreSQL platform
built to be simultaneously the #1 gym management system, the #1 nutrition
tracking app, and the #1 AI personal trainer in the world. Not one of the best.
The best. Each pillar must be able to stand alone and defeat its category leader
(Mindbody, MyFitnessPal, Fitbod) head-to-head — and together they form an
integration moat that no single-category competitor can ever replicate.

Every feature decision, schema change, API endpoint, UI screen, and AI prompt
must be evaluated against this north star before it is built.

The existing stack is:
Backend → Node.js / Express / TypeScript / Prisma / PostgreSQL / Redis /
Socket.io / Stripe Connect / multi-provider AI (OpenAI, Anthropic,
Gemini, Azure, Deepseek)
Mobile → Flutter 3 / Riverpod / GoRouter / Dio / Hive / Firebase FCM /
flutter_stripe / mobile_scanner / flutter_animate
Admin → Next.js 16 / React 19 / Zustand / TanStack Query / Tailwind v4 /
Shadcn/ui

The 39-model Prisma schema already contains WorkoutPlan, DietPlan, DailyProgress,
GymMembership, Attendance, ProgressRoom, UserChallenge, and 32 more models.
Build on what exists. Never create a duplicate model or endpoint.

══════════════════════════════════════════════════════════════════════════════
PILLAR 1 — GYM MANAGEMENT SYSTEM (target: surpass Mindbody, Glofox, PushPress)
══════════════════════════════════════════════════════════════════════════════

CURRENT GAPS TO CLOSE (ranked by competitive impact):

1. POINT-OF-SALE MODULE
   Build a first-class POS inside the admin and a staff-facing Flutter screen.
   - Products & services catalog (supplements, merchandise, day passes, PT sessions)
   - Cart with discounts, tax rules per jurisdiction
   - Split tender (cash + card), Stripe Terminal integration for card-present
   - End-of-day cash reconciliation linked to existing Deposit model
   - Receipt via email/SMS using existing Notification infrastructure
     Schema: Add Product, SaleOrder, SaleOrderItem, TaxRule models to Prisma.

2. DIGITAL WAIVER & E-SIGNATURE ENGINE
   Members cannot access a gym until they sign the current membership agreement.
   - PDF template per gym (uploaded via existing /api/upload)
   - Versioned waiver — if gym updates T&Cs, all members must re-sign
   - Signature captured on mobile (finger draw or typed name + timestamp)
   - Immutable audit trail stored in AuditLog
     Schema: Add WaiverTemplate, WaiverSignature models.

3. STAFF ROTA & SHIFT SCHEDULING
   - Drag-and-drop weekly schedule in admin
   - Staff roles: Receptionist, Trainer, Manager, Cleaner
   - Shift swap requests with manager approval
   - Overtime alerts and cost projection
   - Push notification to staff when schedule is published (existing NotificationService)
     Schema: Add StaffShift, ShiftSwapRequest models.

4. LOCAL PAYMENT GATEWAY ABSTRACTION
   Stripe-only kills the Georgian/CIS market. Build a PaymentGateway adapter
   pattern (identical to the existing DoorAdapter pattern in door-access module).
   - Adapters: Stripe (existing), BOG (Bank of Georgia), TBC Pay, PayPal
   - Active gateway selected per gym via GymSettings
   - All adapters return a unified PaymentResult type
   - Zero changes to existing payment UI when gateway switches

5. WHITE-LABEL MOBILE APP
   Gym owners need their brand, not Amirani's.
   - Flutter flavor system: one codebase, per-gym flavor config
   - Each flavor: app name, bundle ID, primary color, logo, splash screen
   - Remote config (already have PlatformConfig) drives runtime theming
   - Admin page to set per-gym branding assets

6. ENTERPRISE FRANCHISE DASHBOARD
   - Cross-gym aggregated revenue, occupancy, churn in one view
   - Benchmark one gym against the network average
   - Bulk plan/equipment/automation push to all branches
   - Role: FRANCHISE_OWNER above GYM_OWNER in the existing Role enum

7. AUTOMATED LEAD CAPTURE & TRIAL CONVERSION FUNNEL
   - Public landing page per gym (SEO-friendly, no login required)
   - Visitor fills interest form → Lead record created
   - Automated 3-email drip sequence via existing AutomationRule engine
   - Lead → Trial Member → Paid conversion tracked in Analytics module
     Schema: Add Lead model.

8. OCCUPANCY & ZONE INTELLIGENCE
   - Real-time occupancy already tracked via Attendance check-in/check-out
   - Add zone mapping: free weights, cardio floor, pool, studio
   - Members see live heat-map in the mobile app before commuting
   - Historical peak-hour prediction using last 90 days of Attendance data
   - Push notification: "Your gym is at 20% capacity right now — great time to visit"

QUALITY STANDARDS FOR GYM MANAGEMENT:

- Every API response uses the existing success() wrapper from lib/response.ts
- Every new module follows the existing controller / service / repository pattern
- Role guards: use the existing requireRole() middleware, never inline role checks
- All financial operations are wrapped in Prisma transactions

══════════════════════════════════════════════════════════════════════════════
PILLAR 2 — DIET CREATOR & AI NUTRITION (target: surpass MyFitnessPal, MacroFactor, Carbon)
══════════════════════════════════════════════════════════════════════════════

CURRENT GAPS TO CLOSE (ranked by competitive impact):

1. FOOD DATABASE — THE SINGLE BIGGEST GAP
   Without a food database users cannot log meals. This is non-negotiable.
   - Integrate Nutritionix API (primary) with Open Food Facts as free fallback
   - Cache searched foods in a local FoodItem table (avoid repeated API costs)
   - Support: search by name, filter by brand, sort by macro density
   - USDA standard nutrients: calories, protein, carbs, fat, fiber, sugar, sodium,
     cholesterol, 13 micronutrients (Vitamin A/C/D/E/K, B6/B12, Iron, Calcium,
     Magnesium, Potassium, Zinc, Folate)
   - Portion size variants: grams, oz, cups, tbsp, pieces, slices — with conversion
     Schema: Add FoodItem, FoodPortion, FoodLog models. FoodLog links to DailyProgress.

2. BARCODE SCANNER — 2 DAYS OF WORK, MASSIVE UX WIN
   mobile_scanner is already in pubspec.yaml. Wire it up.
   - Tap the camera icon on the food log screen → scan barcode
   - Barcode → Nutritionix API lookup → pre-fill food log entry
   - Unknown barcode → "Add to our database" flow (crowdsourced)
   - Fallback: manual search if barcode not found

3. ADAPTIVE CALORIE & MACRO TARGETING (MacroFactor's core moat — build it better)
   MacroFactor charges $11.99/mo just for this. Amirani gets it for free as a feature.
   - Every Sunday: algorithm compares actual intake (FoodLog) vs target for past week
   - Compare against actual body weight logged in DailyProgress
   - If weight loss rate is below target AND intake was accurate → reduce by 50–75 kcal
   - If weight loss rate is above target → maintain or increase by 50 kcal
   - Algorithm is fully explainable: show member the exact math in the app
   - Override: member or trainer can lock targets and pause adaptive mode
     This connects Diet + Workout data: if member had 5 training sessions, calorie
     floor is automatically raised to prevent under-fuelling.

4. RECIPE BUILDER & MEAL TEMPLATES
   - Build a meal from multiple FoodItems with custom gram weights
   - Save as Recipe with a name, photo, and servings count
   - One-tap log an entire Recipe to today's diary
   - Share recipe to gym's ProgressRoom
   - AI "Recipe Optimizer": given a recipe, AI suggests macro-improved variants
     ("Swap regular yogurt for Greek yogurt to add 12g protein at same calories")
     Schema: Add Recipe, RecipeIngredient models.

5. RESTAURANT & DELIVERY INTEGRATION
   - Nutritionix restaurant database: 1,000+ US chain restaurant menus
   - Allow manual "restaurant meal" entries with fuzzy macro estimation
   - "I'm eating out tonight" mode: AI pre-allocates macros for likely restaurant
     meal and adjusts remaining day targets accordingly

6. MICRONUTRIENT DASHBOARD
   - Weekly averages for all 13 tracked micronutrients
   - Red/amber/green visual against RDA
   - AI insight: "You've been low on Vitamin D for 3 weeks. Consider a supplement
     or more salmon — here's a meal plan adjustment."
   - Connect to workout: low iron → AI reduces training intensity recommendation

7. PHOTO FOOD LOGGING (AI vision)
   - Member takes a photo of their plate
   - AI (vision model: GPT-4o or Gemini Vision) estimates meal composition
   - Returns list of detected foods with confidence %, portion estimates
   - Member confirms/adjusts and logs — dramatically lowers logging friction
   - This is not in ANY competitor's free tier. Amirani ships it at no extra cost.

8. COACH NUTRITION OVERSIGHT PORTAL
   - Trainer sees member's weekly nutrition summary alongside workout load
   - Can send nutrition notes ("Increase protein on rest days")
   - Can flag a member for nutritional review if logged calories are dangerously low
   - Integrates with existing TrainerProfile → GymMembership relationship

AI PROMPT TEMPLATE FOR DIET PLAN GENERATION (replace existing):

SYSTEM: You are a world-class registered dietitian and sports nutritionist with
expertise in evidence-based nutrition for athletic performance, body composition,
and long-term health. You generate precise, personalised, actionable meal plans
in structured JSON only. Never use markdown. Never add commentary outside JSON.

USER CONTEXT VARIABLES (inject all at runtime):

- goal: {goal} (lose_fat | build_muscle | maintain | athletic_performance | health)
- tdee: {calculatedTDEE} kcal (calculated from: weight, height, age, sex, activity)
- deficit_or_surplus: {±kcal} (derived from goal and rate_of_change preference)
- macro_split: {protein_g}/{carbs_g}/{fat_g} (calculated from body weight + goal)
- dietary_style: {style} (omnivore|vegetarian|vegan|keto|paleo|halal|kosher|gluten_free)
- allergies: [{list}]
- disliked_foods: [{list}]
- preferred_cuisines: [{list}]
- cooking_skill: {beginner|intermediate|advanced}
- budget_per_day_usd: {amount}
- meals_per_day: {3|4|5|6}
- training_days: [{Mon,Wed,Fri}] (affects pre/post workout meal timing)
- current_micronutrient_deficiencies: [{nutrient, severity}] (from FoodLog analysis)
- weeks_on_plan: {n} (for progressive calorie cycling)

OUTPUT SCHEMA:
{
"planMeta": {
"dailyCalories": number,
"macros": { "protein": number, "carbs": number, "fat": number, "fiber": number },
"weeklyCalorieCycle": [number, number, number, number, number, number, number],
"hydrationTargetMl": number,
"keyNutritionInsights": [string] // max 3 actionable insights
},
"weeks": [ // 4 weeks
{
"week": number,
"theme": string, // e.g. "Metabolic reset", "High-protein focus"
"days": [ // 7 days
{
"day": string,
"isTrainingDay": boolean,
"totalCalories": number,
"meals": [
{
"name": string,
"time": string,
"calories": number,
"protein": number, "carbs": number, "fat": number, "fiber": number,
"ingredients": [{ "item": string, "grams": number }],
"prepTimeMinutes": number,
"instructions": string,
"mealTiming": string // e.g. "30 min pre-workout", "post-workout recovery"
}
]
}
]
}
]
}

MEAL SWAP ENGINE — QUALITY STANDARDS (non-negotiable for dietary safety):

The meal swap engine is a medical-adjacent feature. Wrong macro or allergen
matching can break a ketogenic diet, trigger an allergic reaction, or invalidate
a calorie deficit. The following rules are ALWAYS enforced:

1. CALORIE MATCHING: alternative must be within ±15% of the original meal's calories
   (never show an alternative that would significantly change the day's total)

2. MACRO MATCHING: alternative must be within ±40% of both fat AND carbs of the
   original (prevents, e.g., a keto meal being swapped for a high-carb option)

3. DIETARY STYLE RATIOS: macro estimation MUST use per-style ratios, never a flat
   25/45/30% for everyone:
   keto=[protein 25%, carbs 5%, fat 70%]
   vegan=[protein 15%, carbs 60%, fat 25%]
   vegetarian=[protein 20%, carbs 50%, fat 30%]
   pescatarian=[protein 30%, carbs 40%, fat 30%]
   standard/halal/kosher/mediterranean=[protein 25%, carbs 45%, fat 30%]

4. HEALTH CONDITION / ALLERGY FILTER: runs FIRST, before any other filter.
   Keyword matching uses BOTH singular and plural forms of allergen ingredients.
   Lactose list includes: milk, cheese, yogurt, butter, cream, whey, ghee, kefir, labneh
   Nut list includes: almond, almonds, walnut, walnuts, cashew, cashews, pistachio,
   pistachios, peanut, peanuts, hazelnut, hazelnuts, pecan, pecans

5. FALLBACK: if macro+calorie filters eliminate ALL options, relax to calorie-only
   ±300 kcal window (never show zero alternatives — always give the member a choice)

6. SWAP EXECUTION: when a swap is confirmed, use the stored protein/fat/carbs values
   from the MealAlternative — never re-estimate from calories. The values shown in
   the UI must exactly match what gets written to DailyProgress.

QUALITY STANDARDS FOR NUTRITION:

- Every food logged creates a FoodLog record linked to DailyProgress
- DailyProgress.caloriesConsumed, .proteinConsumed, .carbsConsumed, .fatConsumed
  must be updated atomically with every FoodLog write (Prisma transaction)
- Adaptive target recalculation runs as a Sunday midnight cron job
- AI food photo analysis uses vision-capable model only; fallback to text search
  if vision model is unavailable or returns low confidence (<60%)

══════════════════════════════════════════════════════════════════════════════
PILLAR 3 — AI GYM TRAINER (target: surpass Fitbod, Whoop, Future, Freeletics)
══════════════════════════════════════════════════════════════════════════════

CURRENT GAPS TO CLOSE (ranked by competitive impact):

1. PROGRESSIVE OVERLOAD ENGINE (Fitbod's core moat — build it better with AI)
   Fitbod uses a fatigue algorithm. Amirani uses AI + fatigue + nutrition data.
   - After every completed WorkoutHistory, run progressive overload analysis:
     - If member completed all reps at target weight for 2 consecutive sessions
       on the same exercise → suggest weight increase (typically +2.5kg compound,
       +1kg isolation)
     - If member failed to complete reps → suggest deload (−10%) or technique note
     - Track training volume per muscle group (sets × reps × weight)
     - Apply Prilepin's table principles for strength, hypertrophy, endurance phases
   - AI overlay: "Based on your last 3 chest sessions and your protein intake this
     week (avg 142g vs 160g target), I'm keeping bench press weight the same and
     adding one extra set of flyes instead."
   - Visual: volume progression chart per muscle group over 12 weeks

2. WEARABLE & HEALTH DATA INTEGRATION
   - Apple HealthKit (iOS): resting HR, HRV, sleep, steps, active calories, VO2Max
   - Google Health Connect (Android): same data points
   - Data writes back to DailyProgress model (existing fields + new HR/HRV fields)
   - Recovery Score (0–100) calculated nightly from: sleep duration, HRV trend,
     resting HR, training load from previous 3 days
   - Recovery Score gates training intensity: if score < 40, AI auto-adjusts
     next workout to active recovery (low volume, RPE ≤ 6)
     Schema: Add DailyRecovery model with: hrv, restingHR, sleepHours, sleepQuality,
     recoveryScore, source (APPLE_HEALTH | GOOGLE_HEALTH | MANUAL).

3. AI FORM COACHING (video analysis)
   - Member records a set (squat, deadlift, bench, OHP, row — big 5 first)
   - Video uploaded to /api/upload, stored in existing CDN path
   - Backend sends frames to vision AI (GPT-4o Vision or Gemini Vision)
   - AI returns: rep count (accuracy check vs logged), form cues, specific errors
     ("Knee caving on rep 3 and 4 — focus on driving knees out"), injury risk flag
   - Trainer receives form analysis summary and can add their own note
   - This is future (Whoop Coach + AI form tools are launching this) — ship it first

4. PERIODISATION ENGINE
   Current AI generates a 4-week plan and stops. Build proper annual periodisation.
   - Macrocycles: 12–16 weeks with clearly defined phases
     Phase 1 (Weeks 1–4): Anatomical Adaptation — high reps, light weight, form focus
     Phase 2 (Weeks 5–8): Hypertrophy — 8–12 reps, 70–80% 1RM
     Phase 3 (Weeks 9–12): Strength — 4–6 reps, 80–90% 1RM
     Phase 4 (Week 13–14): Peak / Test — 1–3 rep maxes
     Phase 5 (Week 15–16): Deload — 50% volume, technique reset
   - Deload is auto-inserted after every 4th week of progressive loading
   - Plan adapts in real time: if member misses 3+ sessions in a phase, AI
     extends the phase rather than advancing to higher intensity

5. REAL-TIME WORKOUT COMPANION (in-session AI coach)
   The screen is live during the workout, not just for logging.
   - Rest timer with auto-start after logging a set
   - Mid-workout adjustments: if member marks a set as "too easy" → AI bumps
     next set weight; "too hard" → drops weight, adds rest time
   - Motivational cue at set 3 of 4, fatigue detection at set 4+
   - Auto-spot: if the logged weight for a set drops mid-workout, AI flags it
     as potential fatigue and recommends ending session or switching to accessory work
   - Voice cue option (TTS): "Rest for 90 seconds. Next: 4 sets of 10 at 80kg."

6. BODY COMPOSITION TRACKING & PREDICTION
   - Log: weight, body fat % (manual or smart scale via Bluetooth/HealthKit),
     waist/hip/chest/arm/thigh measurements, progress photos
   - AI body composition projection: "At your current rate, you will reach 15%
     body fat in approximately 11 weeks. This is your projected weight loss curve."
   - Photo comparison: side-by-side 4-week / 8-week / 12-week progress photos
   - DEXA-style estimates from measurements using validated anthropometric formulas
     (Jackson-Pollock, Navy method) as proxy when no scale data available

7. EXERCISE ENCYCLOPAEDIA (1,200+ exercises, beating Fitbod's library)
   - Exercise model: name, muscle groups (primary + secondary), equipment required,
     difficulty, mechanics (compound/isolation), force (push/pull/static/hinge),
     laterality (bilateral/unilateral), video URL, cue list, common mistakes list
   - Filterable by: available equipment, target muscle, difficulty, movement pattern
   - AI substitution engine: "You don't have a barbell today — here are 3 equivalent
     exercises with dumbbells that hit the same primary movers at the same intensity."
     Schema: Extend ExerciseSet model with exerciseLibraryId FK. Add ExerciseLibrary,
     MuscleGroup, ExerciseSubstitution models.

8. TRAINER INTELLIGENCE DASHBOARD
   Human trainers on the platform get AI superpowers:
   - AI weekly summary for each client: "Alex had 3 sessions this week (target 4),
     average protein 118g (target 160g), progressive overload stalled on bench press
     for 3 weeks. Recommended action: book a technique review session."
   - Batch plan generation: trainer sets a template, AI personalises for each client
   - Client comparison view: rank clients by consistency, progress, engagement
   - Trainer earns performance score based on client results (gamification for trainers)

AI PROMPT TEMPLATE FOR WORKOUT PLAN GENERATION (replace existing):

SYSTEM: You are an elite strength and conditioning coach, certified in NSCA-CSCS,
NASM-CPT, and FMS. You design evidence-based, periodised training programs that
produce measurable results. You write in structured JSON only. Never markdown.

USER CONTEXT VARIABLES:

- goal: {goal} (build_strength | hypertrophy | fat_loss | endurance | athletic | rehab)
- training_age: {years} (beginner <1yr | intermediate 1–3yr | advanced 3yr+)
- days_per_week: {3|4|5|6}
- session_duration_minutes: {45|60|75|90}
- available_equipment: [{barbell|dumbbell|cables|machines|bodyweight|kettlebell|bands}]
- injuries_or_limitations: [{body_part, severity, restriction}]
- current_1rm_estimates: {squat: kg, deadlift: kg, bench: kg, ohp: kg} (if known)
- body_metrics: {weight_kg, height_cm, body_fat_pct, age, sex}
- recovery_score_today: {0–100} (from wearable or manual)
- nutrition_status: {avg_protein_g_last_7_days, caloric_surplus_or_deficit}
- phase: {anatomical_adaptation|hypertrophy|strength|peak|deload} // from periodisation engine
- week_in_phase: {1–4}
- previous_week_volume: { per_muscle_group: {sets, avg_rpe} } // from WorkoutHistory

OUTPUT SCHEMA:
{
"planMeta": {
"phase": string,
"weekInPhase": number,
"primaryGoal": string,
"estimatedWeeklyVolumeSets": number,
"coachNote": string // 1-sentence personalised insight
},
"days": [
{
"dayName": string,
"sessionType": string, // "Upper Hypertrophy", "Lower Strength", "Active Recovery"
"estimatedDurationMinutes": number,
"warmup": [{ "exercise": string, "sets": number, "reps": string, "restSeconds": number }],
"mainWork": [
{
"exerciseLibraryId": string, // matched to ExerciseLibrary
"exerciseName": string,
"muscleGroupPrimary": string,
"muscleGroupsSecondary": [string],
"sets": number,
"reps": string, // "8-10" or "5" or "AMRAP"
"rpe": number, // Rate of Perceived Exertion 1–10
"restSeconds": number,
"tempoEccentric": number, // seconds
"tempoPause": number,
"tempoConcentrice": number,
"progressionNote": string, // e.g. "Increase 2.5kg when all reps achieved"
"substituteOptions": [string] // exercise names if equipment unavailable
}
],
"cooldown": [{ "exercise": string, "duration": string }],
"sessionNotes": string
}
]
}

QUALITY STANDARDS FOR AI TRAINER:

- Progressive overload analysis runs as a post-workout background job (queue)
- Recovery score recalculated every morning at 06:00 local time via cron
- Vision AI form analysis is async: member gets a push notification when analysis ready
- All AI-generated plans store raw prompt + response in AIUsageLog for debugging
- ExerciseLibrary seeded with minimum 200 exercises at launch; crowdsource additions

══════════════════════════════════════════════════════════════════════════════
PILLAR 4 — SOCIAL ENGINE & PROGRESS ROOMS (target: surpass Strava's community, beat Whoop Unite)
══════════════════════════════════════════════════════════════════════════════

The ProgressRoom is the social glue that makes members stay. Accountability,
competition, and community are the highest predictors of long-term gym retention.
No competitor combines a leaderboard with real nutrition + workout data. Amirani does.

ROOM TYPES:
- GYM room: created by gym owner/admin, auto-visible and joinable by ALL active-plan
  members of that gym. No invite code needed.
- USER room: created by any member, invite-only. Private by default.

ROOM MECHANICS — QUALITY STANDARDS:

1. LEADERBOARD & SCORING
   - Scoring is composite (not just check-ins): points = (check_ins × 10) +
     (workout_sessions × 15) + (streak_days × 5) + (challenges_completed × 25)
   - Top-3 rendered as a PODIUM (2nd | 1st | 3rd) with distinct visual treatment
     (gold/silver/bronze tiers, animated crown on 1st place)
   - Positions 4+ shown in a ranked list below the podium
   - Leaderboard refreshes in real time via Socket.io room-specific channel
   - Weekly reset option per room (creator toggles)

2. CHALLENGES
   - Creator can set a room challenge: e.g. "5 check-ins this week", "Log 3 workouts",
     "Hit protein target 5 days"
   - Challenge progress tracked automatically from existing DailyProgress / Attendance
   - Members who complete challenge earn a badge shown on their profile
   - Schema: Add RoomChallenge, ChallengeProgress models

3. INVITE CODE SECURITY
   - Invite code is NEVER auto-displayed. It is accessed only via explicit "Share" action
     (native share sheet, not clipboard auto-copy)
   - Code is regeneratable by creator; old codes invalidated immediately
   - Link format: amirani://rooms/join/{code} (deep link)

4. MEMBER MANAGEMENT
   - Creator can kick any member (soft-delete RoomMember record, audit log entry)
   - Creator can transfer ownership to another member
   - Creator can set room capacity limit
   - Creator can set room as public (discoverable in gym's room list) or private

5. NICKNAME / DISPLAY NAME
   - Each member can set a room-specific nickname (stored on RoomMember.displayName)
   - Tap own name in leaderboard → inline edit field
   - Falls back to user's global display name if no room nickname set

6. ROOM FEED
   - Activity feed: check-in events, PR achievements, challenge completions
   - Members can react with emoji to feed events (no text posts — keep it clean)
   - Feed items generated automatically from existing data — zero manual entry required

7. ROOM THEMING
   - All room screens use the app's global dark theme (AppTheme.darkBackground)
   - Room accent color: set by creator from a curated palette (10 options)
   - Consistent card style: rounded corners (16px), subtle gradient overlay on banners

QUALITY STANDARDS FOR ROOMS:
- Real-time leaderboard uses Socket.io; fall back to polling every 60s if socket disconnected
- All room mutations (kick, rename, challenge create) emit socket events to all members
- Room data is cached in Hive (offline read); mutations queue and sync on reconnect
- Member count cap per room: 500 (enforce server-side)

══════════════════════════════════════════════════════════════════════════════
PILLAR 5 — THE INTEGRATION MOAT (what no single competitor can ever replicate)
══════════════════════════════════════════════════════════════════════════════

The reason Amirani wins is not that each pillar is the best in isolation — it is
that all three share a single data graph that makes each one smarter.

INTEGRATION RULES (enforce these everywhere):

Rule 1 — WORKOUT INFORMS DIET
After every logged workout:

- Calculate calories burned (MET × weight × duration; or use HealthKit active cal)
- Add burned calories to today's DailyProgress.caloriesExpended
- If total_kcal_burned > 400: trigger "Refuel Reminder" push notification with
  specific food suggestion from current DietPlan's post-workout meal
- Adaptive calorie engine uses workout load to set next-day calorie floor

Rule 2 — DIET INFORMS WORKOUT
Before generating or adjusting a workout:

- Read last 7 days of DailyProgress.proteinConsumed
- If avg_protein < (0.8 × body_weight_kg): AI reduces training volume by 15%
  and adds a coach note: "Your protein intake is limiting recovery. Volume
  reduced to prevent overtraining until nutrition improves."
- If caloric_deficit > 700 kcal/day: AI prevents strength phase advancement
  and adds note: "Aggressive deficit detected. Maintaining hypertrophy phase
  to preserve muscle mass."

Rule 3 — GYM CHECK-IN TRIGGERS INTELLIGENT CONTEXT
When member taps QR check-in:

- Read today's workout plan day → surface it on the home screen immediately
- Read gym's current zone occupancy → suggest least crowded time for compound lifts
- If rest day and member checks in anyway → offer "Active Recovery" quick-start
- If it is the member's first visit this week and it is Thursday → escalate
  "Get back on track" session with trainer via automated message

Rule 4 — RECOVERY GATES EVERYTHING
If DailyRecovery.recoveryScore < 35:

- Workout AI: switch to active recovery session, flag to trainer
- Diet AI: increase carbohydrates by 15% for recovery glycogen replenishment
- Gym: show "Rest Day Recommended" banner on home screen with rationale
- Auto-notify trainer if member ignores and checks in anyway

Rule 5 — TRAINER SEES THE WHOLE PICTURE
Trainer dashboard shows per-member unified view:

- This week: [3/4 workouts] [avg protein 138g/160g] [2 gym visits] [recovery avg 71]
- Trend: [weight -0.8kg] [body fat -0.4%] [bench +5kg] [consistency 78%]
- AI recommendation for trainer: one-sentence suggested action
  No competitor offers this. Future.co charges $149/mo for a human coach with
  far less data. Amirani gives every gym's trainers this for free.

Rule 6 — SOCIAL ACCOUNTABILITY LOOP
When a member's weekly check-in count drops below their room's average:

- Push notification: "Your room is pulling ahead — you're 3 check-ins behind the average"
- If member misses challenge deadline with progress > 50%: send encouragement + link to gym
- Room leaderboard position drop of 3+ places triggers a "comeback" notification
- These notifications are opt-in per room (default: on) and honour quiet hours (22:00–07:00)

Rule 7 — OCCUPANCY × WORKOUT PERSONALISATION
If member's workout includes heavy compound lifts (squat, deadlift, bench):

- Check real-time zone occupancy for free weights area
- If >80% full: offer to reschedule the session or swap to a machine alternative
- If member accepts reschedule: AI adjusts the day's workout using available
  equipment for current occupancy, keeping the same muscle groups

══════════════════════════════════════════════════════════════════════════════
UNIVERSAL ENGINEERING STANDARDS
══════════════════════════════════════════════════════════════════════════════

BACKEND:

- All endpoints: authenticate with existing requireAuth middleware first
- Role guards: use requireRole() from existing middleware
- All responses: use success() from lib/response.ts — never res.json() directly
- Error responses: use the { error: { message, code } } envelope consistently
- New Prisma models: define in schema.prisma, run migration, never raw SQL
- Background jobs: use setInterval pattern from index.ts for recurring tasks
- Queue heavy AI calls: do not block HTTP response threads
- Every AI call must: log to AIUsageLog, handle provider timeout gracefully,
  fall back to secondary provider if primary returns error

MOBILE DESIGN SYSTEM STANDARDS:

- Global theme: dark-first. AppTheme.darkBackground is the default surface.
  Never ship a screen with a white/light background unless it is explicitly a
  document view (waiver PDF, receipt).
- Typography hierarchy: 3 weights only (Regular/Medium/SemiBold), Inter font family
- Spacing: 4px grid — all padding/margin values are multiples of 4
- Border radius: cards=16px, buttons=12px, chips=8px, dialogs=20px
- Elevation: use color shifts (+8% brightness) instead of shadows on dark backgrounds
- Icon set: Lucide icons (already in stack). No mixing of icon families.
- Interactive feedback: every tappable element has a ripple or scale animation (0.95×)
- Bottom sheets: always use DraggableScrollableSheet for tall content; max 90% screen height
- Empty states: illustration + headline + CTA button — never a plain "No data" text
- Error states: icon + friendly message + retry button — never raw exception messages to users

GAMIFICATION STANDARDS (cross-pillar):

Retention is driven by progress visibility and reward loops. These rules apply globally:

- STREAK TRACKING: daily streak counter on home screen. Break = shame-free reset message.
  Streak counts: consecutive days with at least 1 check-in OR 1 logged workout OR
  1 complete nutrition day (≥80% of calorie target logged)
- BADGES: awarded for milestones (first check-in, 7-day streak, 30-day streak,
  first PR, first room challenge completed, first meal swap). Displayed on profile.
  Schema: Add Badge, UserBadge models.
- LEVEL SYSTEM: XP accumulates from: check-ins (+10), workouts (+15), nutrition days (+8),
  PRs (+30), challenges (+25). Level thresholds: 0/100/300/600/1000/1500/2500/4000...
  Level is shown on profile and leaderboards (not hidden vanity — it represents effort)
- PERSONAL RECORDS: auto-detected when a logged set exceeds previous max weight for
  that exercise. Triggers confetti animation + push notification + room feed event.
- WEEKLY RECAP: every Sunday evening, push notification with member's weekly summary:
  "You crushed it: 4 workouts, protein hit 5/7 days, up 2 spots in your room. 🏆"
  (Only sent if member had at least 1 activity that week)

MOBILE (Flutter):

- All state: Riverpod providers in features/{feature}/presentation/providers/
- All API calls: data layer only, via repository → remote_data_source → Dio
- Error handling: throw typed Failure subclasses, never bare catch (e)
- Offline: write-through to Hive on every successful API response
- Animations: flutter_animate — no raw AnimationController unless unavoidable
- Colors: always AppTheme constants — never hardcoded hex values
- Loading states: every async operation must show a shimmer or progress indicator
- Empty states: every list screen must have a designed empty state, not a blank page

ADMIN (Next.js):

- State: Zustand for global, TanStack Query for server state — never useState for API data
- All API calls through lib/api.ts typed interfaces — never fetch() directly in components
- Loading: Skeleton components (shadcn) for all data-fetching states
- Error boundaries around every dashboard section
- Tables: TanStack Table for all data grids (sortable, filterable, paginated)

AI CONVERSATIONAL ASSISTANT (cross-pillar — the member's 24/7 coach):

Every member has access to an AI chat interface that knows their full data graph.
This is NOT a generic chatbot. It is a specialist that speaks about THIS member only.

Context injected into every conversation:
- Current DietPlan summary (calories, macros, dietary style, allergies)
- Last 7 WorkoutHistory sessions (exercises, volume, PRs)
- DailyProgress averages (last 14 days: calories, protein, weight trend)
- DailyRecovery.recoveryScore (today)
- Active RoomChallenge progress
- Any flagged injuries or limitations

Capabilities:
- Answer nutrition questions with their specific plan data: "Can I eat X today?"
- Explain workout adjustments: "Why did my plan reduce volume this week?"
- Suggest meal swaps inline: "What can I eat instead of dinner tonight?"
- Motivational check-ins when streak is at risk
- Escalate to human trainer if message contains injury/pain keywords

Rules:
- NEVER give medical diagnoses. If message contains: "pain", "injury", "hurt", "torn",
  "swollen", "doctor" — respond with empathy + recommend consulting a healthcare provider
- NEVER override a trainer's explicit instruction without noting the conflict
- All conversations stored in ConversationLog (existing model) linked to userId
- Cheapest capable model for casual questions (Deepseek/Haiku);
  most capable (GPT-4o / Claude Opus) for plan analysis and injury-adjacent queries

AI QUALITY BAR:

- All AI-generated plans must be validated against the JSON schema before saving
- If AI returns invalid JSON: retry once with "Your previous response was not
  valid JSON. Return only the JSON object, no other text." then fail gracefully
- Plans are regenerated on demand if member changes their preferences or metrics
- AI explanations must be in the member's language (detect from device locale)
- Token costs: use the cheapest capable model for simple tasks (Deepseek for
  recipe suggestions), most capable for complex plans (GPT-4o / Claude Opus)

PERFORMANCE TARGETS:

- API P95 response time: <300ms (excluding AI calls)
- AI plan generation: <8 seconds P95 (stream response to mobile if >3s)
- Mobile app cold start: <2 seconds
- Admin dashboard initial load: <1.5 seconds
- Offline mode: all read operations must work without network

SECURITY NON-NEGOTIABLES:

- JWT tokens: access token 15min, refresh token 30 days, rotation on every refresh
- All financial endpoints: require re-authentication (2FA or PIN re-entry)
- File uploads: validate MIME type server-side, virus scan before CDN storage
- AI prompts: sanitise all user-provided strings before injection into prompts
- Rate limiting on all public endpoints: existing infrastructure, apply consistently
- PII: body metrics, health conditions, medical info — encrypted at rest, never logged

══════════════════════════════════════════════════════════════════════════════
LAUNCH READINESS CHECKLIST
══════════════════════════════════════════════════════════════════════════════

Before any feature is marked done:
□ API endpoint has integration test covering success + auth failure + validation error
□ Mobile screen has loading state, error state, empty state, and success state
□ Admin page has role guard (cannot be accessed by wrong role)
□ New Prisma model has cascading delete rules set correctly
□ AI prompt has been tested with 3 different user profiles
□ Any cron job is idempotent (safe to run twice without duplicate effects)
□ Push notifications have been tested on both iOS simulator and Android emulator
□ New feature does not regress any existing feature in the same module
□ All screens use dark theme (AppTheme constants — zero hardcoded hex values)
□ Meal-adjacent features: allergy and health condition filter verified with edge cases
□ Social features: Socket.io event emitted for every state change visible to other users
□ Financial features: end-to-end tested with both Stripe test mode AND local gateway adapter
□ AI chat responses containing injury/pain keywords route to safe escalation path
□ Gamification: XP/badge awarded correctly and does not double-award on retry/refresh

══════════════════════════════════════════════════════════════════════════════
SUCCESS DEFINITION
══════════════════════════════════════════════════════════════════════════════

Amirani has achieved its goal when:

1. A user can cancel MyFitnessPal because Amirani tracks their food better
2. A user can cancel Fitbod because Amirani programs their training better
3. A gym owner can cancel Mindbody because Amirani runs their business better
4. A user stays because their friends are in a room and the leaderboard pulls them back
5. A user trusts the meal swap because it never breaks their diet or triggers an allergy
6. A trainer stays because no other platform gives them this depth of client intelligence
7. None of those competitors can ever replicate what Amirani does with the
   combination — because they do not own all four data layers simultaneously:
   gym operations + nutrition + training + social accountability

Build everything to that standard. Nothing less.

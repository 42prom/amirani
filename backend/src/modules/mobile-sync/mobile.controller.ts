import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';
import { serverError } from '../../lib/response';
import { PlatformConfigService } from '../platform/platform-config.service';
import { UserTier } from '@prisma/client';

/**
 * Identify "Hero Ingredient" (largest by protein or first)
 */
const getDayOfWeekEnum = (date: Date): string => {
  const days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
  return days[date.getUTCDay()]; // Use UTC for absolute stability
};

const getAnchorMonday = (): Date => {
  const now = new Date();
  const dayOfWeek = now.getUTCDay(); // 0 (Sun) - 6 (Sat)
  const daysToSubtract = (dayOfWeek - 1 + 7) % 7; 
  const anchorMonday = new Date(now);
  anchorMonday.setUTCDate(now.getUTCDate() - daysToSubtract);
  anchorMonday.setUTCHours(0, 0, 0, 0);
  return anchorMonday;
};

/**
 * Unified Meal Meta-Enrichment Helper
 * Canonical field: 'ingredients' — no fallback to legacy 'items'.
 * Exported for simulation & unit testing.
 */
export const enrichMeal = (meal: any) => {
  // Canonical field is 'ingredients'. Support one level of nesting only.
  const rawIngredients: any = meal.ingredients ?? [];

  let ingredients: any[] = [];
  if (Array.isArray(rawIngredients)) {
    ingredients = rawIngredients;
  } else if (rawIngredients && typeof rawIngredients === 'object' && Array.isArray(rawIngredients.ingredients)) {
    ingredients = rawIngredients.ingredients;
  }

  // Derive macros from ingredient aggregation only when top-level values are absent
  // PRECISE CALCULATION: Force summation of ingredients to ensure 1:1 math accuracy.
  // The ingredients are the source of truth; top-level fields are ignored if ingredients exist.
  const protein   = ingredients.reduce((s: number, i: any) => s + Number(i.protein  || 0), 0);
  const carbs     = ingredients.reduce((s: number, i: any) => s + Number(i.carbs    || 0), 0);
  const fats      = ingredients.reduce((s: number, i: any) => s + Number(i.fats     || 0), 0);
  const calories  = ingredients.reduce((s: number, i: any) => s + Number(i.calories || 0), 0);

  // Non-mutating sort — avoid modifying the source array
  const heroIngredient = ingredients.length > 0
    ? [...ingredients].sort((a: any, b: any) => Number(b.protein || 0) - Number(a.protein || 0))[0]?.name ?? null
    : null;

  const mappedIngredients = ingredients.map((i: any) => ({
    ...i,
    amount:   parseFloat(String(i.amount   || 0)),
    protein:  parseFloat(String(i.protein  || 0)),
    carbs:    parseFloat(String(i.carbs    || 0)),
    fats:     parseFloat(String(i.fats     || 0)), // canonical: 'fats' only
    calories: parseFloat(String(i.calories || 0)),
  }));

  return {
    ...meal,
    protein:          Math.round(protein),
    carbs:            Math.round(carbs),
    fats:             Math.round(fats),
    calories:         Math.round(calories), // UNIFIED: Primary key for mobile parity
    totalCalories:    Math.round(calories), // Legacy fallback
    heroIngredient,
    ingredientsCount: ingredients.length,
    ingredients:      mappedIngredients,
    ingredientSummary: ingredients.map((i: any) => i.name).join(', '),
    _debugIngredientCount: ingredients.length,
  };
};

/**
 * Infers the meal type for mobile DietPlanMapper._mapToPlannedMealType().
 *
 * Two plan creation paths produce meals with different naming conventions:
 *  - AI plans:      name = "BREAKFAST" (meal type keyword)
 *  - Trainer plans: name = "Chicken Salad" (recipe name) + timeOfDay = "08:00"
 *
 * Strategy:
 *  1. Check if `name` itself is a known meal type keyword (AI plans)
 *  2. Parse `timeOfDay` to infer meal category (Trainer plans)
 *  3. Fall back to `orderIndex` position heuristic
 */
const MEAL_TYPE_KEYWORDS: Record<string, string> = {
  'breakfast': 'BREAKFAST',
  'lunch': 'LUNCH',
  'dinner': 'DINNER',
  'snack': 'SNACK',
  'snack 1': 'SNACK 1',
  'snack 2': 'SNACK 2',
  'morning snack': 'SNACK 1',
  'afternoon snack': 'SNACK 2',
  'brunch': 'BREAKFAST',
  'supper': 'DINNER',
};

export const inferMealType = (mm: any): string => {
  const name = String(mm.name || '').toLowerCase().trim();

  // 1. Check if name IS a meal type keyword (AI plans output "BREAKFAST" as name)
  if (MEAL_TYPE_KEYWORDS[name]) return MEAL_TYPE_KEYWORDS[name];

  // 2. Infer from timeOfDay (trainer plans store "08:30" in timeOfDay)
  const timeStr = mm.timeOfDay ?? mm.time ?? '';
  if (timeStr) {
    const hour = parseInt(String(timeStr).split(':')[0], 10);
    if (!isNaN(hour)) {
      if (hour <= 10)  return 'BREAKFAST';
      if (hour <= 11)  return 'SNACK 1';
      if (hour <= 14)  return 'LUNCH';
      if (hour <= 17)  return 'SNACK 2';
      if (hour <= 22)  return 'DINNER';
    }
  }

  // 3. orderIndex position heuristic (0=breakfast, 1=snack/lunch, last=dinner)
  const idx = mm.orderIndex ?? 0;
  if (idx === 0) return 'BREAKFAST';
  if (idx === 1) return 'LUNCH';
  return 'DINNER';
};

/**
 * Unified Workout Routine Enrichment Helper
 * Aggregates muscle focus and normalizes exercise metadata
 */
export const enrichWorkoutRoutine = (routine: any) => {
  const exercises = (routine.exercises || []).map((ex: any) => ({
    ...ex,
    targetMuscles: ex.library
      ? [ex.library.primaryMuscle, ...(ex.library.secondaryMuscles || [])]
      : (ex.muscleGroupPrimary ? [ex.muscleGroupPrimary] : (ex.targetMuscles || [])),  // P2-B
    videoUrl: ex.library?.videoUrl ?? ex.mediaUrl ?? null,
    instructions: (ex.library?.cues?.join('\n') ?? ex.instructions) || 
      `1. Set up for ${ex.exerciseName}.\n2. Perform with controlled eccentric (lowering) phase.\n3. Maintain core stability and breathe throughout.`,
  }));

  // Smart Muscle Group Aggregation (Exercise -> Routine Focus)
  const muscleSet = new Set<string>();
  exercises.forEach((ex: any) => {
    if (Array.isArray(ex.targetMuscles)) {
      ex.targetMuscles.forEach((m: any) => muscleSet.add(String(m).toLowerCase()));
    }
  });

  const estimatedMinutes = routine.estimatedMinutes || (exercises.length * 10);
  // CX-5: heuristic calorie burn — 5 kcal/min is a conservative moderate-intensity estimate
  const estimatedCaloriesBurned = routine.estimatedCaloriesBurned ||
    Math.round(estimatedMinutes * 5);

  return {
    ...routine,
    exercises,
    targetMuscleGroups: Array.from(muscleSet),
    isOverride: routine.isOverride ?? false,
    estimatedMinutes,
    estimatedCaloriesBurned,
  };
};

export class MobileController {
  
  // GET /api/workout/plan
  static async getActiveWorkoutPlan(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;
      
      const activePlan = await prisma.workoutPlan.findFirst({
        where: { userId: userId, isActive: true },
        include: { 
          routines: { 
            where: { isDraft: false }, 
            orderBy: { scheduledDate: 'asc' }, 
            include: { exercises: { include: { library: true } } } 
          },
          masterTemplate: { 
            include: { 
              routines: { 
                orderBy: { orderIndex: 'asc' }, 
                include: { exercises: { orderBy: { orderIndex: 'asc' }, include: { library: true } } } 
              } 
            } 
          }
        },
        orderBy: { createdAt: 'desc' }
      });

      if (!activePlan) {
        return res.status(200).json({ data: null });
      }

      // ── HYDRATE HYBRID WORKOUT PLAN (Templates + Calendar Overrides) ──
      const templateRoutines: any[] = (activePlan as any).masterTemplate?.routines || [];
      const literalRoutines: any[]  = (activePlan as any).routines || [];

      // Load PlanDeltaOverrides for this plan so we can apply member-specific tweaks
      const deltaOverrides: any[] = await prisma.planDeltaOverride.findMany({
        where: { workoutPlanId: activePlan.id },
      });
      const overridesByMasterRoutine = new Map<string, any[]>();
      const overridesByMasterExercise = new Map<string, any>();
      for (const ov of deltaOverrides) {
        if (ov.masterRoutineId) {
          const list = overridesByMasterRoutine.get(ov.masterRoutineId) || [];
          list.push(ov);
          overridesByMasterRoutine.set(ov.masterRoutineId, list);
        }
        if (ov.masterExerciseSetId) {
          overridesByMasterExercise.set(ov.masterExerciseSetId, ov);
        }
      }

      // Helper: apply exercise-level overrides to a template routine's exercises
      const applyExerciseOverrides = (exercises: any[]): any[] =>
        exercises.map((ex: any) => {
          const ov = overridesByMasterExercise.get(ex.id);
          if (!ov) return ex;
          const vals = ov.overriddenValues || {};
          if (ov.mutationType === 'SWAP_EXERCISE') {
            return { ...ex, ...vals };
          }
          if (ov.mutationType === 'ALTER_SETS') {
            return { ...ex, ...vals };
          }
          return ex;
        });

      // Determine mapping strategy: explicit dayOfWeek wins over index-based cycling
      const hasExplicitDayOfWeek = templateRoutines.some((r: any) => r.dayOfWeek != null);

      // Hydration window: always project from this Monday so the 28-day window
      // covers the current week — aligns with mobile day selector (0–6).
      const anchorDate = getAnchorMonday();
      anchorDate.setUTCHours(0, 0, 0, 0);

      // Phase anchor: locked to the plan's actual startDate so the workout
      // rotation is deterministic regardless of when the app is opened.
      // Without this, index-based cycling used (targetDate - thisMonday) which
      // produced different routines for the same calendar date each week.
      const rawWorkoutPlanStart = activePlan.startDate
        ? new Date(activePlan.startDate)
        : anchorDate;
      rawWorkoutPlanStart.setUTCHours(0, 0, 0, 0);
      const workoutPhaseAnchor = rawWorkoutPlanStart;

      // Use UTC midnight to avoid local-timezone date drift across the 28-day window
      const todayUTC = new Date();
      todayUTC.setUTCHours(0, 0, 0, 0);

      const hydratedRoutines: any[] = [];
      const DAYS_TO_SYNC = 28;

      for (let i = 0; i < DAYS_TO_SYNC; i++) {
        const targetDate = new Date(anchorDate);
        targetDate.setUTCDate(anchorDate.getUTCDate() + i);
        const dateString = targetDate.toISOString().split('T')[0];

        // 1. Literal calendar override takes highest priority
        const literal = literalRoutines.find((r: any) => {
          if (!r.scheduledDate) return false;
          return new Date(r.scheduledDate).toISOString().split('T')[0] === dateString;
        });

        if (literal) {
          hydratedRoutines.push(enrichWorkoutRoutine({
            ...literal,
            isOverride: true,
            scheduledDate: targetDate,
          }));
          continue;
        }

        if (templateRoutines.length === 0) continue; // No template — nothing to hydrate

        const currentDayEnum = getDayOfWeekEnum(targetDate);
        let mr: any = null;

        if (hasExplicitDayOfWeek) {
          // Day-of-week template: match exactly — no match = rest day (intentional gap)
          mr = templateRoutines.find((r: any) => r.dayOfWeek === currentDayEnum) ?? null;
        } else {
          // Index-based template: use circular mapping (no dayOfWeek set by trainer).
          // Phase is relative to workoutPhaseAnchor (plan startDate) so the same
          // calendar date always resolves to the same routine index.
          const diffTime = targetDate.getTime() - workoutPhaseAnchor.getTime();
          const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
          const availableIndices = Array.from(
            new Set(templateRoutines.map((r: any) => r.orderIndex as number))
          ).sort((a, b) => a - b);

          // Guard: only cycle if there are entries to cycle through
          if (availableIndices.length > 0) {
            const loopIndex = ((diffDays % availableIndices.length) + availableIndices.length) % availableIndices.length;
            const targetIndex = availableIndices[loopIndex];
            mr = templateRoutines.find((r: any) => r.orderIndex === targetIndex) ?? null;
          }
        }

        if (mr) {
          // Apply any PlanDeltaOverrides to this master routine's exercises
          const enrichedExercises = applyExerciseOverrides(mr.exercises || []);
          hydratedRoutines.push(enrichWorkoutRoutine({
            ...mr,
            exercises:     enrichedExercises,
            id:            `v_${mr.id}_${i}`,
            planId:        activePlan.id,
            scheduledDate: targetDate,
            isOverride:    false,
            dayOfWeek:     currentDayEnum,
          }));
        }
        // If mr is null and hasExplicitDayOfWeek: this is an intentional rest day — omit it
      }

      // Final Payload for Mobile (Backwards compatible)
      (activePlan as any).routines = hydratedRoutines;
      delete (activePlan as any).masterTemplate;

      res.status(200).json({ data: activePlan });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // GET /api/sync/diet/plan — returns the user's active diet plan (trainer or AI)
  static async getActiveDietPlan(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;

      const activePlan = await prisma.dietPlan.findFirst({
        where: { userId, isActive: true } as any,  // P3-A: no isPublished gate (mirrors workout plan)
        include: {
          meals: { orderBy: { scheduledDate: 'asc' }, include: { ingredients: true } },
          masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' }, include: { ingredients: true } } } }
        },
        orderBy: { createdAt: 'desc' },
      } as any);

      if (!activePlan) {
        return res.status(200).json({ data: null });
      }

      // ── HYDRATE MASTER TEMPLATES (Project 28-Day Pattern from 1-Week Template) ──
      if ((activePlan as any).masterTemplate) {
        // FLAGSHIP: Anchor logic for synchronization parity
        let anchorMonday = getAnchorMonday();
        anchorMonday.setUTCHours(0, 0, 0, 0);

        // Projection window: always start from this Monday so the 28-day window
        // covers the current week — matching _loadMealsForDay(0..6) on mobile.
        // AI plans always have startDate = this Monday (queue.ts getStartOfToday),
        // so planStartDate === phaseAnchor for them. Trainer plans may start mid-week.
        const planStartDate = anchorMonday;

        // Phase anchor: locked to the plan's actual startDate so template day 1
        // maps to the assignment date, not always to this Monday.
        // Example: plan assigned Wednesday → template meal[0] shows on Wednesday.
        const rawDietPlanStart = activePlan.startDate
          ? new Date(activePlan.startDate)
          : anchorMonday;
        rawDietPlanStart.setUTCHours(0, 0, 0, 0);
        const dietPhaseAnchor = rawDietPlanStart;

        const DAYS_TO_PROJECT = 28;
        const projectedMeals: any[] = [];
        const masterMeals = (activePlan as any).masterTemplate.meals || [];

        // 1. Literal Overrides (Manually created or historically tracked)
        const literalMeals = ((activePlan as any).meals || []).map(enrichMeal);

        for (let i = 0; i < DAYS_TO_PROJECT; i++) {
          const targetDate = new Date(planStartDate);
          targetDate.setUTCDate(planStartDate.getUTCDate() + i);
          const dateString = targetDate.toISOString().split('T')[0];

          // Check if any literal meal exists for this date
          const overridesForDate = literalMeals.filter((m: any) => 
            m.scheduledDate && m.scheduledDate.toISOString().split('T')[0] === dateString
          );

          if (overridesForDate.length > 0) {
            projectedMeals.push(...overridesForDate);
            continue;
          }

          // 2. Map master meals to this date using dayOfWeek (explicit) or circular index fallback
          const hasDayOfWeekMeals = masterMeals.some((mm: any) => mm.dayOfWeek != null);
          let todaysMasterMeals: any[] = [];

          if (hasDayOfWeekMeals) {
            // Explicit day-of-week mapping — no match means a rest/free day for diet
            const currentDayEnum = getDayOfWeekEnum(targetDate);
            todaysMasterMeals = masterMeals.filter((mm: any) => mm.dayOfWeek === currentDayEnum);
          } else {
            // ── Index-based circular mapping (P3-B fix) ──────────────────────
            // Problem: orderIndex is a per-meal slot within a day (0=breakfast,
            // 1=lunch, 2=dinner). Taking unique orderIndex values gives [0,1,2]
            // which are treated as 3 separate "days" → one meal per day.
            //
            // Fix: detect the number of meals per day by finding the most common
            // orderIndex frequency, then group meals into day-buckets by dividing
            // their position in the sorted list by mealsPerDay.
            //
            // Example: 7 days × 3 meals = 21 meals with orderIndex 0,1,2,0,1,2,...
            // → mealsPerDay = 3 → dayGroup 0 = indices 0-2, dayGroup 1 = indices 3-5
            const sortedMeals = [...masterMeals].sort(
              (a: any, b: any) => (a.orderIndex ?? 0) - (b.orderIndex ?? 0)
            );
            // Count how many meals share orderIndex=0 to detect meals-per-day
            const mealsPerDay = sortedMeals.filter((mm: any) => (mm.orderIndex ?? 0) === 0).length || 1;
            // Build day-buckets: each bucket = one full day of meals
            const dayBuckets: any[][] = [];
            for (let k = 0; k < sortedMeals.length; k += mealsPerDay) {
              dayBuckets.push(sortedMeals.slice(k, k + mealsPerDay));
            }
            // Phase relative to dietPhaseAnchor (plan startDate) so template day 1
            // always lands on the actual assignment date, not on anchorMonday.
            const diffTime = targetDate.getTime() - dietPhaseAnchor.getTime();
            const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
            if (dayBuckets.length > 0) {
              const loopIndex = ((diffDays % dayBuckets.length) + dayBuckets.length) % dayBuckets.length;
              todaysMasterMeals = dayBuckets[loopIndex];
            }
          }

          if (todaysMasterMeals.length > 0) {
            const virtualMeals = todaysMasterMeals.map((mm: any) =>
              enrichMeal({
                ...mm,
                id:            `v_${mm.id}_${i}`,
                planId:        activePlan.id,
                scheduledDate: targetDate,
                isDraft:       false,
                // CANONICAL: Infer meal type for mobile DietPlanMapper._mapToPlannedMealType().
                // AI plans: name='BREAKFAST' (keyword) → maps directly.
                // Trainer plans: name='Chicken Salad' (recipe) → inferred from timeOfDay.
                type: inferMealType(mm),
              })
            );
            projectedMeals.push(...virtualMeals);
          }
        }

        // Fetch meal log entries for the projected window so each meal gets isLogged.
        const windowStart = new Date(planStartDate);
        windowStart.setUTCHours(0, 0, 0, 0);
        const windowEnd = new Date(planStartDate);
        windowEnd.setUTCDate(planStartDate.getUTCDate() + DAYS_TO_PROJECT);
        const mealLogEntries: Array<{ refId: string; date: Date }> = await (prisma as any).mealLog.findMany({
          where: { userId, date: { gte: windowStart, lt: windowEnd } },
          select: { refId: true, date: true },
        });
        const loggedSet = new Set(
          mealLogEntries.map(e => `${e.refId}::${e.date instanceof Date ? e.date.toISOString().split('T')[0] : String(e.date).split('T')[0]}`)
        );
        for (const meal of projectedMeals) {
          const mealDate = meal.scheduledDate instanceof Date
            ? meal.scheduledDate.toISOString().split('T')[0]
            : String(meal.scheduledDate ?? '').split('T')[0];
          // Virtual meal IDs are prefixed with v_{masterMealId}_{dayOffset} — extract the masterMealId.
          const lookupRef = String(meal.id ?? '').startsWith('v_')
            ? String(meal.id).split('_').slice(1, -1).join('_')
            : String(meal.id ?? '');
          meal.isLogged = loggedSet.has(`${lookupRef}::${mealDate}`);
        }

        (activePlan as any).meals = projectedMeals;
        // Override startDate so mobile DietPlanMapper builds calendar from this Monday.
        // Must be inside the masterTemplate branch where anchorMonday is in scope.
        (activePlan as any).startDate = anchorMonday;
      } else {
        // Instance meals (trainer-assigned literal meals) — inject inferred type
        (activePlan as any).meals = ((activePlan as any).meals || []).map((m: any) =>
          enrichMeal({ ...m, type: m.type ?? inferMealType(m) })
        );
      }
      
      // ── DRAFT SIGNAL: Let mobile show "plan pending" instead of a blank calendar ──
      const totalMasterMeals  = (activePlan as any).masterTemplate
        ? ((activePlan as any).masterTemplate?.meals?.length ?? 0)
        : ((activePlan as any).meals?.length ?? 0);
      const draftMealsCount = ((activePlan as any).meals || []).filter((m: any) => m.isDraft === true).length;
      (activePlan as any).hasPendingDraftMeals = draftMealsCount > 0;
      (activePlan as any).draftMealsCount      = draftMealsCount;
      (activePlan as any).totalMealsCount      = totalMasterMeals;

      // ── SMART BAG (Daily Ingredient Inventory) ──
      // Run post-hydration on enriched meals using UTC date for consistency.
      const todayUTCString = new Date().toISOString().split('T')[0];
      const todayMeals = ((activePlan as any).meals || []).filter((m: any) => {
        if (!m.scheduledDate) return false;
        const d = m.scheduledDate instanceof Date ? m.scheduledDate : new Date(m.scheduledDate);
        return d.toISOString().split('T')[0] === todayUTCString;
      });

      const inventoryMap = new Map<string, number>();
      todayMeals.forEach((m: any) => {
        const mealIngredients: any[] = m.ingredients || [];
        mealIngredients.forEach((i: any) => {
          const name: string = i.name; // canonical field only
          if (!name) return;
          inventoryMap.set(name, (inventoryMap.get(name) || 0) + (i.amount || 1));
        });
      });

      (activePlan as any).smartBagEntries = Array.from(inventoryMap.entries()).map(([name, qty]) => ({
        name,
        qty: Math.round(qty * 100) / 100,
      }));

      // CLEANUP: Only remove template after all metadata is derived
      delete (activePlan as any).masterTemplate;

      if (((activePlan as any).meals?.length ?? 0) === 0) {
        logger.warn(`[SYNC_DIET] Empty plan detected for user ${userId}. Master Template for ID: ${activePlan.id} may be compromised.`);
      }

      logger.debug('[SYNC_DIET] Serving active diet plan', { planId: activePlan.id, mealCount: ((activePlan as any).meals?.length ?? 0) });

      res.status(200).json({ data: activePlan });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // PATCH /api/sync/diet/meals/:refId/log
  // Toggle a meal's logged state for a specific date.
  // refId is Meal.id for literal meals or MasterMeal.id for template/virtual meals.
  // date param is required (ISO date string, e.g. "2026-04-17") so virtual meals
  // can be tracked per-date without a real row in the meals table.
  static async logMeal(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;
      const { refId } = req.params;
      const schema = z.object({
        date:   z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'date must be YYYY-MM-DD'),
        logged: z.boolean(),
      });
      const parsed = schema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(422).json({ success: false, error: parsed.error.flatten() });
      }
      const { date, logged } = parsed.data;
      const dateObj = new Date(date + 'T00:00:00.000Z');

      if (logged) {
        await (prisma as any).mealLog.upsert({
          where: { userId_refId_date: { userId, refId, date: dateObj } },
          create: { id: require('crypto').randomUUID(), userId, refId, date: dateObj },
          update: { loggedAt: new Date() },
        });
      } else {
        await (prisma as any).mealLog.deleteMany({
          where: { userId, refId, date: dateObj },
        });
      }

      logger.info('[MEAL_LOG] Meal log updated', { userId, refId, date, logged });
      res.status(200).json({ success: true, data: { refId, date, isLogged: logged } });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // GET /api/diet/macros?date=2024-02-25
  static async getDailyMacros(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;
      const dateString = req.query.date as string;
      const targetDate = dateString ? new Date(dateString) : new Date();
      
      // Start of day
      const startOfDay = new Date(targetDate.setHours(0, 0, 0, 0));
      const endOfDay = new Date(targetDate.setHours(23, 59, 59, 999));

      const dailyProgress = await prisma.dailyProgress.findFirst({
        where: { 
          userId, 
          date: { gte: startOfDay, lte: endOfDay } 
        }
      });

      // Fetch plan-level targets and user metrics in parallel.
      // Mobile overrides these with per-rotation-day targets from its cached plan (P1-D).
      const [activeDietPlan, metricsUser] = await Promise.all([
        prisma.dietPlan.findFirst({
          where: { userId, isActive: true },
          orderBy: { createdAt: 'desc' },
        }),
        prisma.user.findUnique({
          where: { id: userId },
          select: { weight: true, height: true, dob: true, gender: true },
        }),
      ]);

      // Compute a Mifflin-St Jeor estimate (× 1.55 moderate activity) as the
      // fallback when the active plan has no stored targets. This prevents the
      // macro ring from showing a hardcoded 2500 kcal that ignores the user's
      // actual body metrics (particularly wrong for small or inactive users).
      const estimateDailyCalories = (): number => {
        const w = metricsUser?.weight ? parseFloat(metricsUser.weight.toString()) : null;
        const h = metricsUser?.height ? parseFloat(metricsUser.height.toString()) : null;
        const age = metricsUser?.dob
          ? Math.floor((Date.now() - new Date(metricsUser.dob).getTime()) / (1000 * 60 * 60 * 24 * 365))
          : null;
        if (!w || !h || !age) return 2000;
        const bmr = (metricsUser?.gender === 'FEMALE')
          ? 10 * w + 6.25 * h - 5 * age - 161
          : 10 * w + 6.25 * h - 5 * age + 5;
        return Math.round(Math.max(1200, Math.min(bmr * 1.55, 4000)));
      };

      const fallbackCal = estimateDailyCalories();

      // Field names match DailyMacroModel on mobile (plural: targetFats/currentFats).
      // Targets here are plan-level averages; mobile merges per-day targets from cache.
      const data = {
        targetCalories: activeDietPlan?.targetCalories ?? fallbackCal,
        currentCalories: dailyProgress?.caloriesConsumed ?? 0,
        targetProtein:  activeDietPlan?.targetProtein  ?? Math.round(fallbackCal * 0.30 / 4),
        currentProtein: dailyProgress?.proteinConsumed ?? 0,
        targetCarbs:    activeDietPlan?.targetCarbs    ?? Math.round(fallbackCal * 0.40 / 4),
        currentCarbs:   dailyProgress?.carbsConsumed   ?? 0,
        targetFats:     activeDietPlan?.targetFats     ?? Math.round(fallbackCal * 0.30 / 9),
        currentFats:    dailyProgress?.fatsConsumed    ?? 0,
      };

      res.status(200).json({ data });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // GET /api/sync/tier-limits — returns user's effective tier limits + today's usage
  static async getTierLimits(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;
      const role: string = req.user!.role;

      // Map role to UserTier
      let tier: UserTier = 'FREE';
      if (role === 'GYM_MEMBER') tier = 'GYM_MEMBER';
      else if (role === 'HOME_USER') {
        const user = await prisma.user.findUnique({
          where: { id: userId },
          select: { saasSubscriptionStatus: true },
        });
        if (user?.saasSubscriptionStatus === 'ACTIVE') tier = 'HOME_PREMIUM';
      }

      const [limits, usage] = await Promise.all([
        PlatformConfigService.getTierLimits(tier),
        PlatformConfigService.checkUserAILimits(userId, tier),
      ]);

      res.status(200).json({
        data: {
          tier,
          limits: {
            aiRequestsPerDay:      limits.aiRequestsPerDay,
            aiTokensPerMonth:      limits.aiTokensPerMonth,
            workoutPlansPerMonth:  limits.workoutPlansPerMonth,
            dietPlansPerMonth:     limits.dietPlansPerMonth,
            canAccessAICoach:      limits.canAccessAICoach,
            canAccessDietPlanner:  limits.canAccessDietPlanner,
            canAccessAdvancedStats: limits.canAccessAdvancedStats,
            canExportData:         limits.canExportData,
            maxProgressPhotos:     limits.maxProgressPhotos,
          },
          usage: {
            dailyRequestsUsed:  usage.dailyRequestsUsed,
            dailyRequestsLimit: usage.dailyRequestsLimit,
            monthlyTokensUsed:  usage.monthlyTokensUsed,
            monthlyTokensLimit: usage.monthlyTokensLimit,
            canMakeRequest:     usage.canMakeRequest,
            monthlyLimitReached: (usage as any).monthlyLimitReached,
            dailyLimitReached:   (usage as any).dailyLimitReached,
          },
        },
      });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // POST /api/sync/recovery — log today's recovery check-in
  static async logRecovery(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;

      const schema = z.object({
        sleepHours:    z.number().min(0).max(24),
        energyLevel:   z.number().int().min(1).max(5),
        sorenessLevel: z.number().int().min(1).max(5),
        notes:         z.string().max(500).optional(),
      });

      const parsed = schema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.issues });
      }

      const { sleepHours, energyLevel, sorenessLevel, notes } = parsed.data;

      // Compute recovery score: sleep 40%, energy 30%, inverse soreness 30%
      const recoveryScore = Math.round(
        (Math.min(sleepHours, 8) / 8) * 40 +
        (energyLevel / 5) * 30 +
        ((6 - sorenessLevel) / 5) * 30
      );

      const today = new Date();
      today.setUTCHours(0, 0, 0, 0);

      const record = await prisma.dailyRecovery.upsert({
        where: { userId_date: { userId, date: today } },
        update: {
          sleepHours,
          sleepQuality: energyLevel * 2, // map 1–5 to 2–10
          recoveryScore,
          rawData: { energyLevel, sorenessLevel, notes: notes ?? null },
        },
        create: {
          userId,
          date: today,
          sleepHours,
          sleepQuality: energyLevel * 2,
          recoveryScore,
          source: 'MANUAL',
          rawData: { energyLevel, sorenessLevel, notes: notes ?? null },
        },
      });

      res.status(200).json({ data: record });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // GET /api/sync/recovery/today — get today's recovery record
  static async getTodayRecovery(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;

      const today = new Date();
      today.setUTCHours(0, 0, 0, 0);

      const record = await prisma.dailyRecovery.findUnique({
        where: { userId_date: { userId, date: today } },
      });

      res.status(200).json({ data: record ?? null });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // POST /api/sync/workout-history — create WorkoutHistory + CompletedSets
  static async logWorkoutHistory(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;

      const schema = z.object({
        routineId: z.string().optional(), // Allow virtual IDs (v_...) or real UUIDs
        idempotencyKey: z.string().max(100).optional(), // Client-generated key for dedup
        durationMinutes: z.number().int().min(1),
        notes: z.string().max(500).optional(),
        exercises: z.array(z.object({
          exerciseName: z.string().min(1),
          sets: z.array(z.object({
            weightKg: z.number().min(0),
            reps: z.number().int().min(0),
            rpe: z.number().int().min(1).max(10).optional(),
          })).min(1),
        })),
      });

      const parsed = schema.safeParse(req.body);
      if (!parsed.success) {
        return res.status(400).json({ error: 'Validation failed', details: parsed.error.issues });
      }

      const { routineId, idempotencyKey, durationMinutes, notes, exercises } = parsed.data;

      // ── IDEMPOTENCY: Return existing record if same key was already processed ──
      if (idempotencyKey) {
        const existing = await prisma.workoutHistory.findFirst({
          where: { userId, idempotencyKey },
          select: { id: true },
        });
        if (existing) {
          return res.status(200).json({ data: { historyId: existing.id, setsLogged: 0, deduplicated: true } });
        }
      }

      // ── Wrap the entire session log in a single transaction ──
      const result = await prisma.$transaction(async (tx) => {
        let finalRoutineId: string | null = routineId ?? null;

        // ── SNAP-TO-LITERAL: Convert virtual template IDs to real DB rows ──
        if (routineId && routineId.startsWith('v_')) {
          // Format: v_{masterRoutineId}_{virtualDayIndex}
          // masterRoutineId is a UUID and does not contain underscores, so split at first two '_'
          const firstUnderscore = routineId.indexOf('_');
          const secondUnderscore = routineId.indexOf('_', firstUnderscore + 1);
          const masterRoutineId = routineId.substring(firstUnderscore + 1, secondUnderscore);

          const templateRoutine = await tx.masterWorkoutRoutine.findUnique({
            where: { id: masterRoutineId },
            include: { exercises: true },
          });

          if (templateRoutine) {
            const activePlan = await tx.workoutPlan.findFirst({
              where: { userId, isActive: true, deletedAt: null } as any,
              select: { id: true },
            });

            if (!activePlan) throw new Error('No active workout plan found for snap-to-literal');

            // Materialize a permanent WorkoutRoutine row so history FK is valid
            const literalRoutine = await tx.workoutRoutine.create({
              data: {
                planId: activePlan.id,
                name: templateRoutine.name,
                scheduledDate: new Date(),
                estimatedMinutes: templateRoutine.estimatedMinutes,
                isDraft: false,
                exercises: {
                  create: templateRoutine.exercises.map((ex) => ({
                    exerciseName: ex.exerciseName,
                    exerciseLibraryId: ex.exerciseLibraryId,
                    targetSets: ex.targetSets,
                    targetReps: ex.targetReps,
                    targetWeight: ex.targetWeight,
                    restSeconds: ex.restSeconds,
                    orderIndex: ex.orderIndex,
                    rpe: ex.rpe,
                  })),
                },
              } as any,
            });
            finalRoutineId = literalRoutine.id;
          } else {
            // Master routine deleted — log without a routineId rather than failing
            finalRoutineId = null;
          }
        }

        // ── Create WorkoutHistory row ──
        const history = await tx.workoutHistory.create({
          data: {
            userId,
            routineId: finalRoutineId,
            durationMinutes,
            notes: notes ?? null,
            completedAt: new Date(),
            ...(idempotencyKey ? { idempotencyKey } : {}),
          } as any,
        });

        // ── Create all CompletedSet rows atomically ──
        const libraryCache = new Map<string, string | null>();
        const setRecords = [];

        for (const ex of exercises) {
          let libId = (ex as any).libraryId ?? null;
          
          // Try to match if libId missing and name exists
          if (!libId && ex.exerciseName) {
            if (libraryCache.has(ex.exerciseName)) {
              libId = libraryCache.get(ex.exerciseName);
            } else {
              const match = await tx.exerciseLibrary.findFirst({
                where: { name: { equals: ex.exerciseName, mode: 'insensitive' } },
                select: { id: true }
              });
              libId = match?.id ?? null;
              libraryCache.set(ex.exerciseName, libId);
            }
          }

          for (const s of ex.sets) {
            setRecords.push({
              exerciseName: ex.exerciseName,
              exerciseLibraryId: libId,
              actualSets: 1,
              actualReps: s.reps > 0 ? s.reps : null,
              actualWeight: s.weightKg > 0 ? s.weightKg : null,
              rpe: s.rpe ?? null,
              historyId: history.id,
            });
          }
        }

        if (setRecords.length > 0) {
          await tx.completedSet.createMany({ data: setRecords as any });
        }

        return { historyId: history.id, setsLogged: setRecords.length };
      });

      res.status(201).json({ data: result });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // GET /api/sync/progress?days=30
  static async getProgressSummary(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;
      const days = Math.min(parseInt(req.query.days as string) || 30, 90);

      const now = new Date();
      const windowStart = new Date(now);
      windowStart.setDate(windowStart.getDate() - days);
      windowStart.setHours(0, 0, 0, 0);

      const weekStart = new Date(now);
      weekStart.setDate(weekStart.getDate() - 6);
      weekStart.setHours(0, 0, 0, 0);

      const [user, activePlan, dailyRows, recoveryRows, workoutRows] = await Promise.all([
        prisma.user.findUnique({
          where: { id: userId },
          select: { weight: true, targetWeightKg: true, height: true },
        }),
        prisma.dietPlan.findFirst({
          where: { userId, isActive: true },
          orderBy: { createdAt: 'desc' },
          select: { targetCalories: true, targetProtein: true, targetCarbs: true, targetFats: true, targetWater: true },
        }),
        prisma.dailyProgress.findMany({
          where: { userId, date: { gte: windowStart } },
          orderBy: { date: 'asc' },
          select: {
            date: true, caloriesConsumed: true, proteinConsumed: true,
            carbsConsumed: true, fatsConsumed: true, waterConsumed: true,
            activeMinutes: true, tasksCompleted: true, tasksTotal: true,
          },
        }),
        prisma.dailyRecovery.findMany({
          where: { userId, date: { gte: windowStart } },
          orderBy: { date: 'asc' },
          select: { date: true, sleepHours: true, recoveryScore: true },
        }),
        prisma.workoutHistory.findMany({
          where: { userId, completedAt: { gte: weekStart } },
          select: { completedAt: true, durationMinutes: true, caloriesBurned: true, totalVolume: true },
          orderBy: { completedAt: 'asc' },
        }),
      ]);

      // ── Body ───────────────────────────────────────────────────────────────
      const currentWeightKg = user?.weight ? parseFloat(user.weight.toString()) : null;
      const targetWeightKg = user?.targetWeightKg ? parseFloat(user.targetWeightKg.toString()) : null;
      const heightCm = user?.height ? parseFloat(user.height.toString()) : null;

      // Weight as single log point (no history table — just current snapshot)
      const weightLogs = currentWeightKg != null
        ? [{ date: now.toISOString().split('T')[0], weightKg: currentWeightKg }]
        : [];

      // ── Today's macros ─────────────────────────────────────────────────────
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayRow = dailyRows.find(
        (r) => new Date(r.date).toDateString() === today.toDateString()
      );

      // ── Activity (last 7 days) ─────────────────────────────────────────────
      const last7 = dailyRows.filter((r) => new Date(r.date) >= weekStart);

      const workoutsThisWeek = workoutRows.length;
      const activeMinutesThisWeek = last7.reduce((s, r) => s + r.activeMinutes, 0);

      // ── TELEMETRY: High-resolution Caloric Burn Data ───────────────────────
      const caloriesBurnedThisWeek = workoutRows.length > 0
        ? workoutRows.reduce((s, w) => s + Number(w.caloriesBurned || (w.durationMinutes * 5)), 0)
        : activeMinutesThisWeek * 4;

      // Daily calories burned for chart — 7 day array (index 0 = 6 days ago)
      const caloriesBurnedLast7Days = Array.from({ length: 7 }, (_, i) => {
        const d = new Date(weekStart);
        d.setDate(d.getDate() + i);
        
        const dayWorkouts = workoutRows.filter(w => new Date(w.completedAt).toDateString() === d.toDateString());
        if (dayWorkouts.length > 0) {
           return dayWorkouts.reduce((s, w) => s + Number(w.caloriesBurned || (w.durationMinutes * 5)), 0);
        }

        const row = last7.find((r) => new Date(r.date).toDateString() === d.toDateString());
        return row ? row.activeMinutes * 4 : 0;
      });

      // ── Habit scores (0–1) ─────────────────────────────────────────────────
      const targetCal = activePlan?.targetCalories ?? 2000;
      const targetWater = activePlan ? parseFloat(activePlan.targetWater.toString()) : 3.0;

      const workoutDays = last7.filter((r) => r.activeMinutes >= 20).length;
      const workoutScore = Math.round((workoutDays / 7) * 100) / 100;

      const dietDays = last7.filter((r) => r.caloriesConsumed >= targetCal * 0.7).length;
      const dietScore = Math.round((dietDays / 7) * 100) / 100;

      const hydrationDays = last7.filter(
        (r) => parseFloat(r.waterConsumed.toString()) >= targetWater * 0.8
      ).length;
      const hydrationScore = Math.round((hydrationDays / 7) * 100) / 100;

      const sleepEntries = recoveryRows.filter((r) => {
        return r.sleepHours != null && new Date(r.date) >= weekStart;
      });
      const avgSleepHours = sleepEntries.length > 0
        ? sleepEntries.reduce((s, r) => s + (r.sleepHours ?? 0), 0) / sleepEntries.length
        : 0;
      const sleepScore = Math.round(Math.min(avgSleepHours / 8, 1) * 100) / 100;

      // ── Habit timeline (last 30 days, daily points) ────────────────────────
      const recoveryMap = new Map(recoveryRows.map((r) => [
        new Date(r.date).toDateString(), r,
      ]));
      const timeline = dailyRows.map((r) => {
        const dateKey = new Date(r.date).toDateString();
        const rec = recoveryMap.get(dateKey);
        return {
          date: new Date(r.date).toISOString().split('T')[0],
          workout: r.activeMinutes >= 20 ? 1 : r.activeMinutes >= 10 ? 0.5 : 0,
          diet: Math.min(r.caloriesConsumed / (targetCal || 1), 1),
          hydration: Math.min(parseFloat(r.waterConsumed.toString()) / (targetWater || 1), 1),
          sleep: rec?.sleepHours != null ? Math.min(rec.sleepHours / 8, 1) : 0,
        };
      });

      res.status(200).json({
        data: {
          body: { currentWeightKg, targetWeightKg, heightCm, weightLogs },
          today: {
            caloriesConsumed: todayRow?.caloriesConsumed ?? 0,
            targetCalories: activePlan?.targetCalories ?? 2000,
            proteinConsumed: todayRow?.proteinConsumed ?? 0,
            targetProtein: activePlan?.targetProtein ?? 150,
            carbsConsumed: todayRow?.carbsConsumed ?? 0,
            targetCarbs: activePlan?.targetCarbs ?? 200,
            fatsConsumed: todayRow?.fatsConsumed ?? 0,
            targetFats: activePlan?.targetFats ?? 65,
          },
          activity: {
            workoutsThisWeek,
            activeMinutesThisWeek,
            caloriesBurnedThisWeek,
            caloriesBurnedLast7Days,
          },
          habits: { workoutScore, dietScore, hydrationScore, sleepScore, timeline },
        },
      });
    } catch (error: any) {
      serverError(res, error);
    }
  }

  // GET /api/sync/equipment
  static async getEquipment(req: AuthenticatedRequest, res: Response) {
    try {
      const userId = req.user!.userId;
      
      // Get all active memberships for the user, include gym and equipment
      const memberships = await prisma.gymMembership.findMany({
        where: { userId: userId, status: 'ACTIVE' },
        include: {
          gym: {
            include: {
              equipment: true
            }
          }
        }
      });

      const inventories = memberships.map(m => {
        return {
          gymId: m.gym.id,
          gymName: m.gym.name,
          lastUpdated: new Date().toISOString(),
          equipment: m.gym.equipment.map(e => {
            // Best effort map backend category/name to frontend Equipment Enum
            let type = 'machines';
            const nameLower = e.name.toLowerCase();
            const categoryStr = e.category as string;
            if (nameLower.includes('dumbbell') || nameLower.includes('dumbell')) type = 'dumbbells';
            else if (nameLower.includes('barbell')) type = 'barbell';
            else if (nameLower.includes('bench')) type = 'bench';
            else if (nameLower.includes('cable')) type = 'cables';
            else if (nameLower.includes('pull-up') || nameLower.includes('pull up')) type = 'pullUpBar';
            else if (nameLower.includes('kettlebell')) type = 'kettlebell';
            else if (nameLower.includes('resistance band')) type = 'resistanceBands';
            else if (nameLower.includes('medicine ball') || nameLower.includes('wall ball')) type = 'medicineBall';
            else if (nameLower.includes('stability ball')) type = 'stabilityBall';
            else if (nameLower.includes('battle rope')) type = 'battleRopes';
            else if (nameLower.includes('trx')) type = 'trxStraps';
            else if (nameLower.includes('foam roller') || categoryStr === 'RECOVERY') type = 'foamRoller';
            else if (nameLower.includes('ab wheel')) type = 'abWheel';
            else if (nameLower.includes('yoga') || nameLower.includes('mat') || categoryStr === 'STRETCHING') type = 'yogaMat';
            else if (categoryStr === 'CARDIO') type = 'machines'; // Fallback for cardio machines
            else if (categoryStr === 'MACHINES') type = 'machines';
            else if (categoryStr === 'FUNCTIONAL') type = 'resistanceBands';

            return {
              type: type,
              displayName: e.name,
              quantity: e.quantity,
              isAvailable: e.status === 'AVAILABLE',
              notes: e.notes || null,
              location: e.location || null,
            };
          })
        };
      });

      res.status(200).json({ data: inventories });
    } catch (error: any) {
      serverError(res, error);
    }
  }
}


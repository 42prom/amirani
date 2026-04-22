import { Router, Response } from 'express';
import { z } from 'zod';
import {
  TrainerService,
  TrainerNotFoundError,
  TrainerAccessDeniedError,
} from './trainer.service';
import { FoodService } from '../food/food.service';
import prisma from '../../utils/prisma';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { NotificationService } from '../notifications/notification.service';
import { NotificationType } from '@prisma/client';
import {
  success,
  created,
  noContent,
  notFound,
  forbidden,
  badRequest,
  internalError,
} from '../../utils/response';
import { Role } from '@prisma/client';
import logger from '../../utils/logger';

const router = Router();
router.use(authenticate);

// ─── Middleware ───────────────────────────────────────────────────────────────

const trainerOnly = (req: AuthenticatedRequest, res: Response, next: Function) => {
  if (req.user!.role !== Role.TRAINER) {
    return forbidden(res, 'Trainer access required');
  }
  next();
};

// ─── Error handler helper ─────────────────────────────────────────────────────

function handleServiceError(err: unknown, res: Response) {
  if (err instanceof TrainerNotFoundError) return notFound(res, err.resource);
  if (err instanceof TrainerAccessDeniedError) return forbidden(res, err.message);
  logger.error({ err }, '[Trainer] Error');
  internalError(res);
}

// ─── Profile & Dashboard ──────────────────────────────────────────────────────

router.get('/me', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const profile = await TrainerService.getMyProfile(req.user!.userId);
    success(res, profile);
  } catch (err) {
    handleServiceError(err, res);
  }
});

router.get('/me/dashboard', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await TrainerService.getDashboardStats(req.user!.userId);
    success(res, stats);
  } catch (err) {
    handleServiceError(err, res);
  }
});

router.patch('/me/availability', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { isAvailable } = req.body;
    const profile = await TrainerService.updateAvailability(req.user!.userId, isAvailable);
    success(res, profile);
  } catch (err) {
    handleServiceError(err, res);
  }
});

// ─── Members ──────────────────────────────────────────────────────────────────

router.get('/me/members', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const members = await TrainerService.getAssignedMembers(req.user!.userId);
    success(res, members);
  } catch (err) {
    handleServiceError(err, res);
  }
});

router.get('/me/members/attendance', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { startDate, endDate } = req.query;
    const attendance = await TrainerService.getMembersAttendance(req.user!.userId, {
      startDate: startDate ? new Date(startDate as string) : undefined,
      endDate: endDate ? new Date(endDate as string) : undefined,
    });
    success(res, attendance);
  } catch (err) {
    handleServiceError(err, res);
  }
});

router.get('/me/members/:memberId/stats', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await TrainerService.getMemberStats(req.user!.userId, req.params.memberId);
    success(res, stats);
  } catch (err) {
    handleServiceError(err, res);
  }
});

/**
 * PATCH /trainers/me/members/:memberId/preferences
 * Trainer updates a member's unit and/or language preference
 */
const PreferencesSchema = z.object({
  unitPreference: z.enum(['METRIC', 'IMPERIAL']).optional(),
  languagePreference: z.enum(['EN', 'KA', 'RU']).optional(),
}).refine(d => d.unitPreference !== undefined || d.languagePreference !== undefined, {
  message: 'At least one of unitPreference or languagePreference is required',
});

router.patch('/me/members/:memberId/preferences', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const parsed = PreferencesSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: parsed.error.issues[0].message });
    const { unitPreference, languagePreference } = parsed.data;

    // Verify trainer owns this member
    const profile = await prisma.trainerProfile.findUnique({ where: { userId: req.user!.userId } });
    if (!profile) return res.status(403).json({ error: 'Not a trainer' });
    const assignment = await prisma.gymMembership.findFirst({
      where: { trainerId: profile.id, userId: req.params.memberId },
    });
    if (!assignment) return res.status(403).json({ error: 'Member not assigned to you' });

    const data: Record<string, unknown> = {};
    if (unitPreference) data.unitPreference = unitPreference;
    if (languagePreference) data.languagePreference = languagePreference;

    const updated = await prisma.user.update({
      where: { id: req.params.memberId },
      data,
      select: { id: true, unitPreference: true, languagePreference: true },
    });
    success(res, updated);
  } catch (err) {
    handleServiceError(err, res);
  }
});

// ─── Exercise Library Search ──────────────────────────────────────────────────

router.get('/exercise-library', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const query = (req.query.q as string) || '';
    const limit = parseInt(req.query.limit as string) || 20;
    const langParam = (req.query.lang as string || '').toUpperCase();
    const lang = (['KA', 'RU'].includes(langParam) ? langParam : 'EN') as 'EN' | 'KA' | 'RU';
    const exercises = await TrainerService.searchExerciseLibrary(query, limit, lang);
    success(res, exercises);
  } catch (err) {
    handleServiceError(err, res);
  }
});

// ─── Workout Plans ────────────────────────────────────────────────────────────

const WorkoutPlanSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  difficulty: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).optional(),
  startDate: z.string().optional().transform((v) => (v ? new Date(v) : undefined)),
  endDate: z.string().optional().transform((v) => (v ? new Date(v) : undefined)),
  numWeeks: z.number().int().min(1).max(12).optional(),
});

/**
 * GET /trainers/me/members/:memberId/workout-plans
 * List all trainer-created workout plans for a member
 */
router.get(
  '/me/members/:memberId/workout-plans',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plans = await TrainerService.getMemberWorkoutPlans(
        req.user!.userId,
        req.params.memberId
      );
      success(res, plans);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/members/:memberId/workout-plans
 * Create a new workout plan for a member
 */
router.post(
  '/me/members/:memberId/workout-plans',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const parsed = WorkoutPlanSchema.safeParse(req.body);
      if (!parsed.success) {
        return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
          field: e.path.map(String).join('.'),
          message: e.message,
        })));
      }
      const plan = await TrainerService.createWorkoutPlan(
        req.user!.userId,
        req.params.memberId,
        parsed.data as any
      );
      created(res, plan);
      try { 
        await NotificationService.send({
          userId: req.params.memberId,
          type: NotificationType.WORKOUT_REMINDER,
          title: 'New Workout Plan',
          body: `Your trainer has assigned you a new workout plan: ${plan.name}`,
        });
      } catch (_) {}
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * PUT /trainers/me/workout-plans/:planId
 * Update workout plan metadata
 */
router.put(
  '/me/workout-plans/:planId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.updateWorkoutPlan(
        req.user!.userId,
        req.params.planId,
        req.body
      );
      success(res, plan);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/workout-plans/:planId/activate
 * Activate a workout plan (deactivates others)
 */
router.post(
  '/me/workout-plans/:planId/activate',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.updateWorkoutPlan(
        req.user!.userId,
        req.params.planId,
        { isActive: true }
      );
      success(res, plan);
      try { 
        await NotificationService.send({
          userId: plan.userId,
          type: NotificationType.WORKOUT_REMINDER,
          title: 'Workout Plan Activated',
          body: `Your workout plan "${plan.name}" has been activated.`,
        });
      } catch (_) {}
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/workout-plans/:planId/deactivate
 * Deactivate a workout plan
 */
router.post(
  '/me/workout-plans/:planId/deactivate',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.updateWorkoutPlan(
        req.user!.userId,
        req.params.planId,
        { isActive: false }
      );
      success(res, plan);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * DELETE /trainers/me/workout-plans/:planId
 * Delete a workout plan
 */
router.delete(
  '/me/workout-plans/:planId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      await TrainerService.deleteWorkoutPlan(req.user!.userId, req.params.planId);
      noContent(res);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

// ─── Routines ─────────────────────────────────────────────────────────────────

const RoutineSchema = z.object({
  name: z.string().min(1).max(100),
  scheduledDate: z.string().optional().transform((v) => (v ? new Date(v) : undefined)),
  estimatedMinutes: z.number().int().min(5).max(300).optional(),
  orderIndex: z.number().int().optional(),
  isDraft: z.boolean().optional(),
});

/**
 * POST /trainers/me/workout-plans/:planId/routines
 * Add a workout day to a plan
 */
router.post(
  '/me/workout-plans/:planId/routines',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const parsed = RoutineSchema.safeParse(req.body);
      if (!parsed.success) {
        return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
          field: e.path.map(String).join('.'),
          message: e.message,
        })));
      }
      const routine = await TrainerService.addRoutine(
        req.user!.userId,
        req.params.planId,
        parsed.data as any
      );
      created(res, routine);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * PUT /trainers/me/routines/:routineId
 * Update a routine
 */
router.put(
  '/me/routines/:routineId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const routine = await TrainerService.updateRoutine(
        req.user!.userId,
        req.params.routineId,
        req.body
      );
      success(res, routine);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * DELETE /trainers/me/routines/:routineId
 * Delete a routine
 */
router.delete(
  '/me/routines/:routineId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      await TrainerService.deleteRoutine(req.user!.userId, req.params.routineId);
      noContent(res);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

// ─── Exercises ────────────────────────────────────────────────────────────────

const ExercisesSchema = z.object({
  exercises: z.array(
    z.object({
      exerciseName:      z.string().min(1),
      exerciseLibraryId: z.string().optional(),
      targetSets:        z.number().int().min(1).max(20).optional(),
      targetReps:        z.number().int().min(1).max(100).optional(),
      targetWeight:      z.number().min(0).optional(),
      restSeconds:       z.number().int().min(0).max(600).optional(),
      rpe:               z.number().int().min(1).max(10).optional(),
      progressionNote:   z.string().max(300).optional(),
      orderIndex:        z.number().int().min(0).optional(),
      exerciseType:      z.string().optional(),
    })
  ).min(1),
});

/**
 * POST /trainers/me/routines/:routineId/exercises
 * Add exercises to a routine
 */
router.post(
  '/me/routines/:routineId/exercises',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const parsed = ExercisesSchema.safeParse(req.body);
      if (!parsed.success) {
        return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
          field: e.path.map(String).join('.'),
          message: e.message,
        })));
      }
      const exercises = await TrainerService.addExercises(
        req.user!.userId,
        req.params.routineId,
        parsed.data.exercises
      );
      created(res, exercises);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * PUT /trainers/me/exercises/:exerciseId
 * Update a single exercise
 */
const UpdateExerciseSchema = z.object({
  exerciseName:      z.string().min(1).optional(),
  exerciseLibraryId: z.string().optional(),
  targetSets:        z.number().int().min(1).max(20).optional(),
  targetReps:        z.number().int().min(1).max(100).optional(),
  targetWeight:      z.number().min(0).optional(),
  restSeconds:       z.number().int().min(0).max(600).optional(),
  rpe:               z.number().int().min(1).max(10).optional(),
  progressionNote:   z.string().max(300).optional(),
  orderIndex:        z.number().int().min(0).optional(),
});

router.put(
  '/me/exercises/:exerciseId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const parsed = UpdateExerciseSchema.safeParse(req.body);
      if (!parsed.success) {
        return badRequest(res, 'Validation failed', parsed.error.issues.map(e => ({
          field: e.path.map(String).join('.'), message: e.message,
        })));
      }
      const exercise = await TrainerService.updateExercise(
        req.user!.userId,
        req.params.exerciseId,
        parsed.data
      );
      success(res, exercise);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * DELETE /trainers/me/exercises/:exerciseId
 * Delete a single exercise
 */
router.delete(
  '/me/exercises/:exerciseId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      await TrainerService.deleteExercise(req.user!.userId, req.params.exerciseId);
      noContent(res);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

// ─── Food Search (for diet plan builder) ─────────────────────────────────────

/**
 * GET /trainers/food-search?q=chicken&limit=15
 * Search food database — used by trainer diet builder
 */
router.get('/food-search', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const q = (req.query.q as string || '').trim();
    if (q.length < 2) return badRequest(res, 'Query must be at least 2 characters');
    const limit = Math.min(parseInt(req.query.limit as string) || 15, 30);
    const langParam = (req.query.lang as string || '').toUpperCase();
    const lang = (['KA', 'RU'].includes(langParam) ? langParam : 'EN') as 'EN' | 'KA' | 'RU';
    const results = await FoodService.search(q, limit, lang);
    return success(res, results);
  } catch (err) {
    internalError(res);
  }
});

// ─── Custom Food CRUD (trainer-owned food items) ─────────────────────────────

const CustomFoodSchema = z.object({
  name:    z.string().min(1).max(100),
  brand:   z.string().max(100).optional(),
  calories: z.number().min(0).max(9999),   // per 100g
  protein:  z.number().min(0).max(9999),
  carbs:    z.number().min(0).max(9999),
  fats:      z.number().min(0).max(9999),
  fiber:    z.number().min(0).max(9999).optional(),
  servingGrams: z.number().min(1).max(9999).optional(),
});

/**
 * POST /trainers/food-custom
 * Create a custom food item owned by the trainer (source = TRAINER)
 */
router.post('/food-custom', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const parsed = CustomFoodSchema.safeParse(req.body);
    if (!parsed.success) return badRequest(res, parsed.error.issues[0]?.message ?? 'Invalid data');
    const d = parsed.data;
    const food = await prisma.foodItem.create({
      data: {
        name:      d.name.trim(),
        brand:     d.brand?.trim() ?? null,
        calories:  d.calories,
        protein:   d.protein,
        carbs:     d.carbs,
        fats:       d.fats,
        fiber:     d.fiber ?? null,
        source:    'TRAINER',
        isVerified: false,
        createdBy:  req.user!.userId,
      },
      select: { id: true, name: true, brand: true, calories: true, protein: true, carbs: true, fats: true, fiber: true, source: true, createdAt: true },
    });
    return created(res, food);
  } catch (err) {
    internalError(res);
  }
});

/**
 * GET /trainers/food-mine
 * List all custom food items created by this trainer
 */
router.get('/food-mine', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const foods = await prisma.foodItem.findMany({
      where: { createdBy: req.user!.userId, source: 'TRAINER' },
      orderBy: { createdAt: 'desc' },
      select: { id: true, name: true, brand: true, calories: true, protein: true, carbs: true, fats: true, fiber: true, source: true, createdAt: true },
    });
    return success(res, foods);
  } catch (err) {
    internalError(res);
  }
});

/**
 * DELETE /trainers/food-custom/:foodId
 * Delete a trainer's own custom food item
 */
router.delete('/food-custom/:foodId', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const food = await prisma.foodItem.findFirst({
      where: { id: req.params.foodId, createdBy: req.user!.userId, source: 'TRAINER' },
    });
    if (!food) return res.status(404).json({ error: 'Food item not found' });
    await prisma.foodItem.delete({ where: { id: req.params.foodId } });
    noContent(res);
  } catch (err) {
    internalError(res);
  }
});

// ─── Diet Plans ───────────────────────────────────────────────────────────────

const DietPlanSchema = z.object({
  name: z.string().min(1).max(100),
  targetCalories: z.number().int().min(500).max(10000),
  targetProtein: z.number().int().min(0).max(1000),
  targetCarbs: z.number().int().min(0).max(2000),
  targetFats: z.number().int().min(0).max(1000),
  targetWater: z.number().min(0).max(20).optional(),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional()
    .transform((v) => (v ? new Date(v) : undefined)),
  numWeeks: z.number().int().min(1).max(52).optional().default(1),
  weekTargets: z.array(z.object({
    calories: z.number(),
    protein: z.number(),
    carbs: z.number(),
    fats: z.number(),
  })).optional(),
});

/**
 * GET /trainers/me/members/:memberId/diet-plans
 * List all trainer-created diet plans for a member
 */
router.get(
  '/me/members/:memberId/diet-plans',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plans = await TrainerService.getMemberDietPlans(
        req.user!.userId,
        req.params.memberId
      );
      success(res, plans);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/members/:memberId/diet-plans
 * Create a new diet plan for a member
 */
router.post(
  '/me/members/:memberId/diet-plans',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const parsed = DietPlanSchema.safeParse(req.body);
      if (!parsed.success) {
        return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
          field: e.path.map(String).join('.'),
          message: e.message,
        })));
      }
      const plan = await TrainerService.createDietPlan(
        req.user!.userId,
        req.params.memberId,
        parsed.data
      );
      created(res, plan);
      try { 
        await NotificationService.send({
          userId: req.params.memberId,
          type: NotificationType.MEAL_REMINDER,
          title: 'New Diet Plan',
          body: `Your trainer has assigned you a new diet plan: ${plan.name}`,
        });
      } catch (_) {}
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * PUT /trainers/me/diet-plans/:planId
 * Update diet plan metadata
 */
router.put(
  '/me/diet-plans/:planId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.updateDietPlan(
        req.user!.userId,
        req.params.planId,
        req.body
      );
      success(res, plan);
      try { 
        await NotificationService.send({
          userId: plan.userId,
          type: NotificationType.MEAL_REMINDER,
          title: 'Diet Plan Activated',
          body: `Your diet plan "${plan.name}" has been activated.`,
        });
      } catch (_) {}
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * DELETE /trainers/me/diet-plans/:planId
 * Delete a diet plan
 */
router.delete(
  '/me/diet-plans/:planId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      await TrainerService.deleteDietPlan(req.user!.userId, req.params.planId);
      noContent(res);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/diet-plans/:planId/activate
 * Activate a diet plan — deactivates all other trainer plans for that member
 */
router.post(
  '/me/diet-plans/:planId/activate',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.activateDietPlan(
        req.user!.userId,
        req.params.planId
      );
      success(res, plan);
      try { 
        await NotificationService.send({
          userId: plan.userId,
          type: NotificationType.MEAL_REMINDER,
          title: 'Diet Plan Activated',
          body: `Your diet plan "${plan.name}" has been activated.`,
        });
      } catch (_) {}
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/diet-plans/:planId/deactivate
 * Deactivate a diet plan
 */
router.post(
  '/me/diet-plans/:planId/deactivate',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.deactivateDietPlan(
        req.user!.userId,
        req.params.planId
      );
      success(res, plan);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

// ─── Meals ────────────────────────────────────────────────────────────────────

const MealIngredientSchema = z.object({
  name: z.string(),
  amount: z.number(),
  unit: z.string(),
  calories: z.number(),
  protein: z.number(),
  carbs: z.number(),
  fats: z.number(),
});

const MealSchema = z.object({
  name: z.string().min(1).max(100),
  timeOfDay: z.string().optional(),
  scheduledDate: z.string().optional().transform((v) => (v ? new Date(v) : undefined)),
  totalCalories: z.number().optional(),
  protein: z.number().optional(),
  carbs: z.number().optional(),
  fats: z.number().optional(),
  ingredients: z.any().optional(),
  notificationTime: z.string().optional(),
  isReminderEnabled: z.boolean().optional(),
  instructions: z.string().optional(),
  isDraft: z.boolean().optional(),
  mediaUrl: z.string().url().optional(),
});

const MealUpdateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  timeOfDay: z.string().optional(),
  scheduledDate: z.string().optional().transform((v) => (v ? new Date(v) : undefined)),
  totalCalories: z.number().optional(),
  protein: z.number().optional(),
  carbs: z.number().optional(),
  fats: z.number().optional(),
  ingredients: z.any().optional(),
  notificationTime: z.string().optional(),
  isReminderEnabled: z.boolean().optional(),
  instructions: z.string().optional(),
  isDraft: z.boolean().optional(),
  mediaUrl: z.string().url().optional(),
});

/**
 * POST /trainers/me/diet-plans/:planId/meals
 * Add a meal to a diet plan
 */
router.post(
  '/me/diet-plans/:planId/meals',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const parsed = MealSchema.safeParse(req.body);
      if (!parsed.success) {
        return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
          field: e.path.map(String).join('.'),
          message: e.message,
        })));
      }
      const meal = await TrainerService.addMeal(
        req.user!.userId,
        req.params.planId,
        parsed.data as any
      );
      created(res, meal);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * PUT /trainers/me/meals/:mealId
 * Update a meal
 */
router.put(
  '/me/meals/:mealId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const meal = await TrainerService.updateMeal(
        req.user!.userId,
        req.params.mealId,
        req.body
      );
      success(res, meal);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * POST /trainers/me/diet-plans/:planId/publish
 * Publish a draft macro plan to a user
 */
router.post(
  '/me/diet-plans/:planId/publish',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const plan = await TrainerService.publishDietPlan(req.user!.userId, req.params.planId);
      success(res, plan, 'Plan published successfully');
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

/**
 * DELETE /trainers/me/meals/:mealId
 * Delete a meal
 */
router.delete(
  '/me/meals/:mealId',
  trainerOnly,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      await TrainerService.deleteMeal(req.user!.userId, req.params.mealId);
      noContent(res);
    } catch (err) {
      handleServiceError(err, res);
    }
  }
);

// ─── Draft Template Library ───────────────────────────────────────────────────

const DraftTemplateSchema = z.object({
  type: z.enum(['meal', 'day', 'week']),
  name: z.string().min(1).max(80),
  data: z.any(),
});

/**
 * GET /trainers/me/draft-templates
 * List all draft templates for the trainer
 */
router.get('/me/draft-templates', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const templates = await TrainerService.getDraftTemplates(req.user!.userId);
    success(res, templates);
  } catch (err) {
    handleServiceError(err, res);
  }
});

/**
 * POST /trainers/me/draft-templates
 * Save a new draft template (meal/day/week)
 */
router.post('/me/draft-templates', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const parsed = DraftTemplateSchema.safeParse(req.body);
    if (!parsed.success) return badRequest(res, (parsed.error as any).issues?.[0]?.message ?? 'Invalid input');
    const { type, name, data } = parsed.data;
    const tpl = await TrainerService.createDraftTemplate(req.user!.userId, type, name, data);
    created(res, tpl);
  } catch (err) {
    if (err instanceof TrainerAccessDeniedError) return badRequest(res, err.message);
    handleServiceError(err, res);
  }
});

/**
 * PATCH /trainers/me/draft-templates/:id
 * Edit template name or data
 */
router.patch('/me/draft-templates/:id', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { name, data } = req.body;
    const tpl = await TrainerService.updateDraftTemplate(req.user!.userId, req.params.id, { name, data });
    success(res, tpl);
  } catch (err) {
    handleServiceError(err, res);
  }
});

/**
 * DELETE /trainers/me/draft-templates/:id
 * Delete a draft template
 */
router.delete('/me/draft-templates/:id', trainerOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    await TrainerService.deleteDraftTemplate(req.user!.userId, req.params.id);
    noContent(res);
  } catch (err) {
    handleServiceError(err, res);
  }
});

// ─── Training Sessions (member-facing, any authenticated user) ───────────────

/**
 * GET /trainers/sessions?gymId=xxx
 * List upcoming sessions for a gym
 */
router.get('/sessions', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.query.gymId as string;
    if (!gymId) return badRequest(res, 'gymId is required');
    const sessions = await TrainerService.listUpcomingSessions(gymId);
    success(res, sessions);
  } catch (err) {
    handleServiceError(err, res);
  }
});

/**
 * GET /trainers/sessions/my-bookings
 * Get the authenticated user's upcoming confirmed bookings
 */
router.get('/sessions/my-bookings', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const bookings = await TrainerService.getMySessionBookings(req.user!.userId);
    success(res, bookings);
  } catch (err) {
    handleServiceError(err, res);
  }
});

/**
 * POST /trainers/sessions/:sessionId/book
 * Book a session
 */
router.post('/sessions/:sessionId/book', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const booking = await TrainerService.bookSession(req.user!.userId, req.params.sessionId);
    created(res, booking);
  } catch (err) {
    handleServiceError(err, res);
  }
});

/**
 * DELETE /trainers/sessions/:sessionId/book
 * Cancel a booking
 */
router.delete('/sessions/:sessionId/book', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const booking = await TrainerService.cancelBooking(req.user!.userId, req.params.sessionId);
    success(res, booking);
  } catch (err) {
    handleServiceError(err, res);
  }
});

export default router;


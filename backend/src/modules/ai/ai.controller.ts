import { Router, Response } from 'express';
import { z } from 'zod';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { enqueueAiPlanGeneration, enqueueAiJobStatus } from '../../jobs/queue';
import { success, badRequest, internalError, rateLimited } from '../../utils/response';
import prisma from '../../utils/prisma';
import logger from '../../utils/logger';

const router = Router();
router.use(authenticate);

// ─── Rate Limit (5 AI requests per user per hour) ─────────────────────────────
// Uses Redis via BullMQ connection — fires a simple sorted-set based counter.
// Falls open on Redis failure to avoid blocking users.

async function checkAiRateLimit(userId: string): Promise<boolean> {
  try {
    const { redisConnection } = await import('../../lib/queue');
    const Redis = (await import('ioredis')).default;
    const redis = new Redis(redisConnection as any);

    const key = `ai:ratelimit:${userId}`;
    const now = Date.now();
    const windowMs = 60 * 60 * 1000; // 1 hour
    const limit = 5;

    const pipe = redis.pipeline();
    pipe.zremrangebyscore(key, '-inf', now - windowMs); // Remove expired entries
    pipe.zadd(key, now, `${now}`);                       // Add current request
    pipe.zcard(key);                                      // Count requests in window
    pipe.expire(key, 3600);                               // Reset TTL
    const results = await pipe.exec();

    await redis.quit();

    if (!results) return true; // Fail open
    const count = results[2]?.[1] as number ?? 0;
    return count <= limit;
  } catch {
    return true; // Redis unavailable — fail open
  }
}

// ─── Validation ───────────────────────────────────────────────────────────────

const GenerateWorkoutSchema = z.object({
  goals: z.string().min(3).max(500),
  fitnessLevel: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']),
  daysPerWeek: z.number().int().min(1).max(7).default(4),
  preferredDays: z.array(z.number().int().min(0).max(6)).optional(),
  targetMuscles: z.array(z.string()).optional(),
  restrictions: z.array(z.string()).optional(),
  userMetrics: z.object({
    weightKg: z.number().optional(),
    heightCm: z.number().optional(),
    age: z.number().int().optional(),
    gender: z.string().optional(),
    injuries: z.array(z.string()).optional(),
  }).optional(),
});

const GenerateDietSchema = z.object({
  goals: z.string().min(3).max(500),
  fitnessLevel: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']),
  restrictions: z.array(z.string()).optional(),
  userMetrics: z.object({
    weightKg: z.number().optional(),
    heightCm: z.number().optional(),
    age: z.number().int().optional(),
    gender: z.string().optional(),
  }).optional(),
  dietaryStyle: z.string().optional(),
  allergies: z.array(z.string()).optional(),
  likes: z.array(z.string()).optional(),
  budgetPerDayUsd: z.number().optional(),
  mealsPerDay: z.number().int().min(1).max(6).default(4),
});

// ─── POST /api/ai/generate-workout ───────────────────────────────────────────

/**
 * POST /api/ai/generate-workout
 * Enqueues an AI workout plan generation job for the authenticated user.
 * The job runs in the BullMQ 'ai-workout-generation' worker and saves the
 * resulting WorkoutPlan + WorkoutRoutines + ExerciseSets directly to the DB.
 *
 * Mobile polls GET /api/ai/job-status/:jobId?type=WORKOUT for completion.
 */
router.post('/generate-workout', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;

    const allowed = await checkAiRateLimit(userId);
    if (!allowed) {
      return rateLimited(res);
    }

    const parsed = GenerateWorkoutSchema.safeParse(req.body);
    if (!parsed.success) {
      return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
        field: e.path.map(String).join('.'),
        message: e.message,
      })));
    }

    // Enrich userMetrics and Equipment from DB profile
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { 
        weight: true, 
        height: true, 
        dob: true, 
        gender: true, 
        medicalConditions: true,
        targetWeightKg: true,
        activeGymId: true 
      },
    });

    let availableEquipment: string[] | undefined = undefined;
    if (user?.activeGymId) {
      const equipment = await prisma.equipment.findMany({
        where: { 
          gymId: user.activeGymId,
          status: 'AVAILABLE' 
        },
        select: { name: true }
      });
      if (equipment.length > 0) {
        availableEquipment = equipment.map((e: any) => e.name);
      }
    }

    const mergedMetrics = {
      weightKg: parsed.data.userMetrics?.weightKg ?? (user?.weight ? parseFloat(user.weight.toString()) : undefined),
      heightCm: parsed.data.userMetrics?.heightCm ?? (user?.height ? parseFloat(user.height.toString()) : undefined),
      age: parsed.data.userMetrics?.age ?? (user?.dob ? Math.floor((Date.now() - new Date(user.dob).getTime()) / (1000 * 60 * 60 * 24 * 365)) : undefined),
      gender: parsed.data.userMetrics?.gender ?? user?.gender ?? undefined,
      injuries: parsed.data.userMetrics?.injuries,
      medicalConditions: user?.medicalConditions ?? undefined,
      targetWeightKg: user?.targetWeightKg ? parseFloat(user.targetWeightKg.toString()) : undefined,
    };

    // [TRANSITION]: Deactivation moved to queue.ts for bulletproof stability
    /*
    await prisma.workoutPlan.updateMany({
      where: { userId, isActive: true },
      data: { isActive: false },
    });
    */

    const { jobId } = await enqueueAiPlanGeneration('WORKOUT', {
      userId,
      type: 'WORKOUT',
      goals: parsed.data.goals,
      fitnessLevel: parsed.data.fitnessLevel,
      daysPerWeek: parsed.data.daysPerWeek,
      preferred_days: parsed.data.preferredDays,
      target_muscles: parsed.data.targetMuscles,
      restrictions: parsed.data.restrictions,
      availableEquipment, // Real-time equipment awareness
      userMetrics: mergedMetrics,
    });

    logger.info({ userId, jobId }, '[AI] Workout plan job enqueued');

    return success(res, {
      jobId,
      status: 'QUEUED',
      message: 'Your workout plan is being generated. Poll /api/ai/job-status for updates.',
    }, undefined, 202);
  } catch (err) {
    logger.error({ err }, '[AI] generate-workout enqueue error');
    internalError(res);
  }
});

// ─── POST /api/ai/generate-diet ───────────────────────────────────────────────

/**
 * POST /api/ai/generate-diet
 * Enqueues an AI diet plan generation job for the authenticated user.
 * The worker saves DietPlan + Meals to DB on completion.
 */
router.post('/generate-diet', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;

    const allowed = await checkAiRateLimit(userId);
    if (!allowed) {
      return rateLimited(res);
    }

    const parsed = GenerateDietSchema.safeParse(req.body);
    if (!parsed.success) {
      return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
        field: e.path.map(String).join('.'),
        message: e.message,
      })));
    }

    // Enrich from DB profile
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { weight: true, height: true, dob: true, gender: true, medicalConditions: true, targetWeightKg: true },
    });

    const mergedMetrics = {
      weightKg: parsed.data.userMetrics?.weightKg ?? (user?.weight ? parseFloat(user.weight.toString()) : undefined),
      heightCm: parsed.data.userMetrics?.heightCm ?? (user?.height ? parseFloat(user.height.toString()) : undefined),
      age: parsed.data.userMetrics?.age ?? (user?.dob ? Math.floor((Date.now() - new Date(user.dob).getTime()) / (1000 * 60 * 60 * 24 * 365)) : undefined),
      gender: parsed.data.userMetrics?.gender ?? user?.gender ?? undefined,
      medicalConditions: user?.medicalConditions ?? undefined,
      targetWeightKg: user?.targetWeightKg ? parseFloat(user.targetWeightKg.toString()) : undefined,
    };

    // Build extended goals string with dietary preferences
    const dietContext = [
      parsed.data.goals,
      parsed.data.dietaryStyle ? `Dietary style: ${parsed.data.dietaryStyle}` : '',
      parsed.data.allergies?.length ? `Allergies: ${parsed.data.allergies.join(', ')}` : '',
      parsed.data.budgetPerDayUsd ? `Daily budget: $${parsed.data.budgetPerDayUsd} USD` : '',
      `Meals per day: ${parsed.data.mealsPerDay}`,
    ].filter(Boolean).join('. ');

    // [TRANSITION]: Deactivation moved to queue.ts for bulletproof stability
    /*
    await prisma.dietPlan.updateMany({
      where: { userId, isActive: true },
      data: { isActive: false },
    });
    */

    const { jobId: jobId } = await enqueueAiPlanGeneration('DIET', {
      userId,
      type: 'DIET',
      goals: parsed.data.goals,
      fitnessLevel: parsed.data.fitnessLevel,
      restrictions: parsed.data.restrictions,
      userMetrics: mergedMetrics,
      dietaryStyle: parsed.data.dietaryStyle,
      allergies: parsed.data.allergies,
      likes: parsed.data.likes,
      budgetPerDayUsd: parsed.data.budgetPerDayUsd,
      mealsPerDay: parsed.data.mealsPerDay,
    });

    logger.info({ userId, jobId }, '[AI] Diet plan job enqueued');

    return success(res, {
      jobId,
      status: 'QUEUED',
      message: 'Your diet plan is being generated. Poll /api/ai/job-status for updates.',
    }, undefined, 202);
  } catch (err) {
    logger.error({ err }, '[AI] generate-diet enqueue error');
    internalError(res);
  }
});

// ─── GET /api/ai/job-status/:jobId ───────────────────────────────────────────

/**
 * GET /api/ai/job-status/:jobId?type=WORKOUT|DIET
 * Mobile polls this endpoint to check on an in-progress AI job.
 * Returns status: QUEUED | PROCESSING | COMPLETED | FAILED
 */
router.get('/job-status/:jobId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { jobId } = req.params;
    const type = (req.query.type as string)?.toUpperCase();

    if (!type || !['WORKOUT', 'DIET'].includes(type)) {
      return badRequest(res, 'Query param ?type=WORKOUT|DIET is required');
    }

    const status = await enqueueAiJobStatus(jobId, type as 'WORKOUT' | 'DIET');

    return success(res, status);
  } catch (err) {
    logger.error({ err }, '[AI] job-status check error');
    internalError(res);
  }
});

export default router;


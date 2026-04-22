import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import prisma from '../../utils/prisma';
import { z } from 'zod';
import { enqueueAiPlanGeneration, enqueueAiJobStatus } from '../../jobs/queue';
import { PlatformConfigService } from '../platform/platform-config.service';
import { UserTier } from '@prisma/client';
import { serverError } from '../../utils/response';
import logger from '../../utils/logger';

// ─── Validation Schema ────────────────────────────────────────────────────────

const GeneratePlanSchema = z.object({
  type: z.enum(['WORKOUT', 'DIET', 'BOTH']).default('WORKOUT'),
  // Accept either 'goals' (string) or 'goal' (enum name from mobile)
  goals: z.string().min(1).max(500).optional(),
  goal: z.string().optional(),
  target_muscles: z.array(z.string()).optional(),
  fitnessLevel: z.enum(['BEGINNER', 'INTERMEDIATE', 'ADVANCED']).optional(),
  fitness_level: z.string().optional(), // snake_case alias from mobile
  restrictions: z.array(z.string().max(100)).max(20).optional(),
  available_equipment: z.array(z.string()).optional(),
  availableEquipment: z.array(z.string()).optional(),
  daysPerWeek: z.number().int().min(1).max(7).optional(),
  days_per_week: z.number().int().min(1).max(7).optional(),
  preferred_days: z.array(z.number().int().min(0).max(6)).max(7).optional(),
  userMetrics: z.object({
    weightKg: z.number().min(20).max(500).optional(),
    heightCm: z.number().min(100).max(250).optional(),
    age: z.number().int().min(10).max(100).optional(),
    gender: z.string().optional(),
    injuries: z.array(z.string()).optional(),
  }).optional(),
}).passthrough();

// ─── Controller ───────────────────────────────────────────────────────────────

export class AIController {

  /**
   * POST /api/ai/generate-plan
   * Enqueues an async AI plan generation job.
   */
  static async generatePlan(req: AuthenticatedRequest, res: Response) {
    try {
      // Extract data, potentially nested in 'preferences' if from mobile
      const rawData = req.body.preferences ? { ...req.body.preferences, type: req.body.type || 'WORKOUT' } : req.body;
      
      const parsed = GeneratePlanSchema.safeParse(rawData);
      if (!parsed.success) {
        return res.status(400).json({
          success: false,
          error: { code: 'VALIDATION_ERROR', message: 'Validation failed', details: parsed.error.flatten().fieldErrors },
        });
      }

      const userId = req.user!.userId;

      // Check AI is enabled on platform
      const aiConfig = await prisma.aIConfig.findFirst({ where: { isEnabled: true } });
      if (!aiConfig) {
        return res.status(503).json({ success: false, error: { code: 'AI_DISABLED', message: 'AI capabilities are currently disabled.' } });
      }

      // Enforce per-user daily AI request limit based on UserTierLimits
      const role: string = req.user!.role;
      let tier: UserTier = 'FREE';
      if (role === 'GYM_MEMBER') tier = 'GYM_MEMBER';
      else if (role === 'HOME_USER') {
        const u = await prisma.user.findUnique({ where: { id: userId }, select: { saasSubscriptionStatus: true } });
        if (u?.saasSubscriptionStatus === 'ACTIVE') tier = 'HOME_PREMIUM';
      }
      const { type, ...jobData } = parsed.data;

      const limitCheck = await PlatformConfigService.checkUserAILimits(userId, tier);
      // type=BOTH costs 2 request credits — verify enough quota remains.
      // dailyRequestsLimit === 0 means unlimited (no cap); skip the cost check in that case.
      const requestCost = type === 'BOTH' ? 2 : 1;
      const isUnlimited = limitCheck.dailyRequestsLimit === 0;
      const remainingRequests = limitCheck.dailyRequestsLimit - limitCheck.dailyRequestsUsed;
      const insufficientQuota = !isUnlimited && remainingRequests < requestCost;
      if (!limitCheck.canMakeRequest || insufficientQuota) {
        return res.status(429).json({ success: false, error: { code: 'RATE_LIMITED', message: `AI limit reached. Used ${limitCheck.dailyRequestsUsed}/${limitCheck.dailyRequestsLimit} requests today. This request requires ${requestCost} credit(s).` } });
      }

      // Diet/workout dependency guard.
      // A workout plan requires an active diet plan as its nutritional anchor.
      // type=BOTH is the first-time setup flow — both are being created together, so no prior diet is expected.
      if (type === 'WORKOUT') {
        const activeDiet = await prisma.dietPlan.findFirst({
          where: { userId, isActive: true, deletedAt: null, status: 'ACTIVE' },
          select: { id: true },
        });
        if (!activeDiet) {
          return res.status(409).json({
            success: false,
            error: {
              code: 'DIET_PLAN_REQUIRED',
              message: 'A diet plan is required before generating a workout plan. Please complete your nutrition setup first.',
            },
          });
        }
      }

      // Normalize fields — mobile may send snake_case or alternate names
      const equipment = parsed.data.availableEquipment || (parsed.data as any).available_equipment;
      const goals = parsed.data.goals || parsed.data.goal || 'general fitness';
      const daysPerWeek = parsed.data.daysPerWeek || (parsed.data as any).days_per_week || 3;
      const fitnessLevel = (parsed.data.fitnessLevel ||
        ((parsed.data as any).fitness_level || 'BEGINNER').toUpperCase()) as any;
      // Diet-specific normalizations
      const mealsPerDay = (parsed.data as any).mealsPerDay ?? (parsed.data as any).meals_per_day;
      const dietaryStyle = (parsed.data as any).dietaryStyle ?? (parsed.data as any).dietary_style;
      const allergies = (parsed.data as any).allergies ?? (parsed.data as any).restrictions;
      const likes = (parsed.data as any).likes;
      const dislikedFoods = (parsed.data as any).dislikedFoods ?? (parsed.data as any).disliked_foods;
      // Workout-specific normalizations
      const trainingSplit = (parsed.data as any).trainingSplit ?? (parsed.data as any).training_split;
      // Diet-specific extended fields
      const mealTimes = (parsed.data as any).meal_times ?? (parsed.data as any).mealTimes;
      const maxPrepMinutes = (parsed.data as any).max_prep_minutes ?? (parsed.data as any).maxPrepMinutes;
      const budget = (parsed.data as any).budget;
      const allergiesStructured = (parsed.data as any).allergies_structured ?? (parsed.data as any).allergiesStructured;
      const targetCalories = (parsed.data as any).target_calories ?? (parsed.data as any).targetCalories;
      const targetProteinG = (parsed.data as any).target_protein_g ?? (parsed.data as any).targetProteinG;
      const tdee = (parsed.data as any).tdee;

      // Enrich userMetrics from DB profile when mobile doesn't send them
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { weight: true, height: true, dob: true, gender: true, medicalConditions: true },
      });
      const dbMetrics = {
        weightKg: user?.weight ? parseFloat(user.weight.toString()) : undefined,
        heightCm: user?.height ? parseFloat(user.height.toString()) : undefined,
        age: user?.dob ? Math.floor((Date.now() - new Date(user.dob).getTime()) / (1000 * 60 * 60 * 24 * 365)) : undefined,
        gender: user?.gender ?? undefined,
      };
      const mergedMetrics = {
        ...dbMetrics,
        ...(parsed.data.userMetrics ?? {}),
      };

      // Enqueue
      const { jobId, dietJobId } = await enqueueAiPlanGeneration(type as any, {
        userId,
        type: type as any,
        ...jobData,
        goals,
        fitnessLevel,
        daysPerWeek,
        availableEquipment: equipment,
        userMetrics: mergedMetrics,
        ...(mealsPerDay !== undefined && { mealsPerDay }),
        ...(dietaryStyle !== undefined && { dietaryStyle }),
        ...(allergies !== undefined && { allergies }),
        ...(likes !== undefined && { likes }),
        ...(dislikedFoods !== undefined && { dislikedFoods }),
        ...(trainingSplit !== undefined && { trainingSplit }),
        ...(mealTimes !== undefined && { mealTimes }),
        ...(maxPrepMinutes !== undefined && { maxPrepMinutes }),
        ...(budget !== undefined && { budget }),
        ...(allergiesStructured !== undefined && { allergiesStructured }),
        ...(targetCalories !== undefined && { targetCalories }),
        ...(targetProteinG !== undefined && { targetProteinG }),
        ...(tdee !== undefined && { tdee }),
      });

      return res.status(202).json({ // 202 Accepted — async job enqueued
        success: true,
        data: {
          jobId,
          ...(dietJobId && { dietJobId }), // present only for type=BOTH; lets mobile poll each job independently
          status: 'QUEUED',
          message: "Your AI plan is being generated.",
        },
      });
    } catch (err: any) {
      logger.error({ err }, '[AI] generatePlan error');
      serverError(res, err);
    }
  }

  /**
   * GET /api/ai/status/:jobId
   */
  static async getJobStatus(req: AuthenticatedRequest, res: Response) {
    try {
      const { jobId } = req.params;
      const type = (req.query.type as string ?? 'WORKOUT').toUpperCase() as any;

      if (!jobId) {
        return res.status(400).json({ success: false, error: { message: 'jobId is required' } });
      }

      const status = await enqueueAiJobStatus(jobId, type);
      // CRITICAL: Disable browser/CDN caching on polling endpoints.
      // Without no-store, Chrome (Flutter Web) caches the first QUEUED response
      // and serves 304 Not Modified on every subsequent poll — Dart always sees
      // QUEUED and never detects PROCESSING or COMPLETED.
      res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
      res.setHeader('Pragma', 'no-cache');
      return res.status(200).json({ success: true, data: status });
    } catch (err: any) {
      logger.error({ err }, '[AI] getJobStatus error');
      serverError(res, err);
    }
  }
}


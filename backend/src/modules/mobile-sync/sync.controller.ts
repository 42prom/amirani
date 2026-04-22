import { Request, Response } from 'express';
import prisma from '../../utils/prisma';
import { z } from 'zod';
import { getFullUrl } from '../../utils/url';
import { recalculateUserStats } from '../../utils/leaderboard.service';
import { v4 as uuidv4 } from 'uuid';
import { inferMealType } from './mobile.controller';
import { serverError } from '../../utils/response';
import logger from '../../utils/logger';


const SyncUpSchema = z.object({
  lastSyncTimestamp: z.string(), // Soften from .datetime() for flagship resiliency
  changes: z.object({
    dailyProgress: z.array(z.object({
      id: z.string().uuid().optional(), // Allow optional for auto-generation
      date: z.string(), // Soften from .datetime()
      score: z.number().int().optional(),
      // caloriesConsumed/protein/carbs/fats intentionally omitted — server-owned via food logs
      waterConsumed: z.number().optional(),
      stepsTaken: z.number().int().optional(),
      activeMinutes: z.number().int().optional(),
      tasksTotal: z.number().int().optional(),
      tasksCompleted: z.number().int().optional(),
    })).optional(),
    completedSets: z.array(z.object({
      id: z.string().uuid().optional(), // Optional for auto-gen
      historyId: z.string().uuid(),
      exerciseName: z.string(),
      actualSets: z.number().int(),
      actualReps: z.number().int().optional(),
      actualDuration: z.number().int().optional(),
      actualWeight: z.number().optional(),
      rpe: z.number().optional(),
      notes: z.string().optional(),
    })).optional(),
    profile: z.object({
        firstName: z.string().optional(),
        lastName: z.string().optional(),
        fullName: z.string().optional(),
        gender: z.string().optional(),
        dob: z.string().optional(),
        weight: z.string().optional(),
        height: z.string().optional(),
        targetWeightKg: z.number().optional(),
        medicalConditions: z.string().optional(),
        noMedicalConditions: z.boolean().optional(),
        personalNumber: z.string().optional(),
        phoneNumber: z.string().optional(),
        address: z.string().optional(),
        avatarUrl: z.string().optional(),
        idPhotoUrl: z.string().optional(),
        totalPoints: z.number().int().optional(),
        streakDays: z.number().int().optional(),
        timezone: z.string().optional(),
    }).optional(),
    deletedIds: z.array(z.string().uuid()).optional(),
  })
});

export class SyncController {
  
  // POST /api/sync/up
  static async syncUp(req: Request, res: Response) {
    try {
      const userId = (req as any).user.userId;
      const parsedBody = SyncUpSchema.parse(req.body);

      // Perform updates atomically
      await prisma.$transaction(async (tx) => {
        // Handle DailyProgress updates
        if (parsedBody.changes.dailyProgress && parsedBody.changes.dailyProgress.length > 0) {
          logger.debug(`[Sync] Processing ${parsedBody.changes.dailyProgress.length} daily progress updates`, { userId });
          for (const dp of parsedBody.changes.dailyProgress) {
            const dpId = dp.id || uuidv4();
            // Zod schema intentionally omits caloriesConsumed/protein/carbs/fats — those are
            // server-owned via food.service.ts atomic increments. Spreading dp here is safe.
            await tx.dailyProgress.upsert({
              where: { userId_date: { userId, date: new Date(dp.date) } },
              update: {
                ...dp,
                id: dpId,
                date: new Date(dp.date)
              },
              create: {
                ...dp,
                id: dpId,
                userId: userId,
                date: new Date(dp.date)
              }
            });
          }
        }

        // Handle Completed Sets
        if (parsedBody.changes.completedSets && parsedBody.changes.completedSets.length > 0) {
            logger.debug(`[Sync] Processing ${parsedBody.changes.completedSets.length} set updates`, { userId });
            for (const cs of parsedBody.changes.completedSets) {
                const csId = cs.id || uuidv4();
                await tx.completedSet.upsert({
                    where: { id: csId },
                    update: { ...cs, id: csId },
                    create: { ...cs, id: csId }
                });
            }
        }

        // Handle Profile updates
        if (parsedBody.changes.profile) {
            const p = parsedBody.changes.profile;
            logger.debug({ userId }, '[Sync] Updating profile');
            
            // Auto-calculate fullName if segments are provided but fullName isn't explicitly sent
            let fullName = p.fullName;
            if (!fullName && (p.firstName || p.lastName)) {
                fullName = `${p.firstName || ''} ${p.lastName || ''}`.trim();
            }

            // Normalize gender from mobile format ("Male") to Prisma enum ("MALE")
            const normalizeGender = (g: string | undefined | null): string | undefined => {
              if (!g) return undefined;
              const map: Record<string, string> = {
                male: 'MALE', female: 'FEMALE', other: 'OTHER',
                prefer_not_to_say: 'PREFER_NOT_TO_SAY', prefer: 'PREFER_NOT_TO_SAY',
              };
              return map[g.toLowerCase()] ?? g.toUpperCase();
            };

            // Create update data and remove fields not in User model
            const { firstName, lastName, ...updateData } = {
              ...p,
              gender: normalizeGender(p.gender),
            };
            
            // ─── TRUST MEMBER: Update Global Points & Streak ─────────────────────────
            const currentUser = await tx.user.findUnique({
                where: { id: userId },
                select: { totalPoints: true, streakDays: true } as any
            });

            await tx.user.update({
                where: { id: userId },
                data: {
                    ...updateData,
                    targetWeightKg: p.targetWeightKg?.toString(),
                    totalPoints: p.totalPoints as any,
                    streakDays: p.streakDays as any,
                    timezone: p.timezone,
                    lastActivityAt: new Date(),
                    ...(fullName ? { fullName } : {})
                } as any
            });

            // ─── TRUST MEMBER: Update Leaderboard Points ──────────────────────────────
            // If totalPoints decreased or increased, we reflect the delta in active rooms
            // so the leaderboard stays in sync with the 'Trusted' member data.
            const totalPointsDelta = (p.totalPoints || 0) - ((currentUser as any)?.totalPoints || 0);
            if (totalPointsDelta !== 0) {
                await tx.roomMembership.updateMany({
                    where: { userId: userId },
                    data: {
                        totalPoints: { increment: totalPointsDelta },
                        weeklyPoints: { increment: totalPointsDelta }
                    }
                });
            }

            // Also propagate to TrainerProfile if it exists for this user
            if (fullName || p.avatarUrl) {
                await tx.trainerProfile.updateMany({
                    where: { userId: userId },
                    data: {
                        ...(fullName ? { fullName } : {}),
                        ...(p.avatarUrl ? { avatarUrl: p.avatarUrl } : {}),
                    }
                });
            }
        }

        // Handle deletions
        if (parsedBody.changes.deletedIds && parsedBody.changes.deletedIds.length > 0) {
            const ids = parsedBody.changes.deletedIds;
            logger.debug(`[Sync] Processing ${ids.length} deletions`, { userId });
            
            // Mark WorkoutPlans as deleted
            await tx.workoutPlan.updateMany({
                where: { id: { in: ids }, userId },
                data: { deletedAt: new Date() } as any
            });

            // Mark DietPlans as deleted
            await tx.dietPlan.updateMany({
                where: { id: { in: ids }, userId },
                data: { deletedAt: new Date() } as any
            });

            // Mark DailyProgress as deleted
            await tx.dailyProgress.updateMany({
                where: { id: { in: ids }, userId },
                data: { deletedAt: new Date() } as any
            });
        }
      });

      await recalculateUserStats(userId);

      res.status(200).json({ success: true, message: 'Sync up successful.' });
    } catch (error: any) {
      logger.error({ error }, '[Sync] Error in syncUp');
      
      if (error instanceof z.ZodError) {
        return res.status(400).json({ 
          error: 'Validation failed', 
          details: error.flatten().fieldErrors 
        });
      }
      serverError(res, error);
    }
  }

  // GET /api/sync/down?since=2024-01-01T00:00:00.000Z
  static async syncDown(req: Request, res: Response) {
    try {
      const userId = (req as any).user.userId;
      const sinceTimestamp = req.query.since as string;

      // ── LOOKBACK CAP: Protect against corrupted/missing since timestamps ──
      // Never look back further than 30 days to prevent unbounded payloads.
      const MAX_LOOKBACK_MS = 30 * 24 * 60 * 60 * 1000;
      const earliestAllowed = new Date(Date.now() - MAX_LOOKBACK_MS);
      let sinceDate = sinceTimestamp ? new Date(sinceTimestamp) : new Date(0);
      if (isNaN(sinceDate.getTime()) || sinceDate < earliestAllowed) {
        sinceDate = earliestAllowed;
      }

      // Fetch all entities for this user updated since the last sync
      const [challenges, dailyProgress, workoutPlans, dietPlans, user] = await Promise.all([
        prisma.userChallenge.findMany({
            where: { userId: userId, updatedAt: { gt: sinceDate } }
        }),
        prisma.dailyProgress.findMany({
            where: { userId: userId, deletedAt: null, updatedAt: { gt: sinceDate } } as any
        }),
        prisma.workoutPlan.findMany({
            where: { userId: userId, deletedAt: null, updatedAt: { gt: sinceDate } } as any,
            include: {
              routines: { where: { isDraft: false }, orderBy: { scheduledDate: 'asc' }, include: { exercises: true } },
              masterTemplate: { include: { routines: { orderBy: { orderIndex: 'asc' }, include: { exercises: { orderBy: { orderIndex: 'asc' } } } } } }
            }
        }),
        prisma.dietPlan.findMany({
            where: { userId: userId, deletedAt: null, updatedAt: { gt: sinceDate } } as any,
            include: {
              meals: { where: { isDraft: false } as any, orderBy: { scheduledDate: 'asc' }, include: { ingredients: true } },
              masterTemplate: { include: { meals: { orderBy: { orderIndex: 'asc' }, include: { ingredients: true } } } }
            }
        }),
        prisma.user.findUnique({
            where: { id: userId }
        })
      ]);

      // ── ANCHOR: Monday of current UTC week ───────────────────────────────────
      // All 28-day projections start here so cached data is date-aligned with
      // the primary fetch endpoints (getActiveWorkoutPlan / getActiveDietPlan).
      const today = new Date();
      today.setUTCHours(0, 0, 0, 0);
      const anchorMonday = new Date(today);
      anchorMonday.setUTCDate(today.getUTCDate() - ((today.getUTCDay() - 1 + 7) % 7));

      const DAY_ENUMS = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
      const DAYS_TO_PROJECT = 28;

      // ── WORKOUT: project 28 days (mirrors getActiveWorkoutPlan logic) ──────────
      // Each template routine is expanded into one scheduledDate entry per
      // occurrence across the 28-day window. This gives toMonthlyEntity() enough
      // data to build all 4 weeks instead of just 1.
      const hydratedWorkoutPlans = workoutPlans.map((plan: any) => {
        if (plan.masterTemplate && plan.masterTemplate.routines?.length > 0) {
          const templateRoutines = plan.masterTemplate.routines as any[];
          const hasExplicitDayOfWeek = templateRoutines.some((r: any) => r.dayOfWeek != null);

          const projectedRoutines: any[] = [];

          for (let i = 0; i < DAYS_TO_PROJECT; i++) {
            const targetDate = new Date(anchorMonday);
            targetDate.setUTCDate(anchorMonday.getUTCDate() + i);
            const currentDayEnum = DAY_ENUMS[targetDate.getUTCDay()];

            let mr: any = null;

            if (hasExplicitDayOfWeek) {
              mr = templateRoutines.find((r: any) => r.dayOfWeek === currentDayEnum) ?? null;
            } else {
              const availableIndices = Array.from(
                new Set(templateRoutines.map((r: any) => r.orderIndex as number))
              ).sort((a: number, b: number) => a - b);
              if (availableIndices.length > 0) {
                const loopIndex = ((i % availableIndices.length) + availableIndices.length) % availableIndices.length;
                const targetIndex = availableIndices[loopIndex];
                mr = templateRoutines.find((r: any) => r.orderIndex === targetIndex) ?? null;
              }
            }

            if (mr) {
              projectedRoutines.push({
                id:             `v_${mr.id}_${i}`,
                planId:         plan.id,
                name:           mr.name,
                dayOfWeek:      mr.dayOfWeek ?? currentDayEnum,
                estimatedMinutes: mr.estimatedMinutes,
                orderIndex:     mr.orderIndex,
                scheduledDate:  targetDate,
                exercises:      mr.exercises.map((ex: any) => ({ ...ex, routineId: mr.id })),
              });
            }
            // No match + hasExplicitDayOfWeek → intentional rest day → skip (no entry)
          }

          plan.routines = projectedRoutines;
        }
        delete plan.masterTemplate;
        return plan;
      });

      // ── DIET: project 28 days anchored to Monday ──────────────────────────────
      // Mirrors getActiveDietPlan projection so cached data stays date-aligned.
      // Uses inferMealType() (not normalizeMealType) so timeOfDay fallback works
      // for trainer recipe-named meals like "Grilled Chicken Pasta" → "LUNCH".
      const hydratedDietPlans = dietPlans.map((plan: any) => {
        if (plan.masterTemplate && plan.masterTemplate.meals?.length > 0) {
          const masterMeals = plan.masterTemplate.meals as any[];
          const hasDayOfWeekMeals = masterMeals.some((m: any) => m.dayOfWeek != null);

          const projectedMeals: any[] = [];
          // Literal per-date meal overrides (manually scheduled)
          const literalMeals = (plan.meals || []) as any[];

          for (let i = 0; i < DAYS_TO_PROJECT; i++) {
            const targetDate = new Date(anchorMonday);
            targetDate.setUTCDate(anchorMonday.getUTCDate() + i);
            const dateString = targetDate.toISOString().split('T')[0];

            // Literal override takes priority
            const overrides = literalMeals.filter((m: any) =>
              m.scheduledDate && new Date(m.scheduledDate).toISOString().split('T')[0] === dateString
            );
            if (overrides.length > 0) {
              projectedMeals.push(...overrides.map((m: any) => ({
                ...m,
                type: inferMealType(m),
              })));
              continue;
            }

            let todaysMasterMeals: any[] = [];

            if (hasDayOfWeekMeals) {
              const currentDayEnum = DAY_ENUMS[targetDate.getUTCDay()];
              todaysMasterMeals = masterMeals.filter((mm: any) => mm.dayOfWeek === currentDayEnum);
            } else {
              // P3-B fix: group meals into day-buckets so all meals for a day
              // are returned together, not one meal per "unique orderIndex" day.
              const sortedMeals = [...masterMeals].sort(
                (a: any, b: any) => (a.orderIndex ?? 0) - (b.orderIndex ?? 0)
              );
              const mealsPerDay = sortedMeals.filter((mm: any) => (mm.orderIndex ?? 0) === 0).length || 1;
              const dayBuckets: any[][] = [];
              for (let k = 0; k < sortedMeals.length; k += mealsPerDay) {
                dayBuckets.push(sortedMeals.slice(k, k + mealsPerDay));
              }
              if (dayBuckets.length > 0) {
                const loopIndex = ((i % dayBuckets.length) + dayBuckets.length) % dayBuckets.length;
                todaysMasterMeals = dayBuckets[loopIndex];
              }
            }

            for (const mm of todaysMasterMeals) {
              const ingredients: any[] = mm.ingredients || [];
              const calories = ingredients.reduce((s: number, item: any) => s + (item.calories || 0), 0);
              const protein  = ingredients.reduce((s: number, item: any) => s + Number(item.protein || 0), 0);
              const carbs    = ingredients.reduce((s: number, item: any) => s + Number(item.carbs || 0), 0);
              const fats     = ingredients.reduce((s: number, item: any) => s + Number(item.fats || 0), 0);

              projectedMeals.push({
                id:           `v_${mm.id}_${i}`,
                planId:       plan.id,
                name:         mm.name,
                type:         inferMealType(mm),   // timeOfDay fallback ✓
                timeOfDay:    mm.timeOfDay,
                orderIndex:   mm.orderIndex,
                scheduledDate: targetDate,
                calories:     Math.round(calories),
                totalCalories: Math.round(calories),
                protein:      Math.round(protein),
                carbs:        Math.round(carbs),
                fats:         Math.round(fats),
                ingredients,
                instructions: mm.instructions,
                isDraft:      false,
                mediaUrl:     mm.mediaUrl,
                dayOfWeek:    mm.dayOfWeek,
              });
            }
          }

          plan.meals = projectedMeals;
          // Align startDate with anchorMonday so DietPlanMapper builds calendar
          // from the same Monday used for projection.
          plan.startDate = anchorMonday;
        }
        delete plan.masterTemplate;
        return plan;
      });

      const userWithFullUrls = user ? {
        ...user,
        avatarUrl: getFullUrl(req, user.avatarUrl),
        idPhotoUrl: getFullUrl(req, user.idPhotoUrl),
      } : null;

      res.status(200).json({
        serverTimestamp: new Date().toISOString(),
        changes: {
            challenges,
            dailyProgress,
            workoutPlans: hydratedWorkoutPlans,
            dietPlans: hydratedDietPlans,
            user: userWithFullUrls
        }
      });

    } catch (error: any) {
      serverError(res, error);
    }
  }
}



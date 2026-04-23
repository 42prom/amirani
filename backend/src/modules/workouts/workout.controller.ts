import { Router, Response } from 'express';
import { z } from 'zod';
import prisma from '../../lib/prisma';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, badRequest, internalError } from '../../utils/response';
import { awardPoints, POINTS } from '../../utils/leaderboard.service';
import logger from '../../lib/logger';

const router = Router();
router.use(authenticate);

// ─── Validation ───────────────────────────────────────────────────────────────

const LoggedSetSchema = z.object({
  exerciseName: z.string().min(1),
  exerciseLibraryId: z.string().optional(),
  setIndex: z.number().int().min(0),
  weightKg: z.number().min(0),
  reps: z.number().int().min(0),
  rpe: z.number().int().min(1).max(10).optional(),
  actualDurationSeconds: z.number().int().min(0).optional(),
});

const SaveWorkoutSessionSchema = z.object({
  routineId: z.string().optional(),
  routineName: z.string(),
  durationSeconds: z.number().int().min(0),
  scheduledDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
  exercises: z.array(z.object({
    exerciseName: z.string(),
    exerciseLibraryId: z.string().optional(),
    targetSets: z.number().int(),
    targetReps: z.number().int(),
    restSeconds: z.number().int(),
    loggedSets: z.array(LoggedSetSchema),
  })),
});

// ─── POST /api/workouts/history — Save completed workout session ──────────────

/**
 * POST /api/workouts/history
 * Called by mobile when user finishes a workout session.
 * Creates WorkoutHistory + CompletedSets, then runs progressive overload check.
 */
router.post('/history', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const parsed = SaveWorkoutSessionSchema.safeParse(req.body);

    if (!parsed.success) {
      return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
        field: e.path.map(String).join('.'),
        message: e.message,
      })));
    }

    const { routineId, routineName, durationSeconds, scheduledDate, exercises } = parsed.data;

    // ── Date validation — reject completions for any day other than today (UTC) ─
    const now = new Date();
    const todayStr = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}`;
    if (scheduledDate && scheduledDate !== todayStr) {
      return badRequest(res, 'Workout can only be logged for today');
    }

    // ── Duplicate guard — prevent submitting the same routine twice on the same day
    if (routineId) {
      const startOfDay = new Date(`${todayStr}T00:00:00.000Z`);
      const endOfDay = new Date(`${todayStr}T23:59:59.999Z`);
      const alreadyLogged = await prisma.workoutHistory.findFirst({
        where: { userId, routineId, completedAt: { gte: startOfDay, lte: endOfDay } },
        select: { id: true },
      });
      if (alreadyLogged) {
        return badRequest(res, 'This workout was already logged today');
      }
    }

    // Calculate total volume (sum of weight × reps for all sets)
    const totalVolume = exercises.reduce((sum, ex) =>
      sum + ex.loggedSets.reduce((s2, set) => s2 + (set.weightKg * set.reps), 0), 0
    );

    const totalSets = exercises.reduce((sum, ex) => sum + ex.loggedSets.length, 0);

    // ── TELEMETRY: Calculate Clinical Calories Burned (Phase 3) ────────────────
    const userRow = await prisma.user.findUnique({ where: { id: userId }, select: { weight: true } });
    const userWeightKg = userRow?.weight ? parseFloat(userRow.weight.toString()) : 75;

    let totalCaloriesBurned = 0;
    const libraryIds = exercises.map(ex => ex.exerciseLibraryId).filter(Boolean) as string[];
    const libraries = await prisma.exerciseLibrary.findMany({ where: { id: { in: libraryIds } } });
    const libraryMap = new Map(libraries.map((l: any) => [l.id, l]));

    for (const ex of exercises) {
      const lib = ex.exerciseLibraryId ? libraryMap.get(ex.exerciseLibraryId) : null;
      const metValue = (lib as any)?.metValue || 3.0; // Assume MET 3.0 (Moderate) if unknown

      for (const set of ex.loggedSets) {
         let durationMin = 0;
         if (set.actualDurationSeconds && set.actualDurationSeconds > 0) {
            durationMin = set.actualDurationSeconds / 60;
         } else {
            // Fallback estimation: 3s per rep + rest time
            durationMin = ((set.reps * 3) + ex.restSeconds) / 60;
         }
         // Formula: (MET × 3.5 × BW in kg) ÷ 200 = kcal/minute
         const kcalPerMin = (metValue * 3.5 * userWeightKg) / 200;
         totalCaloriesBurned += kcalPerMin * durationMin;
      }
    }

    // ── Create history record with all completed sets ────────────────────────
    const history = await prisma.workoutHistory.create({
      data: {
        userId,
        routineId: routineId ?? null,
        durationMinutes: Math.round(durationSeconds / 60),
        caloriesBurned: Math.round(totalCaloriesBurned),
        totalVolume,
        completedSets: {
          create: exercises.flatMap((ex) =>
            ex.loggedSets.map((set) => ({
              exerciseName: ex.exerciseName,
              exerciseLibraryId: ex.exerciseLibraryId ?? null,
              actualSets: 1,
              actualReps: set.reps,
              actualDuration: set.actualDurationSeconds ?? null,
              actualWeight: set.weightKg,
              rpe: set.rpe ?? null,
            }))
          ),
        },
      },
      include: {
        completedSets: true,
      },
    });

    // ── Progressive overload check ────────────────────────────────────────────
    // If the user completed all target sets with RPE ≤ 7 on an exercise
    // that has an ExerciseSet in a routine → bump target weight by 2.5kg
    const progressionResults: Array<{ exercise: string; newWeight: number }> = [];

    if (routineId) {
      for (const ex of exercises) {
        if (ex.loggedSets.length < ex.targetSets) continue; // didn't complete all sets

        const avgRpe = ex.loggedSets.reduce((sum, s) => sum + (s.rpe ?? 7), 0) / ex.loggedSets.length;
        if (avgRpe > 7) continue; // too hard, don't increase

        const avgWeight = ex.loggedSets.reduce((sum, s) => sum + s.weightKg, 0) / ex.loggedSets.length;
        if (avgWeight <= 0) continue; // bodyweight exercise

        // Find the matching ExerciseSet in this routine
        const exerciseSet = await prisma.exerciseSet.findFirst({
          where: {
            routineId,
            exerciseName: { equals: ex.exerciseName, mode: 'insensitive' },
          },
        });

        if (!exerciseSet) continue;

        // Only progress if the user has done this exercise at least once BEFORE today this week.
        // Exclude the session we just saved so the first-ever session never triggers overload.
        const previousSessions = await prisma.completedSet.count({
          where: {
            exerciseName: { equals: ex.exerciseName, mode: 'insensitive' },
            history: {
              userId,
              id:          { not: history.id },
              completedAt: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
            },
          },
        });

        if (previousSessions >= 1) {
          const newWeight = Number((avgWeight + 2.5).toFixed(1));

          await prisma.exerciseSet.update({
            where: { id: exerciseSet.id },
            data: { targetWeight: newWeight },
          });

          progressionResults.push({ exercise: ex.exerciseName, newWeight });
        }
      }
    }

    // ── Award room points (fire-and-forget, non-blocking) ─────────────────────
    awardPoints({
      userId,
      sourceId:   history.id,
      sourceType: 'WORKOUT',
      delta:      POINTS.WORKOUT_COMPLETE,
      reason:     `Completed workout: ${routineName}`,
    }).catch((err) => logger.warn('awardPoints failed', { err }));

    // ── Increment DailyProgress.tasksCompleted (fire-and-forget) ──────────────
    const todayDateObj = new Date(`${todayStr}T00:00:00.000Z`);
    prisma.dailyProgress.updateMany({
      where: { userId, date: todayDateObj },
      data:  { tasksCompleted: { increment: 1 } },
    }).catch((err) => logger.warn('DailyProgress increment failed', { err }));

    return success(res, {
      historyId: history.id,
      durationMinutes: history.durationMinutes,
      totalVolume: Number(history.totalVolume ?? 0),
      totalSets,
      progressions: progressionResults,
    }, undefined, 201);
  } catch (err) {
    logger.error('[Workout] save history error', { err });
    internalError(res);
  }
});

// ─── GET /api/workouts/history — Recent workout history for mobile ────────────

/**
 * GET /api/workouts/history?limit=20&offset=0
 */
router.get('/history', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const limit = Math.min(parseInt(String(req.query.limit ?? '20')), 50);
    const offset = parseInt(String(req.query.offset ?? '0'));

    const [history, total] = await Promise.all([
      prisma.workoutHistory.findMany({
        where: { userId },
        include: {
          completedSets: {
            select: {
              id: true,
              exerciseName: true,
              actualSets: true,
              actualReps: true,
              actualWeight: true,
              rpe: true,
            },
          },
          routine: { select: { id: true, name: true } },
        },
        orderBy: { completedAt: 'desc' },
        take: limit,
        skip: offset,
      }),
      prisma.workoutHistory.count({ where: { userId } }),
    ]);

    return success(res, { history, total, limit, offset });
  } catch (err) {
    logger.error('[Workout] get history error', { err });
    internalError(res);
  }
});

// ─── GET /api/workouts/history/:id — Single session detail ───────────────────

router.get('/history/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;

    const history = await prisma.workoutHistory.findFirst({
      where: { id: req.params.id, userId },
      include: {
        completedSets: true,
        routine: { select: { id: true, name: true } },
      },
    });

    if (!history) {
      return res.status(404).json({ success: false, error: { message: 'Not found' } });
    }

    return success(res, history);
  } catch (err) {
    logger.error('[Workout] get history detail error', { err });
    internalError(res);
  }
});

export default router;



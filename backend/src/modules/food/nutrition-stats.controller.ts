import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, badRequest, internalError } from '../../utils/response';
import prisma from '../../utils/prisma';

const router = Router();
router.use(authenticate);

// ─── GET /api/nutrition/stats/rolling ─────────────────────────────────────────

/**
 * GET /api/nutrition/stats/rolling?days=7
 *
 * Computes rolling macro averages from DailyProgress for the authenticated user.
 * Used by the AI system prompt builder to inject caloric/protein context
 * into workout and diet plan generation.
 *
 * Response:
 * {
 *   days: number,
 *   avgCalories: number,
 *   avgProteinG: number,
 *   avgCarbsG: number,
 *   avgFatsG: number,
 *   caloricStatus: 'SURPLUS' | 'DEFICIT' | 'MAINTENANCE' | 'INSUFFICIENT_DATA',
 *   daysWithData: number
 * }
 */
router.get('/stats/rolling', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId  = req.user!.userId;
    const rawDays = parseInt(String(req.query.days ?? '7'));
    const days    = Math.min(Math.max(rawDays, 1), 90); // clamp 1–90

    const since = new Date();
    since.setDate(since.getDate() - days);
    since.setHours(0, 0, 0, 0);

    const records = await prisma.dailyProgress.findMany({
      where: {
        userId,
        date: { gte: since },
      },
      orderBy: { date: 'desc' },
    });

    if (records.length === 0) {
      return success(res, {
        days,
        avgCalories:   0,
        avgProteinG:   0,
        avgCarbsG:     0,
        avgFatsG:      0,
        caloricStatus: 'INSUFFICIENT_DATA',
        daysWithData:  0,
      });
    }

    const total = records.reduce(
      (acc, r) => ({
        calories: acc.calories + Number(r.caloriesConsumed ?? 0),
        protein:  acc.protein  + Number(r.proteinConsumed  ?? 0),
        carbs:    acc.carbs    + Number(r.carbsConsumed    ?? 0),
        fats:     acc.fats     + Number(r.fatsConsumed     ?? 0),
      }),
      { calories: 0, protein: 0, carbs: 0, fats: 0 }
    );

    const n = records.length;
    const avg = {
      calories: Math.round(total.calories / n),
      protein:  Math.round(total.protein  / n),
      carbs:    Math.round(total.carbs    / n),
      fats:     Math.round(total.fats     / n),
    };

    // Determine caloric status vs standard TDEE ranges
    // (will be enriched by AI controller with actual TDEE from user profile)
    let caloricStatus: 'SURPLUS' | 'DEFICIT' | 'MAINTENANCE' | 'INSUFFICIENT_DATA';
    if (n < 3) {
      caloricStatus = 'INSUFFICIENT_DATA';
    } else if (avg.calories > 2800) {
      caloricStatus = 'SURPLUS';
    } else if (avg.calories < 1600) {
      caloricStatus = 'DEFICIT';
    } else {
      caloricStatus = 'MAINTENANCE';
    }

    return success(res, {
      days,
      avgCalories:   avg.calories,
      avgProteinG:   avg.protein,
      avgCarbsG:     avg.carbs,
      avgFatsG:      avg.fats,
      caloricStatus,
      daysWithData:  n,
    });
  } catch (err) {
    internalError(res);
  }
});

// ─── GET /api/nutrition/stats/today ───────────────────────────────────────────

/**
 * GET /api/nutrition/stats/today
 * Today's macro totals and goal percentages (for dashboard widget).
 */
router.get('/stats/today', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId  = req.user!.userId;
    const today   = new Date();
    today.setHours(0, 0, 0, 0);

    const progress = await prisma.dailyProgress.findUnique({
      where: { userId_date: { userId, date: today } },
    });

    // TODO: Replace with user.calorieGoal once goal fields are added to User schema
    const consumed = {
      calories: Number(progress?.caloriesConsumed ?? 0),
      proteinG: Number(progress?.proteinConsumed  ?? 0),
      carbsG:   Number(progress?.carbsConsumed    ?? 0),
      fatsG:    Number(progress?.fatsConsumed     ?? 0),
    };

    const goals = {
      calories: 2000,
      proteinG: 150,
      carbsG:   200,
      fatsG:    65,
    };

    const pct = (v: number, g: number) => g > 0 ? Math.round((v / g) * 100) : 0;

    return success(res, {
      consumed,
      goals,
      percentages: {
        calories: pct(consumed.calories, goals.calories),
        proteinG: pct(consumed.proteinG, goals.proteinG),
        carbsG:   pct(consumed.carbsG,   goals.carbsG),
        fatsG:    pct(consumed.fatsG,     goals.fatsG),
      },
      date: today.toISOString().split('T')[0],
    });
  } catch (err) {
    internalError(res);
  }
});

export default router;

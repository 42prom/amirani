import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import prisma from '../../lib/prisma';

const router = Router();
router.use(authenticate);

/**
 * PATCH /api/users/me — update profile fields.
 * UNIT CONTRACT: all numeric body metrics are stored in SI units.
 *   weight       → kg  (callers must convert lbs → kg before sending)
 *   heightCm     → cm  (callers must convert inches/ft → cm before sending)
 *   targetWeightKg → kg
 * The DB never stores Imperial values. Conversion happens in the client.
 */
router.patch('/me', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const {
      fullName, unitPreference, languagePreference,
      heightCm, weight, targetWeightKg,
    } = req.body;

    const data: Record<string, unknown> = {};
    if (fullName && typeof fullName === 'string' && fullName.trim()) {
      data.fullName = fullName.trim();
    }
    if (unitPreference === 'METRIC' || unitPreference === 'IMPERIAL') {
      data.unitPreference = unitPreference;
    }
    if (languagePreference === 'EN' || languagePreference === 'KA' || languagePreference === 'RU') {
      data.languagePreference = languagePreference;
    }
    if (typeof heightCm === 'number' && heightCm > 0 && heightCm < 300) {
      data.heightCm = heightCm;
    }
    // weight must be in kg — reject implausible lbs values (> 500 kg is impossible)
    if (typeof weight === 'number' && weight > 0 && weight <= 500) {
      data.weight = weight;
    }
    if (typeof targetWeightKg === 'number' && targetWeightKg > 0 && targetWeightKg <= 500) {
      data.targetWeightKg = targetWeightKg;
    }

    if (Object.keys(data).length === 0) {
      return res.status(400).json({ error: 'No valid fields provided' });
    }

    const user = await prisma.user.update({
      where: { id: req.user!.userId },
      data,
      select: {
        id: true, fullName: true, avatarUrl: true,
        unitPreference: true, languagePreference: true,
        heightCm: true, weight: true, targetWeightKg: true,
      },
    });

    res.json({ data: user });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/users/dashboard/metrics
 * Fetch data for the mobile app's main dashboard widgets.
 * returns DashboardModel: { activeCaloriesBurned, activeMinutes, workoutsCompletedWeek, activeChallengeName, activeChallengeProgress, weeklySparks }
 */
router.get('/dashboard/metrics', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const now = new Date();
    const today = new Date(now);
    today.setHours(0, 0, 0, 0);

    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);

    const [progressToday, recentWorkouts, activeChallenge, weeklyProgress] = await Promise.all([
      // 1. Today's progress
      prisma.dailyProgress.findUnique({
        where: { userId_date: { userId, date: today } }
      }),
      // 2. Workouts this week
      prisma.workoutHistory.count({
        where: { userId, completedAt: { gte: weekAgo } }
      }),
      // 3. Active challenge
      prisma.userChallenge.findFirst({
        where: { userId, status: 'IN_PROGRESS' },
        orderBy: { createdAt: 'desc' }
      }),
      // 4. Last 7 days calories (for the spark graph)
      prisma.dailyProgress.findMany({
        where: { userId, date: { gte: weekAgo } },
        orderBy: { date: 'asc' },
        select: { caloriesConsumed: true, date: true }
      })
    ]);

    // Map weekly sparks (filling in zeros for missing days)
    const sparksMap = new Map<string, number>();
    weeklyProgress.forEach(p => {
      const d = p.date.toISOString().split('T')[0];
      sparksMap.set(d, Number(p.caloriesConsumed || 0));
    });

    const weeklySparks: number[] = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(today);
      d.setDate(d.getDate() - i);
      const ds = d.toISOString().split('T')[0];
      weeklySparks.push(sparksMap.get(ds) || 0);
    }

    const metrics = {
      activeCaloriesBurned: Number(progressToday?.caloriesConsumed || 0),
      activeMinutes: Number(progressToday?.activeMinutes || 0),
      workoutsCompletedWeek: recentWorkouts,
      activeChallengeName: activeChallenge?.title || 'No active challenge',
      activeChallengeProgress: activeChallenge 
        ? Math.min(Number(activeChallenge.currentValue) / Number(activeChallenge.targetValue), 1.0)
        : 0.0,
      weeklySparks
    };

    res.json(metrics);
  } catch (err: any) {
    res.status(500).json({ error: 'Failed to fetch dashboard metrics' });
  }
});

export default router;

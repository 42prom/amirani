import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { ChurnService } from './churn.service';
import { RevenueService } from './revenue.service';
import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';

const router = Router();
router.use(authenticate, branchAdminOrAbove);

// ─── Access guard ─────────────────────────────────────────────────────────────

async function assertGymAccess(gymId: string, userId: string, role: Role, managedGymId?: string | null) {
  const gym = await prisma.gym.findUnique({ where: { id: gymId } });
  if (!gym) throw Object.assign(new Error('Gym not found'), { status: 404 });

  const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
  if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
    throw Object.assign(new Error('Access denied'), { status: 403 });
  }
}

// ─── Routes ───────────────────────────────────────────────────────────────────

/**
 * GET /api/analytics/gyms/:gymId/churn
 * Full churn risk list for all active members (sorted by risk desc)
 */
router.get('/gyms/:gymId/churn', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const members = await ChurnService.computeForGym(req.params.gymId);
    res.json({ data: members });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/churn/at-risk
 * Only members with score >= 35
 */
router.get('/gyms/:gymId/churn/at-risk', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const members = await ChurnService.getAtRisk(req.params.gymId);
    res.json({ data: members });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/churn/summary
 * Aggregate counts: safe / at-risk / high-risk / churning
 */
router.get('/gyms/:gymId/churn/summary', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const summary = await ChurnService.getSummary(req.params.gymId);
    res.json({ data: summary });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/churn/dashboard
 * Single-query response combining all, at-risk, and summary — use this instead of
 * calling the 3 separate endpoints from a dashboard to avoid triple DB hits.
 */
router.get('/gyms/:gymId/churn/dashboard', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const all     = await ChurnService.computeForGym(req.params.gymId);
    const atRisk  = await ChurnService.getAtRisk(req.params.gymId, all);
    const summary = await ChurnService.getSummary(req.params.gymId, all);
    res.json({ data: { members: all, atRisk, summary } });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/revenue
 * Full revenue intelligence: KPIs, monthly trend, plan breakdown, peak hours, recent payments
 */
router.get('/gyms/:gymId/revenue', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const data = await RevenueService.getIntelligence(req.params.gymId);
    res.json({ data });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/revenue/kpis
 * Just the KPI numbers (for dashboard card widgets)
 */
router.get('/gyms/:gymId/revenue/kpis', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const kpis = await RevenueService.getKPIs(req.params.gymId);
    res.json({ data: kpis });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Platform-wide KPIs (Super Admin only) ────────────────────────────────────

/**
 * GET /api/analytics/platform-kpis
 * Total gym owners, total gyms, total revenue this month, avg revenue per owner.
 */
router.get('/platform-kpis', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [ownerCount, gymCount, revenueAgg] = await Promise.all([
      prisma.user.count({ where: { role: Role.GYM_OWNER } }),
      prisma.gym.count({ where: { isActive: true } }),
      prisma.payment.aggregate({
        where: { status: 'SUCCEEDED', createdAt: { gte: monthStart } },
        _sum: { amount: true },
      }),
    ]);

    const totalRevenue = Number(revenueAgg._sum.amount ?? 0);
    res.json({
      data: {
        ownerCount,
        gymCount,
        totalRevenueThisMonth: totalRevenue,
        avgRevenuePerOwner: ownerCount > 0 ? Math.round(totalRevenue / ownerCount) : 0,
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/top-owners?limit=10
 * Top gym owners ranked by revenue this month (Super Admin only).
 */
router.get('/top-owners', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const limit = Math.min(Number(req.query.limit) || 10, 50);
    const monthStart = new Date();
    monthStart.setDate(1);
    monthStart.setHours(0, 0, 0, 0);

    const owners = await prisma.user.findMany({
      where: { role: Role.GYM_OWNER, isActive: true },
      include: {
        ownedGyms: {
          where: { isActive: true },
          include: {
            _count: { select: { memberships: true } },
            payments: {
              where: { status: 'SUCCEEDED', createdAt: { gte: monthStart } },
              select: { amount: true },
            },
          },
        },
      },
    });

    const ranked = owners
      .map((o) => ({
        id: o.id,
        fullName: o.fullName,
        email: o.email,
        isActive: o.isActive,
        gymCount: o.ownedGyms.length,
        activeMembers: o.ownedGyms.reduce((s, g) => s + (g._count?.memberships ?? 0), 0),
        revenueThisMonth: o.ownedGyms.reduce(
          (s, g) => s + g.payments.reduce((ps, p) => ps + Number(p.amount), 0),
          0,
        ),
      }))
      .sort((a, b) => b.revenueThisMonth - a.revenueThisMonth)
      .slice(0, limit);

    res.json({ data: ranked });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gym-owner/dashboard
 * Per-gym aggregate for the authenticated gym owner's dashboard (branch cards).
 */
router.get('/gym-owner/dashboard', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const days = Math.min(Number(req.query.days) || 30, 90);
    const rangeStart = new Date();
    rangeStart.setDate(rangeStart.getDate() - days);

    const gyms = await prisma.gym.findMany({
      where: { ownerId: userId, isActive: true },
      select: {
        id: true,
        name: true,
        city: true,
        country: true,
        _count: {
          select: {
            memberships: { where: { status: 'ACTIVE' } },
            trainers: true,
          },
        },
      },
    });

    const branches = await Promise.all(
      gyms.map(async (gym) => {
        const [todayCheckins, rangeRevenueAgg] = await Promise.all([
          prisma.attendance.count({
            where: { gymId: gym.id, checkIn: { gte: todayStart } },
          }),
          prisma.payment.aggregate({
            where: { gymId: gym.id, status: 'SUCCEEDED', createdAt: { gte: rangeStart } },
            _sum: { amount: true },
          }),
        ]);

        return {
          id: gym.id,
          name: gym.name,
          city: gym.city,
          country: gym.country,
          activeMembers: gym._count.memberships,
          trainerCount: gym._count.trainers,
          todayCheckins,
          monthRevenue: Number(rangeRevenueAgg._sum.amount ?? 0),
        };
      }),
    );

    res.json({ data: branches });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Platform-wide Engagement Analytics (Super Admin only) ───────────────────

/**
 * GET /api/analytics/member-growth?days=30
 * New memberships per day + by month + cohort retention for the period.
 */
router.get('/member-growth', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const days = Math.min(Number(req.query.days) || 30, 365);
    const since = new Date();
    since.setDate(since.getDate() - days);

    const memberships = await prisma.gymMembership.findMany({
      where: { createdAt: { gte: since } },
      select: { createdAt: true, status: true },
      orderBy: { createdAt: 'asc' },
    });

    const byDay: Record<string, number> = {};
    const byMonth: Record<string, number> = {};
    for (const m of memberships) {
      const day = m.createdAt.toISOString().split('T')[0];
      byDay[day] = (byDay[day] ?? 0) + 1;
      const month = m.createdAt.toISOString().slice(0, 7);
      byMonth[month] = (byMonth[month] ?? 0) + 1;
    }

    const totalNew = memberships.length;
    const stillActive = memberships.filter(m => m.status === 'ACTIVE').length;

    res.json({
      data: {
        totalNewThisPeriod: totalNew,
        retentionRate: totalNew > 0 ? Math.round((stillActive / totalNew) * 100) : 0,
        byDay: Object.entries(byDay).map(([date, count]) => ({ date, count })),
        byMonth: Object.entries(byMonth).map(([month, count]) => ({ month, count })),
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/engagement
 * DAU / MAU, avg workouts per week, feature usage counts.
 */
router.get('/engagement', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const [dauWorkout, dauFood, dauCheckin, mauWorkout, mauFood, mauCheckin, weeklyWorkouts] = await Promise.all([
      prisma.workoutHistory.groupBy({ by: ['userId'], where: { completedAt: { gte: todayStart } } }),
      prisma.foodLog.groupBy({ by: ['userId'], where: { loggedAt: { gte: todayStart } } }),
      prisma.attendance.groupBy({ by: ['userId'], where: { checkIn: { gte: todayStart } } }),
      prisma.workoutHistory.groupBy({ by: ['userId'], where: { completedAt: { gte: monthStart } } }),
      prisma.foodLog.groupBy({ by: ['userId'], where: { loggedAt: { gte: monthStart } } }),
      prisma.attendance.groupBy({ by: ['userId'], where: { checkIn: { gte: monthStart } } }),
      prisma.workoutHistory.count({ where: { completedAt: { gte: weekAgo } } }),
    ]);

    const dauSet = new Set([
      ...dauWorkout.map(r => r.userId),
      ...dauFood.map(r => r.userId),
      ...dauCheckin.map(r => r.userId),
    ]);
    const mauSet = new Set([
      ...mauWorkout.map(r => r.userId),
      ...mauFood.map(r => r.userId),
      ...mauCheckin.map(r => r.userId),
    ]);

    const dau = dauSet.size;
    const mau = mauSet.size;

    const [monthlyFoodTotal, monthlyCheckinTotal] = [
      mauFood.length,
      mauCheckin.length,
    ];

    res.json({
      data: {
        dau,
        mau,
        dauMauRatio: mau > 0 ? Math.round((dau / mau) * 100) : 0,
        avgWorkoutsPerWeek: mau > 0 ? Math.round((weeklyWorkouts / mau) * 10) / 10 : 0,
        featureUsage: {
          workoutsToday: dauWorkout.length,
          foodLogsToday: dauFood.length,
          checkinsToday: dauCheckin.length,
          workoutUsersThisMonth: mauWorkout.length,
          foodLogUsersThisMonth: monthlyFoodTotal,
          checkinUsersThisMonth: monthlyCheckinTotal,
        },
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/workout-completion?days=30
 * Total completions, avg session duration, breakdown by day-of-week.
 */
router.get('/workout-completion', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const days = Math.min(Number(req.query.days) || 30, 365);
    const since = new Date();
    since.setDate(since.getDate() - days);

    const [totalPlanned, completedHistory] = await Promise.all([
      prisma.workoutRoutine.count({ where: { plan: { isActive: true, deletedAt: null } } }),
      prisma.workoutHistory.findMany({
        where: { completedAt: { gte: since } },
        select: { completedAt: true, durationMinutes: true },
      }),
    ]);

    const dowCounts: Record<number, number> = { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0 };
    for (const h of completedHistory) {
      dowCounts[h.completedAt.getDay()]++;
    }

    const dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const avgDuration = completedHistory.length > 0
      ? Math.round(completedHistory.reduce((s, h) => s + h.durationMinutes, 0) / completedHistory.length)
      : 0;

    res.json({
      data: {
        totalPlannedRoutines: totalPlanned,
        completionsInPeriod: completedHistory.length,
        avgSessionDurationMinutes: avgDuration,
        byDayOfWeek: Object.entries(dowCounts).map(([dow, count]) => ({
          day: dowLabels[Number(dow)],
          count,
        })),
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/diet-adherence?days=30
 * Meal log rate against active diet plan users, avg daily calories logged.
 */
router.get('/diet-adherence', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const days = Math.min(Number(req.query.days) || 30, 365);
    const since = new Date();
    since.setDate(since.getDate() - days);

    const [mealLogsCount, activeDietUsers, usersLogged, progressSample] = await Promise.all([
      prisma.mealLog.count({ where: { loggedAt: { gte: since } } }),
      prisma.dietPlan.groupBy({ by: ['userId'], where: { isActive: true, deletedAt: null } }),
      prisma.mealLog.groupBy({ by: ['userId'], where: { loggedAt: { gte: since } } }),
      prisma.dailyProgress.findMany({
        where: { date: { gte: since }, caloriesConsumed: { gt: 0 } },
        select: { caloriesConsumed: true },
        take: 5000,
      }),
    ]);

    const avgCalories = progressSample.length > 0
      ? Math.round(progressSample.reduce((s, d) => s + d.caloriesConsumed, 0) / progressSample.length)
      : 0;

    const activePlanUsers = activeDietUsers.length;

    res.json({
      data: {
        activeDietPlanUsers: activePlanUsers,
        usersLoggedMeals: usersLogged.length,
        mealLogRate: activePlanUsers > 0 ? Math.round((usersLogged.length / activePlanUsers) * 100) : 0,
        totalMealLogsInPeriod: mealLogsCount,
        avgDailyCaloriesLogged: avgCalories,
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/leaderboard-health
 * Points tier distribution and activity recency for all active users.
 */
router.get('/leaderboard-health', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const [beginner, active, champion, inactive7d, inactive30d, neverActive, totalWithPoints] = await Promise.all([
      prisma.user.count({ where: { totalPoints: { gte: 0, lt: 100 }, isActive: true } }),
      prisma.user.count({ where: { totalPoints: { gte: 100, lt: 1000 }, isActive: true } }),
      prisma.user.count({ where: { totalPoints: { gte: 1000 }, isActive: true } }),
      prisma.user.count({ where: { lastActivityAt: { lt: sevenDaysAgo }, isActive: true } }),
      prisma.user.count({ where: { lastActivityAt: { lt: thirtyDaysAgo }, isActive: true } }),
      prisma.user.count({ where: { lastActivityAt: null, isActive: true } }),
      prisma.user.count({ where: { totalPoints: { gt: 0 }, isActive: true } }),
    ]);

    res.json({
      data: {
        pointsBuckets: { beginner, active, champion },
        totalUsersWithPoints: totalWithPoints,
        inactiveLast7d: inactive7d,
        inactiveLast30d: inactive30d,
        neverActive,
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/platform-revenue-trend?days=30
 * Realized revenue trend across all gyms.
 */
router.get('/platform-revenue-trend', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const days = Math.min(Number(req.query.days) || 30, 90);
    const results: any[] = [];
    const now = new Date();

    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
      const start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0);
      const end = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59);

      const agg = await prisma.payment.aggregate({
        where: { status: 'SUCCEEDED', createdAt: { gte: start, lte: end } },
        _sum: { amount: true },
      });

      results.push({
        date: start.toISOString().split('T')[0],
        revenue: Math.round(Number(agg._sum.amount ?? 0) * 100) / 100,
      });
    }

    res.json({ data: results });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/platform-stats
 * Quick insights for the dashboard summary box.
 */
router.get('/platform-stats', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.SUPER_ADMIN) return res.status(403).json({ error: 'Super admin only' });

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);

    const [thisMonthAgg, lastMonthAgg, newOwners, activeMemberships] = await Promise.all([
      prisma.payment.aggregate({
        where: { status: 'SUCCEEDED', createdAt: { gte: startOfMonth } },
        _sum: { amount: true },
      }),
      prisma.payment.aggregate({
        where: { status: 'SUCCEEDED', createdAt: { gte: startOfLastMonth, lte: endOfLastMonth } },
        _sum: { amount: true },
      }),
      prisma.user.count({ where: { role: Role.GYM_OWNER, createdAt: { gte: startOfMonth } } }),
      prisma.gymMembership.count({ where: { status: 'ACTIVE' } }),
    ]);

    const revThis = Number(thisMonthAgg._sum.amount ?? 0);
    const revLast = Number(lastMonthAgg._sum.amount ?? 0);
    const growth = revLast > 0 ? ((revThis - revLast) / revLast) * 100 : 0;

    res.json({
      data: {
        revenueGrowth: Math.round(growth * 10) / 10,
        newPartners: newOwners,
        totalActiveMembers: activeMemberships,
        topGymName: (await prisma.gym.findFirst({
          where: { isActive: true },
          orderBy: { memberships: { _count: 'desc' } },
          select: { name: true }
        }))?.name || "N/A"
      }
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Gym Owner Deep-Dive Analytics (P3-5) ────────────────────────────────────

/**
 * GET /api/analytics/gyms/:gymId/pulse
 * Today's check-ins by hour + yesterday comparison (occupancy heatmap).
 */
router.get('/gyms/:gymId/pulse', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const now = new Date();
    const todayStart    = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const yesterdayStart = new Date(todayStart.getTime() - 24 * 60 * 60 * 1000);

    const [todayRecords, yesterdayCount, activeNow] = await Promise.all([
      prisma.attendance.findMany({
        where: { gymId: req.params.gymId, checkIn: { gte: todayStart } },
        select: { checkIn: true },
      }),
      prisma.attendance.count({
        where: { gymId: req.params.gymId, checkIn: { gte: yesterdayStart, lt: todayStart } },
      }),
      prisma.attendance.count({
        where: { gymId: req.params.gymId, checkOut: null, checkIn: { gte: todayStart } },
      }),
    ]);

    const hourly = Array.from({ length: 24 }, (_, h) => ({ hour: h, count: 0 }));
    for (const r of todayRecords) hourly[r.checkIn.getHours()].count++;

    res.json({
      data: {
        activeNow,
        todayTotal: todayRecords.length,
        yesterdayTotal: yesterdayCount,
        vsYesterday: yesterdayCount > 0
          ? Math.round(((todayRecords.length - yesterdayCount) / yesterdayCount) * 100)
          : 0,
        hourlyCheckins: hourly,
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/retention-heatmap
 * Check-in count by day-of-week for the last 12 weeks — reveals dropout patterns.
 */
router.get('/gyms/:gymId/retention-heatmap', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const twelveWeeksAgo = new Date(Date.now() - 84 * 24 * 60 * 60 * 1000);

    const records = await prisma.attendance.findMany({
      where: { gymId: req.params.gymId, checkIn: { gte: twelveWeeksAgo } },
      select: { checkIn: true },
    });

    const dowCounts: Record<number, number> = { 0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0 };
    for (const r of records) dowCounts[r.checkIn.getDay()]++;

    const dowLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const byDayOfWeek = Object.entries(dowCounts).map(([dow, count]) => ({
      day: dowLabels[Number(dow)],
      count,
      avgPerWeek: Math.round(count / 12),
    }));

    res.json({
      data: { byDayOfWeek, periodWeeks: 12, totalCheckins: records.length },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/top-trainers
 * Trainers ranked by session completion rate + assigned members this month.
 */
router.get('/gyms/:gymId/top-trainers', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const gymId = req.params.gymId;

    // Unique trainers at this gym via sessions or member assignments
    const [sessionTrainerIds, membershipTrainerIds] = await Promise.all([
      prisma.trainingSession.findMany({
        where: { gymId },
        select: { trainerId: true },
        distinct: ['trainerId'],
      }),
      prisma.gymMembership.findMany({
        where: { gymId, trainerId: { not: null }, status: 'ACTIVE' },
        select: { trainerId: true },
        distinct: ['trainerId'],
      }),
    ]);

    const allIds = [...new Set([
      ...sessionTrainerIds.map(s => s.trainerId),
      ...membershipTrainerIds.map(m => m.trainerId!),
    ])];

    if (allIds.length === 0) return res.json({ data: [] });

    const [profiles, monthSessions, assignedCounts] = await Promise.all([
      prisma.trainerProfile.findMany({
        where: { id: { in: allIds } },
        include: { user: { select: { fullName: true } } },
      }),
      prisma.trainingSession.findMany({
        where: { gymId, trainerId: { in: allIds }, startTime: { gte: monthStart } },
        select: { trainerId: true, status: true },
      }),
      prisma.gymMembership.groupBy({
        by: ['trainerId'],
        where: { gymId, trainerId: { in: allIds }, status: 'ACTIVE' },
        _count: { trainerId: true },
      }),
    ]);

    const sessionMap = new Map<string, { total: number; completed: number }>();
    for (const s of monthSessions) {
      const cur = sessionMap.get(s.trainerId) ?? { total: 0, completed: 0 };
      cur.total++;
      if (s.status === 'COMPLETED') cur.completed++;
      sessionMap.set(s.trainerId, cur);
    }
    const assignMap = new Map(assignedCounts.map(a => [a.trainerId!, a._count.trainerId]));

    const result = profiles.map(tp => {
      const stats = sessionMap.get(tp.id) ?? { total: 0, completed: 0 };
      return {
        trainerId: tp.id,
        fullName: tp.user?.fullName ?? 'Unknown',
        assignedMembers: assignMap.get(tp.id) ?? 0,
        sessionsThisMonth: stats.total,
        completionRate: stats.total > 0 ? Math.round((stats.completed / stats.total) * 100) : 0,
      };
    }).sort((a, b) => b.completionRate - a.completionRate || b.assignedMembers - a.assignedMembers);

    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/analytics/gyms/:gymId/plan-mix
 * Membership plan distribution: active count, percentage, revenue share, status breakdown.
 */
router.get('/gyms/:gymId/plan-mix', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);

    const memberships = await prisma.gymMembership.findMany({
      where: { gymId: req.params.gymId, deletedAt: null },
      include: { plan: { select: { id: true, name: true, price: true } } },
    });

    type PlanBucket = { name: string; price: number; active: number; pending: number; cancelled: number; frozen: number; total: number };
    const planMap = new Map<string, PlanBucket>();

    for (const m of memberships) {
      if (!planMap.has(m.planId)) {
        planMap.set(m.planId, { name: m.plan.name, price: Number(m.plan.price ?? 0), active: 0, pending: 0, cancelled: 0, frozen: 0, total: 0 });
      }
      const bucket = planMap.get(m.planId)!;
      bucket.total++;
      if (m.status === 'ACTIVE') bucket.active++;
      else if (m.status === 'PENDING') bucket.pending++;
      else if (m.status === 'CANCELLED') bucket.cancelled++;
      else if (m.status === 'FROZEN') bucket.frozen++;
    }

    const totalActive = memberships.filter(m => m.status === 'ACTIVE').length;

    const plans = Array.from(planMap.entries()).map(([planId, v]) => ({
      planId,
      name: v.name,
      price: v.price,
      activeCount: v.active,
      pendingCount: v.pending,
      cancelledCount: v.cancelled,
      frozenCount: v.frozen,
      percentage: totalActive > 0 ? Math.round((v.active / totalActive) * 100) : 0,
    })).sort((a, b) => b.activeCount - a.activeCount);

    res.json({ data: { plans, totalActiveMembers: totalActive } });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

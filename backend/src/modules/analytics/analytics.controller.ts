import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { ChurnService } from './churn.service';
import { RevenueService } from './revenue.service';
import prisma from '../../utils/prisma';
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

export default router;

import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { AutomationService, ALL_TRIGGERS } from './automation.service';
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
 * GET /api/automations/gyms/:gymId/rules
 * List all automation rules for a gym
 */
router.get('/gyms/:gymId/rules', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const rules = await AutomationService.list(req.params.gymId);
    res.json({ data: rules });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/automations/triggers
 * List available trigger types with labels
 */
router.get('/triggers', async (_req: AuthenticatedRequest, res: Response) => {
  const triggers = ALL_TRIGGERS.map((t) => ({
    value: t,
    label: require('./automation.service').TRIGGER_LABELS[t] as string,
  }));
  res.json({ data: triggers });
});

/**
 * POST /api/automations/gyms/:gymId/rules
 * Create a new automation rule
 */
router.post('/gyms/:gymId/rules', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const { name, trigger, subject, body, channels } = req.body;

    if (!name || !trigger || !body || !channels?.length) {
      return res.status(400).json({ error: 'name, trigger, body, and channels are required' });
    }
    if (!ALL_TRIGGERS.includes(trigger)) {
      return res.status(400).json({ error: `Invalid trigger. Must be one of: ${ALL_TRIGGERS.join(', ')}` });
    }

    const rule = await AutomationService.create(req.params.gymId, { name, trigger, subject, body, channels });
    res.status(201).json({ data: rule });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /api/automations/gyms/:gymId/rules/:id
 * Update rule content or toggle isActive
 */
router.patch('/gyms/:gymId/rules/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const { name, subject, body, channels, isActive } = req.body;
    const rule = await AutomationService.update(req.params.id, req.params.gymId, {
      name, subject, body, channels, isActive,
    });
    res.json({ data: rule });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /api/automations/gyms/:gymId/rules/:id
 */
router.delete('/gyms/:gymId/rules/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    await AutomationService.deleteRule(req.params.id, req.params.gymId);
    res.json({ data: { deleted: true } });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /api/automations/gyms/:gymId/rules/:id/run
 * Manually run a rule now (24h look-back window)
 */
router.post('/gyms/:gymId/rules/:id/run', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await assertGymAccess(req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId);
    const result = await AutomationService.runNow(req.params.id, req.params.gymId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

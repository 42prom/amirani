import { Router, Response } from 'express';
import { MembershipService } from './membership.service';
import { FreezeService } from './freeze.service';
import {
  authenticate,
  gymOwnerOrAbove,
  branchAdminOrAbove,
  superAdminOnly,
  AuthenticatedRequest
} from '../../middleware/auth.middleware';
import prisma from '../../lib/prisma';
import { success, forbidden, notFound, internalError, serverError, badRequest, created } from '../../lib/response';
import logger from '../../lib/logger';

const router = Router();

router.use(authenticate);

/**
 * GET /memberships/gyms/:gymId/members - Get all members of a gym (Branch Admin or above)
 */
router.get('/gyms/:gymId/members', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const members = await MembershipService.getGymMembers(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    return success(res, members);
  } catch (error: any) {
    if (error.message === 'Gym not found') {
      return notFound(res, 'Gym');
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * POST /memberships/:id/assign-trainer - Assign trainer to member
 */
router.post('/:id/assign-trainer', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const membership = await MembershipService.assignTrainer(
      req.params.id,
      req.body.trainerId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    return success(res, membership);
  } catch (error: any) {
    if (error.message === 'Membership not found' || error.message === 'Trainer not found in this gym') {
      return notFound(res, error.message);
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return badRequest(res, error.message);
  }
});

/**
 * PATCH /memberships/:id/status - Update membership status
 */
router.patch('/:id/status', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const membership = await MembershipService.updateStatus(
      req.params.id,
      req.body.status,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    return success(res, membership);
  } catch (error: any) {
    if (error.message === 'Membership not found') {
      return notFound(res, 'Membership');
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return badRequest(res, error.message);
  }
});

/**
 * POST /memberships/gyms/:gymId/subscription-plans - Create subscription plan
 */
router.post('/gyms/:gymId/subscription-plans', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const plan = await MembershipService.createPlan(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    return created(res, plan);
  } catch (error: any) {
    if (error.message === 'Gym not found') {
      return notFound(res, 'Gym');
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return badRequest(res, error.message);
  }
});

/**
 * GET /memberships/gyms/:gymId/subscription-plans - Get gym subscription plans
 */
router.get('/gyms/:gymId/subscription-plans', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const plans = await MembershipService.getGymPlans(req.params.gymId);
    return success(res, plans);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /memberships/subscription-plans/:id - Update subscription plan
 */
router.patch('/subscription-plans/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const plan = await MembershipService.updatePlan(
      req.params.id,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    return success(res, plan);
  } catch (error: any) {
    if (error.message === 'Plan not found') {
      return notFound(res, 'Plan');
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return badRequest(res, error.message);
  }
});

/**
 * POST /memberships/gyms/:gymId/manual-register - Manual member registration
 */
router.post('/gyms/:gymId/manual-register', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await MembershipService.manualCreateMember(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    return created(res, result);
  } catch (error: any) {
    if (error.name === 'MembershipValidationError') {
      return error(res, 400, 'VALIDATION_ERROR', error.message, error.details);
    }
    if (error.message === 'Gym not found') {
      return notFound(res, 'Gym');
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * POST /memberships/gyms/:gymId/manual-activate - Manual member activation/renewal
 */
router.post('/gyms/:gymId/manual-activate', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await MembershipService.manualActivateMember(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    return success(res, result);
  } catch (error: any) {
    if (error.name === 'MembershipValidationError') {
      return error(res, 400, 'VALIDATION_ERROR', error.message, error.details);
    }
    if (error.message === 'Gym not found' || error.message === 'Member not found') {
      return notFound(res, error.message);
    }
    if (error.message === 'Access denied') {
      return forbidden(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * POST /memberships/gyms/:gymId/:membershipId/freeze
 * Freeze an active membership for N days
 */
router.post('/gyms/:gymId/:membershipId/freeze', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { days, reason } = req.body;
    if (!days || days < 1 || days > 180) {
      return res.status(400).json({ error: 'days must be between 1 and 180' });
    }
    const updated = await FreezeService.freeze(
      req.params.membershipId,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      { days: Number(days), reason }
    );
    res.json({ data: updated });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /memberships/gyms/:gymId/:membershipId/unfreeze
 * Unfreeze a frozen membership immediately
 */
router.post('/gyms/:gymId/:membershipId/unfreeze', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const updated = await FreezeService.unfreeze(
      req.params.membershipId,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: updated });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /memberships/leave/:gymId
 * Member self-service gym leave. Sets membership status to CANCELLED.
 */
router.delete('/leave/:gymId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { gymId } = req.params;

    const membership = await prisma.gymMembership.findFirst({
      where: { userId, gymId, status: { in: ['ACTIVE', 'FROZEN'] } },
    });

    if (!membership) {
      return res.status(404).json({ success: false, error: { message: 'No active membership found for this gym' } });
    }

    await prisma.gymMembership.update({
      where: { id: membership.id },
      data: { status: 'CANCELLED' },
    });

    return success(res, { left: true, gymId });
  } catch (err) {
    logger.error('[Membership] leave error', { err });
    serverError(res, err);
  }
});

/**
 * GET /memberships/my
 * Returns the authenticated user's gym memberships (for mobile app).
 * Response shape matches GymMembershipInfo.fromJson in Flutter.
 */
router.get('/my', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const memberships = await prisma.gymMembership.findMany({
      where: { userId },
      include: {
        gym: { select: { id: true, name: true, logoUrl: true } },
        plan: { select: { id: true, name: true } },
        trainer: { select: { id: true, fullName: true, avatarUrl: true, specialization: true } },
      },
      orderBy: { startDate: 'desc' },
    });

    return success(res, memberships);
  } catch (err) {
    logger.error('[Membership] /my error', { err });
    serverError(res, err);
  }
});

/**
 * PATCH /memberships/gyms/:gymId/members/:userId
 * Branch manager edits a member's profile
 */
router.patch('/gyms/:gymId/members/:userId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const user = await MembershipService.updateMemberProfile(
      req.params.gymId,
      req.params.userId,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    res.json(user);
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /memberships/gyms/:gymId/members/:userId
 * Branch manager removes member from branch (cancels membership)
 */
router.delete('/gyms/:gymId/members/:userId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await MembershipService.removeMemberFromGym(
      req.params.gymId,
      req.params.userId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json(result);
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

import { Router, Response } from 'express';
import {
  DoorAccessService,
  DoorAccessNotFoundError,
  DoorAccessDeniedError,
  DoorAccessValidationError,
} from './door-access.service';
import { AccessControlService } from './access-control.service';
import {
  authenticate,
  gymOwnerOrAbove,
  branchAdminOrAbove,
  validateBranchOwnership,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import {
  success,
  created,
  notFound,
  forbidden,
  badRequest,
  internalError,
} from '../../utils/response';
import { awardPoints, POINTS } from '../../utils/leaderboard.service';
import logger from '../../utils/logger';

const router = Router();

// All door access routes require authentication
router.use(authenticate);

// ─── Door System Management (Admin) ──────────────────────────────────────────

/**
 * POST /door-access/gyms/:gymId/systems
 * Create a new door system for a gym
 */
router.post(
  '/gyms/:gymId/systems',
  branchAdminOrAbove,
  validateBranchOwnership('gymId'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const doorSystem = await DoorAccessService.createDoorSystem(
        req.params.gymId,
        req.user!.userId,
        req.user!.role,
        req.body
      );
      created(res, doorSystem);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Create door system error');
      internalError(res);
    }
  }
);

/**
 * GET /door-access/gyms/:gymId/systems
 * Get all door systems for a gym
 */
router.get(
  '/gyms/:gymId/systems',
  branchAdminOrAbove,
  validateBranchOwnership('gymId'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const doorSystems = await DoorAccessService.getGymDoorSystems(
        req.params.gymId,
        req.user!.userId,
        req.user!.role
      );
      success(res, doorSystems);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Get door systems error');
      internalError(res);
    }
  }
);

/**
 * PATCH /door-access/systems/:id
 * Update a door system
 */
router.patch(
  '/systems/:id',
  branchAdminOrAbove,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const doorSystem = await DoorAccessService.updateDoorSystem(
        req.params.id,
        req.user!.userId,
        req.user!.role,
        req.body
      );
      success(res, doorSystem);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Update door system error');
      internalError(res);
    }
  }
);

/**
 * DELETE /door-access/systems/:id
 * Delete a door system
 */
router.delete(
  '/systems/:id',
  branchAdminOrAbove,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      await DoorAccessService.deleteDoorSystem(
        req.params.id,
        req.user!.userId,
        req.user!.role
      );
      res.status(204).send();
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Delete door system error');
      internalError(res);
    }
  }
);

/**
 * GET /door-access/gyms/:gymId/systems/health
 * Check health of all door systems
 */
router.get(
  '/gyms/:gymId/systems/health',
  branchAdminOrAbove,
  validateBranchOwnership('gymId'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const health = await DoorAccessService.checkDoorSystemsHealth(
        req.params.gymId,
        req.user!.userId,
        req.user!.role
      );
      success(res, health);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Check door health error');
      internalError(res);
    }
  }
);

// ─── Door Unlock (Members) ───────────────────────────────────────────────────

/**
 * POST /door-access/systems/:id/unlock
 * Request door unlock - generates unlock code for the authenticated user
 */
router.post('/systems/:id/unlock', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await DoorAccessService.requestUnlock(
      req.params.id,
      req.user!.userId
    );
    success(res, result);
  } catch (err) {
    if (err instanceof DoorAccessNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof DoorAccessDeniedError) {
      return forbidden(res, err.message);
    }
    if (err instanceof DoorAccessValidationError) {
      return badRequest(res, err.message);
    }
    logger.error({ err }, 'Request unlock error');
    internalError(res);
  }
});

/**
 * POST /door-access/systems/:id/validate
 * Validate an unlock code (called by door hardware)
 */
router.post('/systems/:id/validate', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { code } = req.body;
    if (!code) {
      return badRequest(res, 'Unlock code is required');
    }

    const result = await DoorAccessService.validateUnlock(req.params.id, code);
    success(res, result);
  } catch (err) {
    if (err instanceof DoorAccessNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error({ err }, 'Validate unlock error');
    internalError(res);
  }
});

/**
 * POST /door-access/systems/:id/revoke/:userId
 * Revoke access for a user
 */
router.post(
  '/systems/:id/revoke/:userId',
  branchAdminOrAbove,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const result = await DoorAccessService.revokeAccess(
        req.params.id,
        req.params.userId,
        req.user!.userId,
        req.user!.role
      );
      success(res, result);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Revoke access error');
      internalError(res);
    }
  }
);

// ─── Access Logs ─────────────────────────────────────────────────────────────

/**
 * GET /door-access/systems/:id/logs
 * Get access logs for a specific door
 */
router.get(
  '/systems/:id/logs',
  branchAdminOrAbove,
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { startDate, endDate, limit } = req.query;

      const logs = await DoorAccessService.getAccessLogs(
        req.params.id,
        req.user!.userId,
        req.user!.role,
        {
          startDate: startDate ? new Date(startDate as string) : undefined,
          endDate: endDate ? new Date(endDate as string) : undefined,
          limit: limit ? parseInt(limit as string) : undefined,
        }
      );
      success(res, logs);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Get access logs error');
      internalError(res);
    }
  }
);

/**
 * GET /door-access/gyms/:gymId/logs
 * Get access logs for all doors in a gym
 */
router.get(
  '/gyms/:gymId/logs',
  branchAdminOrAbove,
  validateBranchOwnership('gymId'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { limit } = req.query;

      const logs = await DoorAccessService.getGymAccessLogs(
        req.params.gymId,
        req.user!.userId,
        req.user!.role,
        {
          limit: limit ? parseInt(limit as string) : undefined,
        }
      );
      success(res, logs);
    } catch (err) {
      if (err instanceof DoorAccessNotFoundError) {
        return notFound(res, err.resource);
      }
      if (err instanceof DoorAccessDeniedError) {
        return forbidden(res, err.message);
      }
      logger.error({ err }, 'Get gym access logs error');
      internalError(res);
    }
  }
);

// ─── Access Control (Time-Based) ─────────────────────────────────────────────

/**
 * GET /door-access/gyms/:gymId/access-check
 * Check if current user can access the gym right now (based on plan restrictions)
 */
router.get('/gyms/:gymId/access-check', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AccessControlService.validateAccess(
      req.user!.userId,
      req.params.gymId
    );
    success(res, result);
  } catch (err) {
    logger.error({ err }, 'Access check error');
    internalError(res);
  }
});

/**
 * GET /door-access/gyms/:gymId/access-schedule
 * Get user's access schedule for a gym
 */
router.get('/gyms/:gymId/access-schedule', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const schedule = await AccessControlService.getUserAccessSchedule(
      req.user!.userId,
      req.params.gymId
    );

    if (!schedule) {
      return notFound(res, 'No active membership found');
    }

    success(res, schedule);
  } catch (err) {
    logger.error({ err }, 'Get access schedule error');
    internalError(res);
  }
});

/**
 * GET /door-access/gyms/:gymId/access-windows
 * Get upcoming access windows for the user
 */
router.get('/gyms/:gymId/access-windows', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { days } = req.query;
    const windows = await AccessControlService.getUpcomingAccessWindows(
      req.user!.userId,
      req.params.gymId,
      days ? parseInt(days as string) : 7
    );
    success(res, windows);
  } catch (err) {
    logger.error({ err }, 'Get access windows error');
    internalError(res);
  }
});

/**
 * POST /door-access/systems/:id/unlock-with-validation
 * Request door unlock with full access control validation
 */
router.post('/systems/:id/unlock-with-validation', async (req: AuthenticatedRequest, res: Response) => {
  try {
    // First, get the door system to find the gym
    const doorSystem = await DoorAccessService.getDoorSystem(req.params.id);

    if (!doorSystem) {
      return notFound(res, 'Door system not found');
    }

    // Validate access based on plan restrictions
    const accessResult = await AccessControlService.validateAndLogAccess(
      req.user!.userId,
      doorSystem.gymId,
      req.params.id,
      req.body.deviceInfo
    );

    if (!accessResult.allowed) {
      return forbidden(res, accessResult.reason || 'Access denied');
    }

    // If access is allowed, generate unlock code
    const unlockResult = await DoorAccessService.requestUnlock(
      req.params.id,
      req.user!.userId
    );

    // Award check-in points (fire-and-forget — never blocks unlock response)
    awardPoints({
      userId:     req.user!.userId,
      sourceId:   req.params.id,      // doorSystem ID — stable sourceId for dedup
      sourceType: 'CHECKIN',
      delta:      POINTS.CHECKIN,
      reason:     'Gym check-in',
    }).catch((err) => logger.warn({ err }, 'awardPoints(CHECKIN) failed'));

    success(res, {
      ...unlockResult,
      accessValidation: accessResult,
    });
  } catch (err) {
    if (err instanceof DoorAccessNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof DoorAccessDeniedError) {
      return forbidden(res, err.message);
    }
    if (err instanceof DoorAccessValidationError) {
      return badRequest(res, err.message);
    }
    logger.error({ err }, 'Request unlock with validation error');
    internalError(res);
  }
});

export default router;



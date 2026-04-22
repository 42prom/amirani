import { Router, Response } from 'express';
import {
  AttendanceService,
  AttendanceNotFoundError,
  AttendanceAccessDeniedError,
  AttendanceValidationError,
} from './attendance.service';
import {
  authenticate,
  gymOwnerOrAbove,
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
import logger from '../../utils/logger';

const router = Router();

// All attendance routes require authentication
router.use(authenticate);

/**
 * POST /attendance/check-in
 * Check in a member to a gym
 */
router.post('/check-in', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { userId, gymId } = req.body;

    // If no userId provided, use the authenticated user
    const targetUserId = userId || req.user!.userId;

    const attendance = await AttendanceService.checkIn(
      targetUserId,
      gymId,
      req.user!.userId,
      req.user!.role
    );
    created(res, attendance);
  } catch (err) {
    if (err instanceof AttendanceNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AttendanceValidationError) {
      return badRequest(res, err.message);
    }
    if (err instanceof AttendanceAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error({ err }, 'Check-in error');
    internalError(res);
  }
});

/**
 * POST /attendance/:id/check-out
 * Check out from a gym
 */
router.post('/:id/check-out', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const attendance = await AttendanceService.checkOut(
      req.params.id,
      req.user!.userId,
      req.user!.role
    );
    success(res, attendance);
  } catch (err) {
    if (err instanceof AttendanceNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AttendanceValidationError) {
      return badRequest(res, err.message);
    }
    logger.error({ err }, 'Check-out error');
    internalError(res);
  }
});

/**
 * GET /attendance/gyms/:gymId
 * Get attendance records for a gym
 */
router.get('/gyms/:gymId', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { startDate, endDate, limit, offset } = req.query;

    const options = {
      startDate: startDate ? new Date(startDate as string) : undefined,
      endDate: endDate ? new Date(endDate as string) : undefined,
      limit: limit ? parseInt(limit as string) : undefined,
      offset: offset ? parseInt(offset as string) : undefined,
    };

    const result = await AttendanceService.getGymAttendance(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      options
    );
    success(res, result);
  } catch (err) {
    if (err instanceof AttendanceNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AttendanceAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error({ err }, 'Get gym attendance error');
    internalError(res);
  }
});

/**
 * GET /attendance/gyms/:gymId/today
 * Get today's attendance for a gym
 */
router.get('/gyms/:gymId/today', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const attendance = await AttendanceService.getTodayAttendance(
      req.params.gymId,
      req.user!.userId,
      req.user!.role
    );
    success(res, attendance);
  } catch (err) {
    if (err instanceof AttendanceNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AttendanceAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error({ err }, 'Get today attendance error');
    internalError(res);
  }
});

/**
 * GET /attendance/gyms/:gymId/stats
 * Get attendance statistics for a gym
 */
router.get('/gyms/:gymId/stats', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await AttendanceService.getGymAttendanceStats(
      req.params.gymId,
      req.user!.userId,
      req.user!.role
    );
    success(res, stats);
  } catch (err) {
    if (err instanceof AttendanceNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AttendanceAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error({ err }, 'Get attendance stats error');
    internalError(res);
  }
});

/**
 * GET /attendance/users/:userId
 * Get attendance records for a specific user
 */
router.get('/users/:userId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId } = req.query;

    const attendance = await AttendanceService.getUserAttendance(
      req.params.userId,
      req.user!.userId,
      req.user!.role,
      gymId as string | undefined
    );
    success(res, attendance);
  } catch (err) {
    if (err instanceof AttendanceAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error({ err }, 'Get user attendance error');
    internalError(res);
  }
});

/**
 * GET /attendance/users/:userId/gyms/:gymId/missed
 * Get missed days analysis for a user at a gym
 */
router.get('/users/:userId/gyms/:gymId/missed', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { days } = req.query;

    const analysis = await AttendanceService.getMissedDays(
      req.params.userId,
      req.params.gymId,
      days ? parseInt(days as string) : 30
    );
    success(res, analysis);
  } catch (err) {
    if (err instanceof AttendanceNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error({ err }, 'Get missed days error');
    internalError(res);
  }
});

/**
 * GET /attendance/me
 * Get current user's attendance history
 */
router.get('/me', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId } = req.query;

    const attendance = await AttendanceService.getUserAttendance(
      req.user!.userId,
      req.user!.userId,
      req.user!.role,
      gymId as string | undefined
    );
    success(res, attendance);
  } catch (err) {
    logger.error({ err }, 'Get my attendance error');
    internalError(res);
  }
});

export default router;


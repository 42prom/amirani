import { Router, Response } from 'express';
import {
  MembershipService,
  MembershipValidationError,
  MembershipNotFoundError,
  MembershipAccessDeniedError,
  ManualRegistrationRequest,
  ManualActivationRequest,
} from '../memberships/membership.service';
import { DoorAccessService } from '../door-access/door-access.service';
import { GymService } from './gym.service';
import {
  authenticate,
  branchAdminOrAbove,
  validateBranchOwnership,
  gymOwnerOnly,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import {
  success,
  created,
  badRequest,
  forbidden,
  notFound,
  validationError,
  internalError,
} from '../../utils/response';
import logger from '../../lib/logger';

const router = Router();

// All branch manager routes require authentication and branch admin role
router.use(authenticate);
router.use(branchAdminOrAbove);

/**
 * POST /branch/:id/manual-create - Manual member registration
 *
 * Creates a new user and assigns them a membership.
 * Branch Admin can only create members for their assigned branch.
 */
router.post(
  '/:id/manual-create',
  validateBranchOwnership('id'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const data: ManualRegistrationRequest = {
        fullName: req.body.fullName,
        email: req.body.email,
        phoneNumber: req.body.phoneNumber,
        subscriptionPlanId: req.body.subscriptionPlanId,
        startDate: req.body.startDate,
        sendNotification: req.body.sendNotification,
      };

      const result = await MembershipService.manualCreateMember(
        req.params.id,
        req.user!.userId,
        req.user!.role,
        data,
        req.user!.managedGymId
      );

      return created(res, result);
    } catch (error: unknown) {
      if (error instanceof MembershipValidationError) {
        return validationError(res, error.details);
      }
      if (error instanceof MembershipNotFoundError) {
        return notFound(res, error.resource);
      }
      if (error instanceof MembershipAccessDeniedError) {
        return forbidden(res, error.message);
      }
      logger.error('Manual create error', { error });
      return internalError(res, 'Failed to create member');
    }
  }
);

/**
 * POST /branch/:id/manual-activate - Manual membership activation/renewal
 *
 * Activates or renews an existing member's subscription.
 * Branch Admin can only activate members for their assigned branch.
 */
router.post(
  '/:id/manual-activate',
  validateBranchOwnership('id'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const data: ManualActivationRequest = {
        memberId: req.body.memberId,
        planId: req.body.planId,
        durationValue: req.body.durationDays || req.body.durationValue,
        durationUnit: req.body.durationUnit,
        startDate: req.body.startDate,
      };

      if (!data.memberId || !data.planId) {
        return badRequest(res, 'memberId and planId are required');
      }

      const result = await MembershipService.manualActivateMember(
        req.params.id,
        req.user!.userId,
        req.user!.role,
        data,
        req.user!.managedGymId
      );

      return success(res, result);
    } catch (error: unknown) {
      if (error instanceof MembershipValidationError) {
        return validationError(res, error.details);
      }
      if (error instanceof MembershipNotFoundError) {
        return notFound(res, error.resource);
      }
      if (error instanceof MembershipAccessDeniedError) {
        return forbidden(res, error.message);
      }
      logger.error('Manual activate error', { error });
      return internalError(res, 'Failed to activate membership');
    }
  }
);

/**
 * GET /branch/:id/search-members - Search members for activation dropdown
 *
 * Returns members matching the search query.
 */
router.get(
  '/:id/search-members',
  validateBranchOwnership('id'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const query = (req.query.q as string) || '';
      const limit = Math.min(parseInt(req.query.limit as string) || 10, 50);

      const members = await MembershipService.searchMembers(
        req.params.id,
        req.user!.userId,
        req.user!.role,
        query,
        limit,
        req.user!.managedGymId
      );

      return success(res, members);
    } catch (error: unknown) {
      if (error instanceof MembershipAccessDeniedError) {
        return forbidden(res, error.message);
      }
      logger.error('Search members error', { error });
      return internalError(res, 'Failed to search members');
    }
  }
);

/**
 * Legacy: POST /branch/:id/register-member - Manual member registration (deprecated)
 * Use POST /branch/:id/manual-create instead
 */
router.post('/:id/register-member', validateBranchOwnership('id'), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const membership = await MembershipService.createMembership(
      req.params.id,
      req.body.userId,
      req.user!.userId,
      req.user!.role,
      req.body
    );
    return created(res, membership);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return badRequest(res, errorMessage);
  }
});

/**
 * GET /branch/:id/export-logs - Export access logs for the gym
 *
 * GYM_OWNER only - Branch Admin cannot access this endpoint.
 * Supports filtering by date range and log type.
 * Returns CSV or JSON format.
 */
router.get(
  '/:id/export-logs',
  gymOwnerOnly, // Explicitly block BRANCH_ADMIN
  validateBranchOwnership('id'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const startDate = req.query.startDate ? new Date(req.query.startDate as string) : undefined;
      const endDate = req.query.endDate ? new Date(req.query.endDate as string) : undefined;
      const format = (req.query.format as string) || 'json';
      const logType = req.query.logType as string | undefined;

      // Validate date range
      if (startDate && endDate && startDate > endDate) {
        return badRequest(res, 'startDate must be before endDate');
      }

      const logs = await DoorAccessService.getGymAccessLogs(
        req.params.id,
        req.user!.userId,
        req.user!.role,
        {
          limit: 10000, // Higher limit for export
          startDate,
          endDate,
        }
      );

      // Filter by log type if specified
      let filteredLogs = logs;
      if (logType) {
        filteredLogs = logs.filter(log => log.method === logType);
      }

      const exportData = filteredLogs.map(log => ({
        timestamp: log.accessTime,
        userName: log.user?.fullName || 'Unknown',
        userEmail: log.user?.email || 'Unknown',
        doorName: log.doorSystem?.name || 'Unknown',
        doorLocation: log.doorSystem?.location || '',
        method: log.method,
        granted: log.accessGranted,
        deviceInfo: log.deviceInfo || '',
      }));

      if (format === 'csv') {
        // Generate CSV with streaming for large datasets
        const csvHeaders = 'Timestamp,User Name,User Email,Door Name,Door Location,Method,Granted,Device Info\n';
        const csvRows = exportData.map(row =>
          `"${row.timestamp}","${row.userName}","${row.userEmail}","${row.doorName}","${row.doorLocation}","${row.method}","${row.granted}","${row.deviceInfo}"`
        ).join('\n');

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="access-logs-${req.params.id}-${new Date().toISOString().split('T')[0]}.csv"`);
        return res.send(csvHeaders + csvRows);
      }

      // Default: JSON format
      return success(res, {
        gymId: req.params.id,
        exportDate: new Date().toISOString(),
        filters: {
          startDate: startDate?.toISOString(),
          endDate: endDate?.toISOString(),
          logType,
        },
        totalRecords: exportData.length,
        logs: exportData,
      });
    } catch (error: unknown) {
      logger.error('Export logs error', { error });
      return internalError(res, 'Failed to export logs');
    }
  }
);

export default router;


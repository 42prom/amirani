import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { AuditLogService } from './audit.service';

const router = Router();
router.use(authenticate);

/**
 * GET /api/audit/gyms/:gymId
 * List audit logs for a gym (paginated)
 */
router.get('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { action, from, to, page } = req.query as Record<string, string>;
    const result = await AuditLogService.list(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      { action, from, to, page: page ? parseInt(page) : 1 }
    );
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

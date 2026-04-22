import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { AssignmentService } from './assignment.service';
import { Role } from '@prisma/client';

const router = Router();
router.use(authenticate);

// ─── Member: request a trainer ────────────────────────────────────────────────

/**
 * POST /api/assignment/gyms/:gymId/request
 * Member requests to be assigned to a specific trainer
 */
router.post('/gyms/:gymId/request', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { trainerId, message } = req.body;
    if (!trainerId) return res.status(400).json({ error: 'trainerId is required' });
    const result = await AssignmentService.requestTrainer(
      req.params.gymId, req.user!.userId, trainerId, message
    );
    res.status(201).json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Member: get own assignment status ────────────────────────────────────────

/**
 * GET /api/assignment/gyms/:gymId/my-status
 * Member checks their assigned trainer + any pending request
 */
router.get('/gyms/:gymId/my-status', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AssignmentService.getMyRequest(req.params.gymId, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Member: remove own assignment ────────────────────────────────────────────

/**
 * DELETE /api/assignment/gyms/:gymId/remove
 * Member removes their trainer assignment
 */
router.delete('/gyms/:gymId/remove', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AssignmentService.removeAssignment(
      req.params.gymId, req.user!.userId, req.user!.userId, req.user!.role as Role
    );
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Trainer: get pending requests ────────────────────────────────────────────

/**
 * GET /api/assignment/me/pending-requests
 * Trainer gets their pending assignment requests
 */
router.get('/me/pending-requests', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.TRAINER) {
      return res.status(403).json({ error: 'Trainer access required' });
    }
    const requests = await AssignmentService.getPendingRequests(req.user!.userId);
    res.json({ data: requests });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Trainer: approve request ─────────────────────────────────────────────────

/**
 * POST /api/assignment/requests/:requestId/approve
 */
router.post('/requests/:requestId/approve', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.TRAINER) {
      return res.status(403).json({ error: 'Trainer access required' });
    }
    const result = await AssignmentService.approveRequest(req.params.requestId, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Trainer: reject request ──────────────────────────────────────────────────

/**
 * POST /api/assignment/requests/:requestId/reject
 */
router.post('/requests/:requestId/reject', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.TRAINER) {
      return res.status(403).json({ error: 'Trainer access required' });
    }
    const result = await AssignmentService.rejectRequest(req.params.requestId, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Trainer: remove a member assignment ──────────────────────────────────────

/**
 * DELETE /api/assignment/gyms/:gymId/members/:memberId/remove
 * Trainer removes a member from their roster
 */
router.delete('/gyms/:gymId/members/:memberId/remove', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.TRAINER) {
      return res.status(403).json({ error: 'Trainer access required' });
    }
    const result = await AssignmentService.removeAssignment(
      req.params.gymId, req.params.memberId, req.user!.userId, req.user!.role as Role
    );
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Branch Manager: trainer stats ────────────────────────────────────────────

/**
 * GET /api/assignment/gyms/:gymId/trainer-stats
 * Branch manager / gym owner sees member count per trainer
 */
router.get('/gyms/:gymId/trainer-stats', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await AssignmentService.getTrainerStats(
      req.params.gymId, req.user!.userId, req.user!.role as Role, req.user!.managedGymId
    );
    res.json({ data: stats });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

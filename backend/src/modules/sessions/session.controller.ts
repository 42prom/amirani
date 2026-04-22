import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { SessionService, BookingStatus } from './session.service';
import { Role } from '@prisma/client';

const router = Router();
router.use(authenticate);

// ─── Admin / Owner routes (branch admin or above) ─────────────────────────────

/**
 * GET /api/sessions/gyms/:gymId
 * List all sessions for a gym (with booking counts)
 */
router.get('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { from, to, trainerId, status } = req.query as Record<string, string>;
    const sessions = await SessionService.listForGym(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      { from, to, trainerId, status }
    );
    res.json({ data: sessions });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /api/sessions/gyms/:gymId
 * Create a new session
 */
router.post('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { trainerId, title, description, type, startTime, endTime, maxCapacity, location, color } = req.body;
    if (!trainerId || !title || !startTime || !endTime) {
      return res.status(400).json({ error: 'trainerId, title, startTime, and endTime are required' });
    }
    const session = await SessionService.create(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      { trainerId, title, description, type: type ?? 'GROUP_CLASS', startTime, endTime, maxCapacity: maxCapacity ?? 20, location, color }
    );
    res.status(201).json({ data: session });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /api/sessions/gyms/:gymId/:id
 * Update a session (edit details or cancel)
 */
router.patch('/gyms/:gymId/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const session = await SessionService.update(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      req.body
    );
    res.json({ data: session });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /api/sessions/gyms/:gymId/:id
 */
router.delete('/gyms/:gymId/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await SessionService.deleteSession(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/sessions/gyms/:gymId/:id/bookings
 * List bookings for a session (admin)
 */
router.get('/gyms/:gymId/:id/bookings', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const bookings = await SessionService.getBookings(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: bookings });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /api/sessions/gyms/:gymId/:id/bookings/:memberId
 * Mark attendance status for a booking
 */
router.patch('/gyms/:gymId/:id/bookings/:memberId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status } = req.body;
    if (!['CONFIRMED', 'CANCELLED', 'ATTENDED', 'NO_SHOW'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    const booking = await SessionService.markAttendance(
      req.params.id,
      req.params.memberId,
      status as BookingStatus,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: booking });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/sessions/gyms/:gymId/trainers/stats
 * Trainer utilization stats
 */
router.get('/gyms/:gymId/trainers/stats', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await SessionService.getTrainerStats(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: stats });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Member routes (any authenticated user) ───────────────────────────────────

/**
 * POST /api/sessions/:id/book
 * Member books a session
 */
router.post('/:id/book', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const booking = await SessionService.bookSession(req.params.id, req.user!.userId);
    res.status(201).json({ data: booking });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /api/sessions/:id/book
 * Member cancels their booking
 */
router.delete('/:id/book', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await SessionService.cancelBooking(req.params.id, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/sessions/me/bookings
 * Member's own upcoming bookings
 */
router.get('/me/bookings', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const bookings = await SessionService.getMemberBookings(req.user!.userId);
    res.json({ data: bookings });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

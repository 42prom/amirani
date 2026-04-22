import { Router, Response } from 'express';
import { Role } from '@prisma/client';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { SupportService, TicketStatus, TicketPriority } from './support.service';

const router = Router();
router.use(authenticate);

// ─── Admin routes ─────────────────────────────────────────────────────────────

/**
 * GET /api/support/gyms/:gymId/tickets
 * Admin: list all tickets with optional status/priority filter
 */
router.get('/gyms/:gymId/tickets', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status, priority } = req.query as Record<string, string>;
    const tickets = await SupportService.listForGym(
      req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId,
      { status, priority }
    );
    res.json({ data: tickets });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/support/gyms/:gymId/stats
 */
router.get('/gyms/:gymId/stats', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await SupportService.getStats(
      req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId
    );
    res.json({ data: stats });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/support/gyms/:gymId/tickets/:id
 * Get single ticket with full message thread
 */
router.get('/gyms/:gymId/tickets/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const ticket = await SupportService.getTicket(
      req.params.id, req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId
    );
    res.json({ data: ticket });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /api/support/gyms/:gymId/tickets/:id/reply
 * Reply to a ticket (works for both admin and member)
 */
router.post('/gyms/:gymId/tickets/:id/reply', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { body } = req.body;
    if (!body?.trim()) return res.status(400).json({ error: 'body is required' });
    const message = await SupportService.reply(
      req.params.id, req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId, body
    );
    res.status(201).json({ data: message });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /api/support/gyms/:gymId/tickets/:id/status
 * Admin: update ticket status
 */
router.patch('/gyms/:gymId/tickets/:id/status', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status } = req.body;
    const valid: TicketStatus[] = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
    if (!valid.includes(status)) return res.status(400).json({ error: `status must be one of: ${valid.join(', ')}` });
    const ticket = await SupportService.updateStatus(
      req.params.id, req.params.gymId, req.user!.userId, req.user!.role, req.user!.managedGymId, status
    );
    res.json({ data: ticket });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Member routes ────────────────────────────────────────────────────────────

/**
 * GET /api/support/gyms/:gymId/my-tickets
 * Member: list their own tickets for this gym
 */
router.get('/gyms/:gymId/my-tickets', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const tickets = await SupportService.listForMember(req.user!.userId, req.params.gymId);
    res.json({ data: tickets });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /api/support/gyms/:gymId/tickets
 * Member creates a ticket
 */
router.post('/gyms/:gymId/tickets', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { subject, body, priority } = req.body;
    if (!subject?.trim() || !body?.trim()) {
      return res.status(400).json({ error: 'subject and body are required' });
    }
    const ticket = await SupportService.createTicket(
      req.params.gymId, req.user!.userId, subject, body, (priority as TicketPriority) ?? 'MEDIUM'
    );
    res.status(201).json({ data: ticket });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Trainer Conversation routes ──────────────────────────────────────────────

/**
 * POST /api/support/gyms/:gymId/trainer-conversation
 * Member opens (or retrieves existing) chat with their assigned trainer
 */
router.post('/gyms/:gymId/trainer-conversation', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { trainerId } = req.body;
    if (!trainerId) return res.status(400).json({ error: 'trainerId is required' });
    const ticket = await SupportService.openTrainerConversation(
      req.params.gymId, req.user!.userId, trainerId
    );
    res.status(200).json({ data: ticket });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/support/trainer-conversations
 * Trainer lists all their member conversations
 */
router.get('/trainer-conversations', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (req.user!.role !== Role.TRAINER) return res.status(403).json({ error: 'Trainer access required' });
    const convos = await SupportService.listTrainerConversations(req.user!.userId);
    res.json({ data: convos });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

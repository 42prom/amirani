import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { WebhookService, WEBHOOK_EVENTS } from './webhook.service';

const router = Router();
router.use(authenticate);

/**
 * GET /api/webhooks/events
 * List all supported event types
 */
router.get('/events', async (_req, res: Response) => {
  res.json({ data: WEBHOOK_EVENTS });
});

/**
 * GET /api/webhooks/gyms/:gymId
 * List webhook endpoints for a gym
 */
router.get('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const endpoints = await WebhookService.list(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: endpoints });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /api/webhooks/gyms/:gymId
 * Create a new webhook endpoint
 */
router.post('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { url, events } = req.body;
    const ep = await WebhookService.create(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      { url, events }
    );
    res.status(201).json({ data: ep });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /api/webhooks/gyms/:gymId/:id
 * Update endpoint (url, events, isActive)
 */
router.patch('/gyms/:gymId/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const ep = await WebhookService.update(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      req.body
    );
    res.json({ data: ep });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /api/webhooks/gyms/:gymId/:id
 */
router.delete('/gyms/:gymId/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await WebhookService.delete(
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
 * POST /api/webhooks/gyms/:gymId/:id/rotate-secret
 * Rotate the signing secret
 */
router.post('/gyms/:gymId/:id/rotate-secret', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const ep = await WebhookService.rotateSecret(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: ep });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /api/webhooks/gyms/:gymId/:id/deliveries
 * List delivery history for an endpoint
 */
router.get('/gyms/:gymId/:id/deliveries', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const page = req.query.page ? parseInt(req.query.page as string) : 1;
    const result = await WebhookService.getDeliveries(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      page
    );
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

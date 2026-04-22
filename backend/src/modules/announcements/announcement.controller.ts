import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { AnnouncementService } from './announcement.service';

const router = Router();
router.use(authenticate, branchAdminOrAbove);

/**
 * GET /api/announcements/gyms/:gymId
 */
router.get('/gyms/:gymId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const list = await AnnouncementService.list(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: list });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /api/announcements/gyms/:gymId
 * Publish a new announcement (saves + sends immediately)
 */
router.post('/gyms/:gymId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { title, body, imageUrl, isPinned, targetAudience, channels } = req.body;

    if (!title?.trim() || !body?.trim()) {
      return res.status(400).json({ error: 'title and body are required' });
    }
    if (!channels?.length) {
      return res.status(400).json({ error: 'At least one channel is required' });
    }

    const announcement = await AnnouncementService.publish(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      {
        title,
        body,
        imageUrl,
        isPinned: isPinned ?? false,
        targetAudience: targetAudience ?? 'ALL',
        channels,
      }
    );
    res.status(201).json({ data: announcement });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /api/announcements/gyms/:gymId/:id/pin
 * Toggle pin status
 */
router.patch('/gyms/:gymId/:id/pin', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const announcement = await AnnouncementService.togglePin(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: announcement });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /api/announcements/gyms/:gymId/:id
 */
router.delete('/gyms/:gymId/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AnnouncementService.delete(
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

export default router;

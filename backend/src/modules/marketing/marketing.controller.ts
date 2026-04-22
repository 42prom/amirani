import { Router, Response } from 'express';
import {
  authenticate,
  branchAdminOrAbove,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import { MarketingService, CampaignAudience } from './marketing.service';

const router = Router();
router.use(authenticate, branchAdminOrAbove);

/**
 * GET /api/marketing/gyms/:gymId/campaigns
 * List all campaigns for a gym
 */
router.get('/gyms/:gymId/campaigns', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const campaigns = await MarketingService.list(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: campaigns });
  } catch (err: any) {
    res.status(err.message === 'Access denied' ? 403 : 500).json({ error: err.message });
  }
});

/**
 * POST /api/marketing/gyms/:gymId/campaigns
 * Create a draft campaign
 */
router.post('/gyms/:gymId/campaigns', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const campaign = await MarketingService.create(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      req.body
    );
    res.status(201).json({ data: campaign });
  } catch (err: any) {
    res.status(err.message === 'Access denied' ? 403 : 400).json({ error: err.message });
  }
});

/**
 * GET /api/marketing/gyms/:gymId/campaigns/preview-audience
 * Preview recipient count before sending
 * Query: audience, targetPlanId?
 */
router.get('/gyms/:gymId/campaigns/preview-audience', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { audience, targetPlanId } = req.query as { audience: CampaignAudience; targetPlanId?: string };
    if (!audience) return res.status(400).json({ error: 'audience is required' });

    const preview = await MarketingService.previewAudience(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      audience,
      targetPlanId
    );
    res.json({ data: preview });
  } catch (err: any) {
    res.status(err.message === 'Access denied' ? 403 : 500).json({ error: err.message });
  }
});

/**
 * POST /api/marketing/gyms/:gymId/campaigns/:campaignId/send
 * Send a campaign now
 */
router.post('/gyms/:gymId/campaigns/:campaignId/send', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await MarketingService.send(
      req.params.campaignId,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: result });
  } catch (err: any) {
    const status = err.message === 'Access denied' ? 403 : err.message === 'Campaign not found' ? 404 : 400;
    res.status(status).json({ error: err.message });
  }
});

/**
 * DELETE /api/marketing/gyms/:gymId/campaigns/:campaignId
 * Delete a draft campaign
 */
router.delete('/gyms/:gymId/campaigns/:campaignId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await MarketingService.delete(
      req.params.campaignId,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.status(204).send();
  } catch (err: any) {
    const status = err.message === 'Access denied' ? 403 : err.message === 'Campaign not found' ? 404 : 400;
    res.status(status).json({ error: err.message });
  }
});

export default router;

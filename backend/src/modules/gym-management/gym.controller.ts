import { Router, Response } from 'express';
import { GymService } from './gym.service';
import { authenticate } from '../../middleware/auth.middleware';
import {
  gymOwnerOrAbove,
  branchAdminOrAbove,
  AuthenticatedRequest
} from '../../middleware/auth.middleware';
import { serverError } from '../../utils/response';

const router = Router();

/**
 * GET /gyms/:id/registration-config
 * Public endpoint — member scans QR and needs to know which fields to fill.
 * returns { gymId, gymName, requirements }
 */
router.get('/public/registration-config/:gymId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId } = req.params;
    const result = await GymService.getPublicRegistrationInfo(gymId);
    res.json({ data: result });
  } catch (error: any) {
    if (error.message === 'Gym not found') return res.status(404).json({ error: error.message });
    res.status(400).json({ error: error.message });
  }
});

/**
 * POST /gyms/:id/self-register
 * Public endpoint — member scans QR and self-registers with their data.
 */
router.post('/:id/self-register', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { code, ...data } = req.body;
    if (!code) return res.status(400).json({ error: 'Registration code is required' });
    const result = await GymService.selfRegister(req.params.id, code, data);
    res.status(201).json({ data: result });
  } catch (error: any) {
    if (error.message === 'Gym not found') return res.status(404).json({ error: error.message });
    res.status(400).json({ error: error.message });
  }
});

// All routes below require authentication
router.use(authenticate);

/**
 * GET /gyms/:id/registration-qr
 * Returns the registration code and QR content for a gym.
 * Restricted to owners or branch admins.
 */
router.get('/:id/registration-qr', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.params.id;
    const result = await GymService.getRegistrationQr(
      gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: result });
  } catch (error: any) {
    if (error.message === 'Gym not found') return res.status(404).json({ error: error.message });
    if (error.message === 'Access denied') return res.status(403).json({ error: error.message });
    res.status(400).json({ error: error.message });
  }
});

/**
 * GET /gyms/:id/qr-token
 * Returns a signed, time-limited QR payload for gym entry.
 * Token is HMAC-SHA256 signed with the gym's qrSecret, valid for 24 h.
 * Mobile encodes this as amirani://checkin?gymId=...&token=<signed-payload>
 * and the check-in endpoint verifies signature + expiry before granting access.
 */
router.get('/:id/qr-token', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.params.id;
    const { GymQrService } = await import('../gym-entry/gym-qr.service');

    const { qrData, expiresAt } = await GymQrService.generate(gymId, 'DAILY_CHECKIN');
    const token = `amirani://checkin?gymId=${gymId}&token=${encodeURIComponent(qrData)}`;
    res.json({ data: { token, expiresAt } });
  } catch (error: any) {
    if (error.status === 404) {
      return res.status(404).json({ error: 'Gym not found or inactive' });
    }
    res.status(500).json({ error: 'Failed to generate entry QR' });
  }
});

/**
 * GET /gyms
 * Returns all gyms for Super Admins or owned gyms for Gym Owners.
 */
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gyms = await GymService.findAll(
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: gyms });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to retrieve gyms' });
  }
});

/**
 * POST /gyms
 * Super Admin only: create a new gym.
 */
router.post('/', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await GymService.create(req.body);
    res.status(201).json({ data: gym });
  } catch (error: any) {
    res.status(400).json({ error: error.message });
  }
});

/**
 * GET /gyms/:id
 * Get full gym details.
 */
router.get('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await GymService.findById(
      req.params.id,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: gym });
  } catch (error: any) {
    if (error.message === 'Gym not found') return res.status(404).json({ error: 'Gym not found' });
    if (error.message === 'Access denied') return res.status(403).json({ error: 'Access denied' });
    res.status(500).json({ error: 'Failed to retrieve gym' });
  }
});

/**
 * PATCH /gyms/:id
 * Update gym details.
 */
router.patch('/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await GymService.update(
      req.params.id,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    res.json({ data: gym });
  } catch (error: any) {
    if (error.message === 'Gym not found') return res.status(404).json({ error: 'Gym not found' });
    if (error.message === 'Access denied') return res.status(403).json({ error: 'Access denied' });
    res.status(400).json({ error: error.message });
  }
});

/**
 * GET /gyms/:id/stats
 * Get branch-specific statistics.
 */
router.get('/:id/stats', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await GymService.getStats(
      req.params.id,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json(stats);
  } catch (error: any) {
    if (error.message === 'Gym not found') {
      return res.status(404).json({ error: error.message });
    }
    if (error.message === 'Access denied') {
      return res.status(403).json({ error: error.message });
    }
    serverError(res, error);
  }
});

export default router;

import { Router, Response } from 'express';
import { NotificationService, NotificationError } from './notification.service';
import {
  authenticate,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import {
  success,
  created,
  badRequest,
  internalError,
} from '../../lib/response';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

const router = Router();

// All notification routes require authentication
router.use(authenticate);

/**
 * GET /notifications
 * Get user's notifications
 */
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { unreadOnly, type, limit, offset } = req.query;

    const result = await NotificationService.getUserNotifications(req.user!.userId, {
      unreadOnly: unreadOnly === 'true',
      type: type as any,
      limit: limit ? parseInt(limit as string) : undefined,
      offset: offset ? parseInt(offset as string) : undefined,
    });

    success(res, result);
  } catch (err) {
    logger.error('Get notifications error', { err });
    internalError(res);
  }
});

/**
 * POST /notifications/:id/read
 * Mark a notification as read
 */
router.post('/:id/read', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await NotificationService.markAsRead(req.params.id, req.user!.userId);
    success(res, { marked: true });
  } catch (err) {
    logger.error('Mark as read error', { err });
    internalError(res);
  }
});

/**
 * POST /notifications/read-all
 * Mark all notifications as read
 */
router.post('/read-all', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await NotificationService.markAllAsRead(req.user!.userId);
    success(res, { marked: result.count });
  } catch (err) {
    logger.error('Mark all as read error', { err });
    internalError(res);
  }
});

/**
 * GET /notifications/preferences
 * Get notification preferences
 */
router.get('/preferences', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const preferences = await NotificationService.getPreferences(req.user!.userId);
    success(res, preferences);
  } catch (err) {
    logger.error('Get preferences error', { err });
    internalError(res);
  }
});

/**
 * PATCH /notifications/preferences
 * Update notification preferences
 */
router.patch('/preferences', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const preferences = await NotificationService.updatePreferences(
      req.user!.userId,
      req.body
    );
    success(res, preferences);
  } catch (err) {
    logger.error('Update preferences error', { err });
    internalError(res);
  }
});

/**
 * POST /notifications/register-device
 * Register FCM/APNS token for push notifications
 * Body: { fcmToken?: string, apnsToken?: string, platform?: 'ios'|'android', deviceName?: string }
 */
router.post('/register-device', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { fcmToken, apnsToken, platform, deviceName } = req.body;

    if (!fcmToken && !apnsToken) {
      return badRequest(res, 'Either fcmToken or apnsToken is required');
    }

    await NotificationService.updatePreferences(req.user!.userId, {
      fcmToken,
      apnsToken,
    });

    // Also upsert into UserDevice for multi-device support
    if (fcmToken) {
      await prisma.userDevice.upsert({
        where: { fcmToken },
        update: {
          userId: req.user!.userId,
          platform: platform ?? null,
          deviceName: deviceName ?? null,
          lastActiveAt: new Date(),
        },
        create: {
          userId: req.user!.userId,
          fcmToken,
          platform: platform ?? null,
          deviceName: deviceName ?? null,
        },
      });
    }

    success(res, { registered: true });
  } catch (err) {
    logger.error('Register device error', { err });
    internalError(res);
  }
});

/**
 * POST /notifications/test
 * Send a test notification (development only)
 */
router.post('/test', async (req: AuthenticatedRequest, res: Response) => {
  try {
    if (process.env.NODE_ENV === 'production') {
      return badRequest(res, 'Test notifications disabled in production');
    }

    const { title, body, type } = req.body;

    const result = await NotificationService.send({
      userId: req.user!.userId,
      type: type || 'SYSTEM',
      title: title || 'Test Notification',
      body: body || 'This is a test notification from Amirani.',
      channels: ['IN_APP', 'PUSH'],
    });

    success(res, result);
  } catch (err) {
    if (err instanceof NotificationError) {
      return badRequest(res, err.message);
    }
    logger.error('Test notification error', { err });
    internalError(res);
  }
});

export default router;

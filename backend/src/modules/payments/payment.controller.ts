import { Router, Response, Request } from 'express';
import { createHmac, timingSafeEqual } from 'crypto';
import {
  PaymentService,
  PaymentError,
  PaymentNotFoundError,
} from './payment.service';
import logger from '../../lib/logger';
import { PaymentStatus } from '@prisma/client';
import {
  authenticate,
  gymOwnerOrAbove,
  superAdminOnly,
  validateBranchOwnership,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import {
  success,
  created,
  notFound,
  badRequest,
  internalError,
  serverError,
} from '../../utils/response';
import config from '../../config/env';

export function verifyStripeSignature(rawBody: Buffer, signatureHeader: string, secret: string): boolean {
  const parts = signatureHeader.split(',');
  const tPart = parts.find(p => p.startsWith('t='));
  const v1Parts = parts.filter(p => p.startsWith('v1='));
  if (!tPart || v1Parts.length === 0) return false;
  const timestamp = tPart.slice(2);
  const signedPayload = `${timestamp}.${rawBody.toString('utf8')}`;
  const expected = createHmac('sha256', secret).update(signedPayload).digest('hex');
  return v1Parts.some(p => {
    try {
      return timingSafeEqual(Buffer.from(p.slice(3), 'hex'), Buffer.from(expected, 'hex'));
    } catch { return false; }
  });
}

const router = Router();

// ─── Public Webhook Route ────────────────────────────────────────────────────

/**
 * POST /payments/webhook
 * Stripe webhook handler (no auth required, uses Stripe signature)
 */
router.post('/webhook', async (req: Request, res: Response) => {
  try {
    const webhookSecret = config.stripe.webhookSecret;
    const sig = req.headers['stripe-signature'] as string | undefined;

    let event: any;

    if (webhookSecret) {
      if (!sig) {
        return badRequest(res, 'Missing Stripe-Signature header');
      }
      const rawBody = req.body as Buffer;
      if (!verifyStripeSignature(rawBody, sig, webhookSecret)) {
        logger.warn('[Stripe] Webhook signature verification failed', { sig });
        return badRequest(res, 'Webhook signature verification failed');
      }
      event = JSON.parse(rawBody.toString('utf8'));
    } else {
      // STRIPE_WEBHOOK_SECRET not configured — accept without verification (development only)
      event = req.body;
    }

    const result = await PaymentService.handleWebhook(event);
    success(res, result);
  } catch (err: any) {
    logger.error('[Stripe] Webhook processing error', { err });
    serverError(res, err);
  }
});

// ─── Authenticated Routes ────────────────────────────────────────────────────

router.use(authenticate);

/**
 * POST /payments/create-intent
 * Create a payment intent for a one-time payment
 */
router.post('/create-intent', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { amount, currency, membershipId, gymId, method, description } = req.body;

    if (!amount || !method) {
      return badRequest(res, 'Amount and payment method are required');
    }

    const result = await PaymentService.createPaymentIntent({
      userId: req.user!.userId,
      amount,
      currency,
      membershipId,
      gymId,
      method,
      description,
    });

    created(res, result);
  } catch (err) {
    if (err instanceof PaymentError) {
      return badRequest(res, err.message);
    }
    if (err instanceof PaymentNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error('Create payment intent error', { err });
    internalError(res);
  }
});

/**
 * POST /payments/subscribe
 * Purchase a gym subscription
 */
router.post('/subscribe', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { planId, gymId, paymentMethodId, autoRenew } = req.body;

    if (!planId || !gymId || !paymentMethodId) {
      return badRequest(res, 'planId, gymId, and paymentMethodId are required');
    }

    const result = await PaymentService.purchaseSubscription({
      userId: req.user!.userId,
      planId,
      gymId,
      paymentMethodId,
      autoRenew,
    });

    created(res, result);
  } catch (err) {
    if (err instanceof PaymentError) {
      return badRequest(res, err.message);
    }
    if (err instanceof PaymentNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error('Subscribe error', { err });
    internalError(res);
  }
});

/**
 * GET /payments/history
 * Get user's payment history
 */
router.get('/history', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { status, limit, offset } = req.query;

    const result = await PaymentService.getUserPayments(req.user!.userId, {
      status: status as PaymentStatus | undefined,
      limit: limit ? parseInt(limit as string) : undefined,
      offset: offset ? parseInt(offset as string) : undefined,
    });

    success(res, result);
  } catch (err) {
    logger.error('Get payment history error', { err });
    internalError(res);
  }
});

/**
 * POST /payments/subscriptions/:id/cancel
 * Cancel a subscription
 */
router.post('/subscriptions/:id/cancel', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const membership = await PaymentService.cancelSubscription(
      req.params.id,
      req.user!.userId
    );
    success(res, membership);
  } catch (err) {
    if (err instanceof PaymentNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error('Cancel subscription error', { err });
    internalError(res);
  }
});

// ─── Admin Routes ────────────────────────────────────────────────────────────

/**
 * GET /payments/gyms/:gymId/revenue
 * Get gym revenue statistics (Gym Owner or Super Admin)
 */
router.get(
  '/gyms/:gymId/revenue',
  gymOwnerOrAbove,
  validateBranchOwnership('gymId'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const stats = await PaymentService.getGymRevenueStats(req.params.gymId);
      success(res, stats);
    } catch (err) {
      logger.error('Get revenue stats error', { err });
      internalError(res);
    }
  }
);

/**
 * POST /payments/process-expiring
 * Manually trigger expiring subscription processing (Super Admin only).
 */
router.post('/process-expiring', authenticate, superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await PaymentService.processExpiringSubscriptions();
    success(res, result);
  } catch (err) {
    logger.error('Process expiring subscriptions error', { err });
    internalError(res);
  }
});

export default router;


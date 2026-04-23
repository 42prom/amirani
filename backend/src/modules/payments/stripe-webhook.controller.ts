import { Router, Request, Response } from 'express';
import Stripe from 'stripe';
import { PaymentService } from '../payments/payment.service';
import config from '../../config/env';
import logger from '../../lib/logger';
import prisma from '../../lib/prisma';

const router = Router();
const stripe = new Stripe(config.stripe.secretKey as string, {
  apiVersion: '2025-01-27.acacia' as any,
});

// ─── Idempotency Helper ───────────────────────────────────────────────────────

/**
 * Returns true if this Stripe event ID has already been processed.
 * Stores the event ID with a 7-day TTL to handle Stripe's retry window.
 */
async function isAlreadyProcessed(stripeEventId: string): Promise<boolean> {
  const existing = await (prisma as any).processedWebhookEvent
    .findUnique({ where: { stripeEventId } })
    .catch(() => null); // table may not exist yet on fresh installs
  return existing !== null && existing !== undefined;
}

async function markProcessed(stripeEventId: string, eventType: string): Promise<void> {
  await (prisma as any).processedWebhookEvent
    .create({ data: { stripeEventId, eventType } })
    .catch(() => {}); // non-fatal — worst case we process twice (idempotent handlers)
}

// ─── Webhook Endpoint ─────────────────────────────────────────────────────────

/**
 * POST /api/payments/webhook
 * Receives Stripe webhook events. Mounted with express.raw() to preserve body.
 */
router.post('/', async (req: Request, res: Response) => {
  const sigHeader = req.headers['stripe-signature'] as string | undefined;
  const webhookSecret = config.stripe.webhookSecret;

  // ── 1. Security Gate ───────────────────────────────────────────────────────
  if (!webhookSecret) {
    if (config.isDevelopment) {
      logger.warn('[Stripe Webhook] STRIPE_WEBHOOK_SECRET not set — skipping verification (dev mode ONLY)');
      const rawEvent = req.body ? JSON.parse(req.body.toString()) : {};
      await PaymentService.handleWebhook(rawEvent).catch((err) =>
        logger.error('[Stripe Webhook] Handler error', { err }),
      );
      return res.json({ received: true });
    } else {
      logger.error('[Stripe Webhook] CRITICAL: STRIPE_WEBHOOK_SECRET missing in production!');
      return res.status(500).json({ error: 'Webhook configuration error' });
    }
  }

  if (!sigHeader) {
    logger.warn('[Stripe Webhook] Request missing Stripe-Signature header — rejected');
    return res.status(400).json({ error: 'Missing Stripe-Signature header' });
  }

  // ── 2. Signature verification ──────────────────────────────────────────────
  let event: any;
  try {
    event = stripe.webhooks.constructEvent(
      req.body as Buffer,
      sigHeader,
      webhookSecret
    );
  } catch (err: any) {
    logger.warn('[Stripe Webhook] Signature verification failed', { reason: err.message });
    return res.status(400).json({ error: `Webhook Error: ${err.message}` });
  }

  // ── 3. Idempotency — skip already-processed events ─────────────────────────
  if (await isAlreadyProcessed(event.id)) {
    logger.info('[Stripe Webhook] Duplicate event — skipping', { eventId: event.id, type: event.type });
    return res.json({ received: true });
  }

  // ── 4. Dispatch to PaymentService ──────────────────────────────────────────
  try {
    await PaymentService.handleWebhook(event);
    await markProcessed(event.id, event.type);
    logger.info('[Stripe Webhook] Processed', { eventId: event.id, type: event.type });
    return res.json({ received: true });
  } catch (err: any) {
    logger.error('[Stripe Webhook] Processing error', { eventId: event.id, type: event.type, err: err.message });
    // Return 200 to prevent Stripe retrying an event that will always fail.
    return res.status(200).json({ received: true, warning: 'Event logged but handler failed' });
  }
});

export default router;

/**
 * Stripe Webhook Handler
 *
 * Mounted at POST /api/payments/webhook with express.raw({ type: 'application/json' })
 * so that the raw body is preserved for HMAC signature verification.
 *
 * When the Stripe SDK is added (npm install stripe), swap the manual HMAC
 * verification below with:
 *   const event = stripe.webhooks.constructEvent(req.body, sig, secret);
 */
import { Router, Request, Response } from 'express';
import crypto from 'crypto';
import { PaymentService } from '../payments/payment.service';
import config from '../../config/env';
import logger from '../../lib/logger';
import prisma from '../../lib/prisma';

const router = Router();

// ─── HMAC Signature Verification ─────────────────────────────────────────────

/**
 * Verifies the Stripe-Signature header against the raw body.
 * Stripe signs payloads as: `t=<timestamp>,v1=<hmac_sha256>`
 * We verify by computing our own HMAC and doing a constant-time comparison.
 *
 * Returns the parsed event object on success, throws on failure.
 */
function verifyStripeSignature(
  rawBody: Buffer,
  sigHeader: string,
  secret: string,
): { id: string; type: string; data: { object: any }; created: number } {
  const parts = Object.fromEntries(
    sigHeader.split(',').map((part) => {
      const [key, ...rest] = part.split('=');
      return [key, rest.join('=')];
    }),
  );

  const timestamp = parts['t'];
  const v1Sig = parts['v1'];

  if (!timestamp || !v1Sig) {
    throw new Error('Malformed Stripe-Signature header');
  }

  // Reject events older than 5 minutes to prevent replay attacks
  const tolerance = 5 * 60; // seconds
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp, 10)) > tolerance) {
    throw new Error('Stripe webhook timestamp is too old (replay attack protection)');
  }

  // Compute expected HMAC: HMAC_SHA256(timestamp + '.' + rawBody, webhookSecret)
  const signedPayload = `${timestamp}.${rawBody.toString('utf8')}`;
  const expected = crypto
    .createHmac('sha256', secret)
    .update(signedPayload, 'utf8')
    .digest('hex');

  // Constant-time comparison to prevent timing attacks
  const expectedBuf = Buffer.from(expected, 'hex');
  const actualBuf = Buffer.from(v1Sig, 'hex');

  if (
    expectedBuf.length !== actualBuf.length ||
    !crypto.timingSafeEqual(expectedBuf, actualBuf)
  ) {
    throw new Error('Stripe webhook signature verification failed');
  }

  return JSON.parse(rawBody.toString('utf8'));
}

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

  // ── 1. Reject if no webhook secret configured ──────────────────────────────
  const webhookSecret = config.stripe.webhookSecret;
  if (!webhookSecret) {
    // In development without Stripe config — log and accept (dev convenience).
    // In production this should never happen; env validation should catch it.
    logger.warn('[Stripe Webhook] STRIPE_WEBHOOK_SECRET not set — skipping verification (dev mode)');
    const rawEvent = req.body ? JSON.parse(req.body.toString()) : {};
    await PaymentService.handleWebhook(rawEvent).catch((err) =>
      logger.error('[Stripe Webhook] Handler error', { err }),
    );
    return res.json({ received: true });
  }

  // ── 2. Signature verification ──────────────────────────────────────────────
  if (!sigHeader) {
    logger.warn('[Stripe Webhook] Request missing Stripe-Signature header — rejected');
    return res.status(400).json({ error: 'Missing Stripe-Signature header' });
  }

  let event: { id: string; type: string; data: { object: any }; created: number };
  try {
    event = verifyStripeSignature(req.body as Buffer, sigHeader, webhookSecret);
  } catch (err: any) {
    logger.warn('[Stripe Webhook] Signature verification failed', { reason: err.message });
    return res.status(400).json({ error: 'Webhook signature verification failed' });
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
    // Log the error for investigation. Change to 500 only for transient errors.
    return res.status(200).json({ received: true, warning: 'Event logged but handler failed' });
  }
});

export default router;

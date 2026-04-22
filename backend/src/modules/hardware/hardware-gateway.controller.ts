/**
 * Hardware Gateway API
 *
 * Two audiences:
 *   A) Admin/Staff  — manage gateways and card credentials
 *   B) Hardware     — gateways authenticate with apiKey header, not JWT
 *
 * Admin routes: /hardware/...   (require JWT + branchAdminOrAbove)
 * Gateway routes: /hardware/gw/... (require X-Gateway-Key header)
 */
import { Router, Request, Response } from 'express';
import {
  authenticate,
  branchAdminOrAbove,
  validateBranchOwnership,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import { success, badRequest, forbidden, notFound, internalError } from '../../lib/response';
import logger from '../../lib/logger';
import * as GW from './hardware-gateway.service';

const router = Router();

// ─── Middleware: Gateway API Key auth ─────────────────────────────────────────

function gatewayAuth(req: Request, res: Response, next: Function) {
  const apiKey = (req.headers['x-gateway-key'] as string) || req.body?.apiKey;
  if (!apiKey) return res.status(401).json({ success: false, error: { message: 'X-Gateway-Key required' } });
  (req as any).gatewayApiKey = apiKey;
  next();
}

// ═══════════════════════════════════════════════════════════════════════════════
// ADMIN ROUTES (JWT protected)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * POST /hardware/gateways
 * Register a new hardware gateway for a gym.
 * Body: { gymId, name, location?, protocol?, config? }
 */
router.post('/gateways', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, name, location, protocol, config } = req.body;
    if (!gymId || !name) return badRequest(res, 'gymId and name are required');

    const gateway = await GW.registerGateway({ gymId, name, location, protocol, config });
    return success(res, gateway);
  } catch (err) {
    logger.error('[HW] register gateway error', { err });
    internalError(res);
  }
});

/**
 * GET /hardware/gateways?gymId=
 * List all gateways for a gym.
 */
router.get('/gateways', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.query.gymId as string;
    if (!gymId) return badRequest(res, 'gymId is required');
    const gateways = await GW.getGatewaysForGym(gymId);
    return success(res, gateways);
  } catch (err) {
    logger.error('[HW] list gateways error', { err });
    internalError(res);
  }
});

/**
 * DELETE /hardware/gateways/:id
 * Remove a gateway and deactivate its linked door system.
 */
router.delete('/gateways/:id', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.query.gymId as string;
    if (!gymId) return badRequest(res, 'gymId is required');
    await GW.deleteGateway(req.params.id, gymId);
    return success(res, { deleted: true });
  } catch (err) {
    logger.error('[HW] delete gateway error', { err });
    internalError(res);
  }
});

/**
 * GET /hardware/stats?gymId=
 * Access statistics: total scans, granted/denied breakdown, peak hours, top members.
 */
router.get('/stats', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.query.gymId as string;
    if (!gymId) return badRequest(res, 'gymId is required');
    const stats = await GW.getAccessStats(gymId);
    return success(res, stats);
  } catch (err) {
    logger.error('[HW] stats error', { err });
    internalError(res);
  }
});

/**
 * POST /hardware/commands/unlock
 * Manually push an unlock command to a gateway (e.g., from admin dashboard).
 * Body: { gatewayId, doorId?, durationMs? }
 */
router.post('/commands/unlock', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gatewayId, doorId, durationMs } = req.body;
    if (!gatewayId) return badRequest(res, 'gatewayId is required');

    const cmd = await GW.pushUnlockCommand(gatewayId, doorId, req.user!.userId, durationMs);
    return success(res, cmd);
  } catch (err) {
    logger.error('[HW] push unlock error', { err });
    internalError(res);
  }
});

// ─── Card Credential Management ───────────────────────────────────────────────

/**
 * POST /hardware/cards
 * Enroll a physical card or phone HCE credential for a member.
 * Body: { gymId, userId, cardUid, cardType, facilityCode?, cardNumber?, label? }
 *
 * Security rules:
 *  - cardUid must be a valid hex string (4, 7, or 10 byte NFC UIDs = 8/14/20 hex chars).
 *    PHONE_HCE credentials may be up to 32 hex chars (128-bit random token).
 *  - userId must refer to a user with an active membership in gymId — prevents
 *    enrolling credentials for non-members or members of other gyms.
 */
router.post('/cards', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, userId, cardUid, cardType, facilityCode, cardNumber, label } = req.body;
    if (!gymId || !userId || !cardUid) return badRequest(res, 'gymId, userId, and cardUid are required');

    // ── 1. Hex format validation ──────────────────────────────────────────────
    // Physical NFC UIDs: 8, 14, or 20 hex chars (4, 7, or 10 bytes).
    // PHONE_HCE tokens: up to 32 hex chars (128-bit random token from the phone's HCE stack).
    const resolvedType = cardType ?? 'NFC_MIFARE';
    const maxHexLen = resolvedType === 'PHONE_HCE' ? 32 : 20;
    const validHex = /^[0-9A-Fa-f]+$/;
    const normalizedUid = cardUid.replace(/[:\s-]/g, '');
    if (!validHex.test(normalizedUid) || normalizedUid.length < 8 || normalizedUid.length > maxHexLen) {
      return badRequest(res, `cardUid must be a hex string (8–${maxHexLen} chars, colons/spaces allowed)`);
    }

    // ── 2. Verify target user has an active membership in this gym ────────────
    // Prevents enrolling credentials for non-members or members of sibling gyms.
    const membership = await GW.getActiveMembership(userId, gymId);
    if (!membership) {
      return badRequest(res, 'Target user has no active membership in this gym');
    }

    const cred = await GW.enrollCard({ gymId, userId, cardUid, cardType: resolvedType, facilityCode, cardNumber, label });
    return success(res, cred);
  } catch (err: any) {
    if (err.status === 409) return res.status(409).json({ success: false, error: { message: err.message } });
    logger.error('[HW] enroll card error', { err });
    internalError(res);
  }
});

/**
 * GET /hardware/cards?gymId=&userId=
 * List cards — for a specific user (userId param) or entire gym.
 */
router.get('/cards', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, userId } = req.query as { gymId?: string; userId?: string };
    if (!gymId) return badRequest(res, 'gymId is required');

    const cards = userId
      ? await GW.getCardsForUser(userId, gymId)
      : await GW.getCardsForGym(gymId);

    return success(res, cards);
  } catch (err) {
    logger.error('[HW] list cards error', { err });
    internalError(res);
  }
});

/**
 * DELETE /hardware/cards/:id
 * Deactivate a card credential.
 */
router.delete('/cards/:id', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymId = req.query.gymId as string;
    if (!gymId) return badRequest(res, 'gymId is required');
    await GW.revokeCard(req.params.id, gymId);
    return success(res, { revoked: true });
  } catch (err) {
    logger.error('[HW] revoke card error', { err });
    internalError(res);
  }
});

// ═══════════════════════════════════════════════════════════════════════════════
// GATEWAY ROUTES (X-Gateway-Key auth — called by hardware devices)
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * POST /hardware/gw/heartbeat
 * Gateway sends heartbeat every 30s to report online status.
 */
router.post('/gw/heartbeat', gatewayAuth, async (req: Request, res: Response) => {
  try {
    const gw = await GW.gatewayHeartbeat((req as any).gatewayApiKey);
    return success(res, { online: true, gatewayId: gw.id, serverTime: new Date().toISOString() });
  } catch (err) {
    return res.status(401).json({ success: false, error: { message: 'Invalid gateway key' } });
  }
});

/**
 * POST /hardware/gw/validate
 * MAIN ENTRY POINT: Gateway calls this when a card or phone is presented.
 *
 * Body: { cardUid: string, doorId?: string, deviceInfo?: string }
 * Response: { granted, reason?, memberName?, planName?, daysRemaining? }
 *
 * After granting, backend also pushes UNLOCK command via WebSocket.
 * The gateway should trigger the relay immediately on "granted: true" response
 * (don't wait for WebSocket — REST response is the primary signal).
 */
router.post('/gw/validate', gatewayAuth, async (req: Request, res: Response) => {
  try {
    const { cardUid, doorId, deviceInfo } = req.body;
    if (!cardUid) return badRequest(res, 'cardUid is required');

    const result = await GW.validateCardScan({
      apiKey: (req as any).gatewayApiKey,
      cardUid,
      doorId,
      deviceInfo,
    });

    // Always return 200 — the hardware acts on granted:true/false
    return success(res, result);
  } catch (err) {
    logger.error('[HW] gw/validate error', { err });
    return success(res, { granted: false, reason: 'Internal error' });
  }
});

/**
 * GET /hardware/gw/commands
 * Gateway polls for pending commands (fallback when WebSocket not connected).
 * After processing each command, gateway calls /gw/commands/:id/ack
 */
router.get('/gw/commands', gatewayAuth, async (req: Request, res: Response) => {
  try {
    const commands = await GW.pollCommands((req as any).gatewayApiKey);
    return success(res, commands);
  } catch (err: any) {
    if (err.status === 401) return res.status(401).json({ success: false, error: { message: err.message } });
    logger.error('[HW] poll commands error', { err });
    internalError(res);
  }
});

/**
 * POST /hardware/gw/commands/:id/ack
 * Gateway confirms a command was executed (or failed).
 * Body: { success: boolean }
 */
router.post('/gw/commands/:id/ack', gatewayAuth, async (req: Request, res: Response) => {
  try {
    const ok = req.body?.success !== false;
    const cmd = await GW.acknowledgeCommand(req.params.id, (req as any).gatewayApiKey, ok);
    return success(res, { acknowledged: true, status: cmd.status });
  } catch (err: any) {
    if (err.status === 401) return res.status(401).json({ success: false, error: { message: err.message } });
    logger.error('[HW] ack command error', { err });
    internalError(res);
  }
});

export default router;


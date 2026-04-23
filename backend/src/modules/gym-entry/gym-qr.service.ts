import crypto from 'crypto';
import prisma from '../../lib/prisma';

// ─── QR payload TTLs ─────────────────────────────────────────────────────────

const TTL_MS = {
  GYM_JOIN:      60 * 60 * 1000,  // 1 hour
  DAILY_CHECKIN: 60 * 1000,       // 60 seconds (Hardened)
} as const;

// ─── Types ────────────────────────────────────────────────────────────────────

export type QrType = 'GYM_JOIN' | 'DAILY_CHECKIN';

export interface QrPayload {
  gymId: string;
  type: QrType;
  nonce: string;
  iat: number;   // issued-at unix ms
  exp: number;   // expiry unix ms
}

export interface QrVerifyResult {
  valid: boolean;
  reason?: string;
  gymId?: string;
  type?: QrType;
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class GymQrService {

  /**
   * Generate a new signed QR payload for a gym.
   * The gym's qrSecret is used for HMAC-SHA256 signing.
   * If the gym has no qrSecret, one is auto-assigned.
   */
  static async generate(gymId: string, type: QrType): Promise<{ qrData: string; expiresAt: Date }> {
    // Ensure gym exists and get/assign qrSecret
    const gym = await prisma.gym.findUnique({
      where: { id: gymId, isActive: true },
      select: { id: true, qrSecret: true },
    });

    if (!gym) throw Object.assign(new Error('Gym not found or inactive'), { status: 404 });

    let secret = gym.qrSecret;
    if (!secret) {
      secret = crypto.randomBytes(32).toString('hex');
      await prisma.gym.update({ where: { id: gymId }, data: { qrSecret: secret } });
    }

    const nonce = crypto.randomUUID();
    const now   = Date.now();
    const exp   = now + TTL_MS[type];

    const payload: QrPayload = { gymId, type, nonce, iat: now, exp };
    const signature = this.sign(payload, secret);
    const qrData    = this.encode(payload, signature);

    // Persist nonce to DB for replay prevention
    await prisma.qrNonce.create({
      data: {
        nonce,
        gymId,
        type: type as any,
        expiresAt: new Date(exp),
      },
    });

    return { qrData, expiresAt: new Date(exp) };
  }

  /**
   * Verify a scanned QR payload.
   * Checks: valid format → valid signature → not expired → (optionally) nonce not used.
   *
   * @param singleUse - true (default) for registration QRs: marks nonce consumed so
   *   the same code cannot be scanned twice. Set false for venue check-in QRs where
   *   the same QR is scanned by many members — replay is prevented per-user by the
   *   anti-passback Attendance check in the check-in controller instead.
   */
  static async verify(
    qrData: string,
    consumedByUserId: string,
    options: { singleUse?: boolean } = {},
  ): Promise<QrVerifyResult> {
    const singleUse = options.singleUse ?? true;
    // 1. Decode
    let payload: QrPayload;
    let signature: string;

    try {
      const decoded = this.decode(qrData);
      payload   = decoded.payload;
      signature = decoded.signature;
    } catch {
      return { valid: false, reason: 'Invalid QR format' };
    }

    // 2. Expiry check (fast — no DB hit)
    if (Date.now() > payload.exp) {
      return { valid: false, reason: 'QR code has expired. Please ask for a new one.' };
    }

    // 3. Gym secret lookup + signature check
    const gym = await prisma.gym.findUnique({
      where: { id: payload.gymId, isActive: true },
      select: { qrSecret: true },
    });

    if (!gym?.qrSecret) {
      return { valid: false, reason: 'Gym not found or QR signing not configured' };
    }

    const expectedSig = this.sign(payload, gym.qrSecret);
    if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSig))) {
      return { valid: false, reason: 'Invalid QR signature' };
    }

    // 4. Nonce check
    // singleUse=true (registration QRs): enforce one-time use — reject if already consumed.
    // singleUse=false (venue check-in QRs): verify nonce exists (proves it was issued by
    // us) but allow reuse; per-user replay is handled by anti-passback in the controller.
    const nonceRecord = await prisma.qrNonce.findUnique({ where: { nonce: payload.nonce } });

    if (!nonceRecord) {
      // Nonce not in DB — expired and cleaned up, or forged payload
      return { valid: false, reason: 'QR code is no longer valid' };
    }

    if (singleUse) {
      if (nonceRecord.usedAt !== null) {
        return { valid: false, reason: 'QR code has already been used' };
      }
      // Mark as consumed
      await prisma.qrNonce.update({
        where: { nonce: payload.nonce },
        data: { usedAt: new Date(), usedBy: consumedByUserId },
      });
    }

    return {
      valid: true,
      gymId: payload.gymId,
      type: payload.type,
    };
  }

  /**
   * Cleanup expired nonces — run as a daily cron job.
   */
  static async cleanupExpiredNonces(): Promise<number> {
    const result = await prisma.qrNonce.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });
    return result.count;
  }

  // ─── Crypto helpers ───────────────────────────────────────────────────────

  private static sign(payload: QrPayload, secret: string): string {
    const data = JSON.stringify({ gymId: payload.gymId, type: payload.type, nonce: payload.nonce, iat: payload.iat, exp: payload.exp });
    return crypto.createHmac('sha256', secret).update(data).digest('hex');
  }

  private static encode(payload: QrPayload, signature: string): string {
    return Buffer.from(JSON.stringify({ ...payload, sig: signature })).toString('base64url');
  }

  private static decode(qrData: string): { payload: QrPayload; signature: string } {
    const raw  = JSON.parse(Buffer.from(qrData, 'base64url').toString('utf8'));
    const { sig, ...rest } = raw;
    return { payload: rest as QrPayload, signature: sig };
  }
}

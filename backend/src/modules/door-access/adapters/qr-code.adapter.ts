import { IDoorAdapter, DoorAdapterConfig, DoorUnlockResult } from './door-adapter.interface';
import crypto from 'crypto';

/**
 * QR Code Door Adapter
 * Generates time-limited QR codes for door access
 */
export class QRCodeAdapter implements IDoorAdapter {
  readonly type = 'QR_CODE';
  private config: DoorAdapterConfig = {};
  private secretKey: string = '';

  async initialize(config: DoorAdapterConfig): Promise<void> {
    this.config = config;
    this.secretKey = config.secretKey || process.env.DOOR_QR_SECRET || 'default-secret-key';
  }

  async generateUnlockCode(userId: string, doorId: string): Promise<DoorUnlockResult> {
    const timestamp = Date.now();
    const expiresAt = new Date(timestamp + 5 * 60 * 1000); // 5 minutes validity

    // Generate secure unlock code
    const payload = `${userId}:${doorId}:${timestamp}`;
    const signature = crypto
      .createHmac('sha256', this.secretKey)
      .update(payload)
      .digest('hex')
      .substring(0, 16);

    const unlockCode = Buffer.from(`${payload}:${signature}`).toString('base64');

    return {
      success: true,
      message: 'QR code generated successfully',
      unlockCode,
      expiresAt,
    };
  }

  async validateUnlock(code: string, doorId: string): Promise<boolean> {
    try {
      const decoded = Buffer.from(code, 'base64').toString('utf-8');
      const [userId, codeDoorId, timestamp, signature] = decoded.split(':');

      // Check door ID matches
      if (codeDoorId !== doorId) {
        return false;
      }

      // Check expiration (5 minutes)
      const codeTime = parseInt(timestamp);
      if (Date.now() - codeTime > 5 * 60 * 1000) {
        return false;
      }

      // Verify signature
      const payload = `${userId}:${codeDoorId}:${timestamp}`;
      const expectedSignature = crypto
        .createHmac('sha256', this.secretKey)
        .update(payload)
        .digest('hex')
        .substring(0, 16);

      return signature === expectedSignature;
    } catch {
      return false;
    }
  }

  async revokeAccess(userId: string, doorId: string): Promise<boolean> {
    // QR codes are stateless and time-limited, no revocation needed
    // In a production system, you might maintain a blocklist
    return true;
  }

  async healthCheck(): Promise<boolean> {
    return true; // QR is local, always available
  }
}

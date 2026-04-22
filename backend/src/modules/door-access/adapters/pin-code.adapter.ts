import { IDoorAdapter, DoorAdapterConfig, DoorUnlockResult } from './door-adapter.interface';
import crypto from 'crypto';

/**
 * PIN Code Door Adapter
 * Manages numeric PIN-based door access
 */
export class PINCodeAdapter implements IDoorAdapter {
  readonly type = 'PIN_CODE';
  private config: DoorAdapterConfig = {};
  private pinLength: number = 6;

  // In-memory PIN storage (production should use Redis/DB)
  private activePins: Map<string, { pin: string; expiresAt: Date }> = new Map();

  async initialize(config: DoorAdapterConfig): Promise<void> {
    this.config = config;
    this.pinLength = config.pinLength || 6;
  }

  async generateUnlockCode(userId: string, doorId: string): Promise<DoorUnlockResult> {
    const timestamp = Date.now();
    const expiresAt = new Date(timestamp + 10 * 60 * 1000); // 10 minutes validity

    // Generate random numeric PIN
    const pin = this.generateRandomPin();

    // Store the PIN for validation
    const pinKey = `${userId}:${doorId}`;
    this.activePins.set(pinKey, { pin, expiresAt });

    // Clean up expired PINs periodically
    this.cleanupExpiredPins();

    return {
      success: true,
      message: 'PIN code generated successfully',
      unlockCode: pin,
      expiresAt,
    };
  }

  async validateUnlock(code: string, doorId: string): Promise<boolean> {
    // Find matching PIN for this door
    for (const [key, value] of this.activePins.entries()) {
      const [, pinDoorId] = key.split(':');

      if (pinDoorId === doorId && value.pin === code) {
        // Check expiration
        if (new Date() > value.expiresAt) {
          this.activePins.delete(key);
          return false;
        }

        // PIN is valid, remove it (one-time use)
        this.activePins.delete(key);
        return true;
      }
    }

    return false;
  }

  async revokeAccess(userId: string, doorId: string): Promise<boolean> {
    const pinKey = `${userId}:${doorId}`;
    this.activePins.delete(pinKey);
    return true;
  }

  async healthCheck(): Promise<boolean> {
    return true; // PIN system is always available
  }

  private generateRandomPin(): string {
    // Generate cryptographically secure random PIN
    const max = Math.pow(10, this.pinLength);
    const randomNum = crypto.randomInt(0, max);
    return randomNum.toString().padStart(this.pinLength, '0');
  }

  private cleanupExpiredPins(): void {
    const now = new Date();
    for (const [key, value] of this.activePins.entries()) {
      if (now > value.expiresAt) {
        this.activePins.delete(key);
      }
    }
  }
}

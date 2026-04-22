import { IDoorAdapter, DoorAdapterConfig, DoorUnlockResult } from './door-adapter.interface';
import crypto from 'crypto';

/**
 * Bluetooth Door Adapter
 * Manages Bluetooth Low Energy (BLE) based door access
 */
export class BluetoothAdapter implements IDoorAdapter {
  readonly type = 'BLUETOOTH';
  private config: DoorAdapterConfig = {};
  private vendorApiUrl: string = '';
  private vendorApiKey: string = '';

  async initialize(config: DoorAdapterConfig): Promise<void> {
    this.config = config;
    this.vendorApiUrl = config.vendorApiUrl || '';
    this.vendorApiKey = config.vendorApiKey || '';
  }

  async generateUnlockCode(userId: string, doorId: string): Promise<DoorUnlockResult> {
    const timestamp = Date.now();
    const expiresAt = new Date(timestamp + 30 * 60 * 1000); // 30 minutes validity

    // Generate BLE beacon identifier and unlock token
    const blePayload = {
      userId,
      doorId,
      timestamp,
      beaconId: crypto.randomBytes(4).toString('hex').toUpperCase(),
      challengeResponse: crypto.randomBytes(16).toString('hex'),
    };

    const signature = crypto
      .createHmac('sha256', this.vendorApiKey || 'ble-secret')
      .update(JSON.stringify(blePayload))
      .digest('hex');

    // The unlock code is sent to the mobile app which uses it for BLE handshake
    const unlockCode = Buffer.from(
      JSON.stringify({ ...blePayload, signature })
    ).toString('base64');

    return {
      success: true,
      message: 'Bluetooth unlock token generated',
      unlockCode,
      expiresAt,
    };
  }

  async validateUnlock(code: string, doorId: string): Promise<boolean> {
    try {
      const decoded = JSON.parse(Buffer.from(code, 'base64').toString('utf-8'));
      const { userId, doorId: codeDoorId, timestamp, beaconId, challengeResponse, signature } = decoded;

      // Verify door ID
      if (codeDoorId !== doorId) {
        return false;
      }

      // Check expiration (30 minutes)
      if (Date.now() - timestamp > 30 * 60 * 1000) {
        return false;
      }

      // Verify signature
      const payload = { userId, doorId: codeDoorId, timestamp, beaconId, challengeResponse };
      const expectedSignature = crypto
        .createHmac('sha256', this.vendorApiKey || 'ble-secret')
        .update(JSON.stringify(payload))
        .digest('hex');

      return signature === expectedSignature;
    } catch {
      return false;
    }
  }

  async revokeAccess(userId: string, doorId: string): Promise<boolean> {
    // In production, notify the BLE beacon to reject this user
    return true;
  }

  async healthCheck(): Promise<boolean> {
    // BLE health depends on the door hardware being online
    // In production, this would check the BLE gateway status
    return true;
  }
}

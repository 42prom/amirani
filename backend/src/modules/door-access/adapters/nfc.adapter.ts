import { IDoorAdapter, DoorAdapterConfig, DoorUnlockResult } from './door-adapter.interface';
import crypto from 'crypto';

/**
 * NFC Door Adapter
 * Manages NFC-based door access tokens
 */
export class NFCAdapter implements IDoorAdapter {
  readonly type = 'NFC';
  private config: DoorAdapterConfig = {};
  private vendorApiUrl: string = '';
  private vendorApiKey: string = '';

  async initialize(config: DoorAdapterConfig): Promise<void> {
    this.config = config;
    this.vendorApiUrl = config.vendorApiUrl || '';
    this.vendorApiKey = config.vendorApiKey || '';
  }

  async generateUnlockCode(userId: string, doorId: string): Promise<DoorUnlockResult> {
    // Generate NFC token that can be written to user's phone NFC
    const timestamp = Date.now();
    const expiresAt = new Date(timestamp + 24 * 60 * 60 * 1000); // 24 hours validity

    // Generate a secure NFC payload
    const nfcPayload = {
      userId,
      doorId,
      timestamp,
      nonce: crypto.randomBytes(8).toString('hex'),
    };

    const signature = crypto
      .createHmac('sha256', this.vendorApiKey || 'nfc-secret')
      .update(JSON.stringify(nfcPayload))
      .digest('hex');

    const unlockCode = Buffer.from(
      JSON.stringify({ ...nfcPayload, signature })
    ).toString('base64');

    // In production, this would call the NFC vendor API to register the token
    // await this.registerTokenWithVendor(unlockCode, doorId);

    return {
      success: true,
      message: 'NFC token generated successfully',
      unlockCode,
      expiresAt,
    };
  }

  async validateUnlock(code: string, doorId: string): Promise<boolean> {
    try {
      const decoded = JSON.parse(Buffer.from(code, 'base64').toString('utf-8'));
      const { userId, doorId: codeDoorId, timestamp, nonce, signature } = decoded;

      // Verify door ID
      if (codeDoorId !== doorId) {
        return false;
      }

      // Check expiration (24 hours)
      if (Date.now() - timestamp > 24 * 60 * 60 * 1000) {
        return false;
      }

      // Verify signature
      const payload = { userId, doorId: codeDoorId, timestamp, nonce };
      const expectedSignature = crypto
        .createHmac('sha256', this.vendorApiKey || 'nfc-secret')
        .update(JSON.stringify(payload))
        .digest('hex');

      return signature === expectedSignature;
    } catch {
      return false;
    }
  }

  async revokeAccess(userId: string, doorId: string): Promise<boolean> {
    // In production, this would call the vendor API to revoke the token
    // await this.callVendorApi('revoke', { userId, doorId });
    return true;
  }

  async healthCheck(): Promise<boolean> {
    // In production, ping the vendor API
    if (!this.vendorApiUrl) {
      return true; // Local mode
    }

    try {
      // const response = await fetch(`${this.vendorApiUrl}/health`);
      // return response.ok;
      return true;
    } catch {
      return false;
    }
  }
}

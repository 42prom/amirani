export * from './door-adapter.interface';
export * from './qr-code.adapter';
export * from './nfc.adapter';
export * from './bluetooth.adapter';
export * from './pin-code.adapter';

import { IDoorAdapter, DoorAdapterConfig } from './door-adapter.interface';
import { QRCodeAdapter } from './qr-code.adapter';
import { NFCAdapter } from './nfc.adapter';
import { BluetoothAdapter } from './bluetooth.adapter';
import { PINCodeAdapter } from './pin-code.adapter';

export type DoorSystemType = 'QR_CODE' | 'NFC' | 'BLUETOOTH' | 'PIN_CODE';

/**
 * Door Adapter Factory
 * Creates the appropriate adapter based on door system type
 */
export class DoorAdapterFactory {
  private static adapters: Map<string, IDoorAdapter> = new Map();

  /**
   * Get or create an adapter for the specified door system type
   */
  static async getAdapter(
    type: DoorSystemType,
    config?: DoorAdapterConfig
  ): Promise<IDoorAdapter> {
    // Check if adapter already exists
    const cacheKey = `${type}:${JSON.stringify(config || {})}`;
    if (this.adapters.has(cacheKey)) {
      return this.adapters.get(cacheKey)!;
    }

    // Create new adapter
    let adapter: IDoorAdapter;

    switch (type) {
      case 'QR_CODE':
        adapter = new QRCodeAdapter();
        break;
      case 'NFC':
        adapter = new NFCAdapter();
        break;
      case 'BLUETOOTH':
        adapter = new BluetoothAdapter();
        break;
      case 'PIN_CODE':
        adapter = new PINCodeAdapter();
        break;
      default:
        throw new Error(`Unknown door system type: ${type}`);
    }

    // Initialize adapter
    await adapter.initialize(config || {});

    // Cache adapter
    this.adapters.set(cacheKey, adapter);

    return adapter;
  }

  /**
   * Get all available door system types
   */
  static getAvailableTypes(): DoorSystemType[] {
    return ['QR_CODE', 'NFC', 'BLUETOOTH', 'PIN_CODE'];
  }

  /**
   * Clear adapter cache (useful for testing)
   */
  static clearCache(): void {
    this.adapters.clear();
  }
}

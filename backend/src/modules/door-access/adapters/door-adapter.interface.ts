/**
 * Door System Adapter Interface
 * All door system integrations must implement this interface
 */
export interface DoorUnlockResult {
  success: boolean;
  message: string;
  unlockCode?: string;
  expiresAt?: Date;
}

export interface DoorAdapterConfig {
  vendorApiKey?: string;
  vendorApiUrl?: string;
  [key: string]: any;
}

export interface IDoorAdapter {
  /**
   * Adapter type identifier
   */
  readonly type: string;

  /**
   * Initialize the adapter with vendor configuration
   */
  initialize(config: DoorAdapterConfig): Promise<void>;

  /**
   * Generate unlock code/token for a user
   */
  generateUnlockCode(userId: string, doorId: string): Promise<DoorUnlockResult>;

  /**
   * Validate an unlock attempt
   */
  validateUnlock(code: string, doorId: string): Promise<boolean>;

  /**
   * Revoke access for a user
   */
  revokeAccess(userId: string, doorId: string): Promise<boolean>;

  /**
   * Check if door system is online
   */
  healthCheck(): Promise<boolean>;
}

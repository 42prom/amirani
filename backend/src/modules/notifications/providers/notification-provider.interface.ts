/**
 * Notification Provider Interface
 * All notification providers (Push, Email, SMS) must implement this interface
 */

export interface NotificationPayload {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, any>;
  imageUrl?: string;
}

export interface NotificationResult {
  success: boolean;
  messageId?: string;
  error?: string;
}

export interface INotificationProvider {
  /**
   * Provider type identifier
   */
  readonly type: 'PUSH' | 'EMAIL' | 'SMS' | 'IN_APP';

  /**
   * Send a notification
   */
  send(payload: NotificationPayload, token?: string): Promise<NotificationResult>;

  /**
   * Send batch notifications
   */
  sendBatch(payloads: NotificationPayload[], tokens?: string[]): Promise<NotificationResult[]>;

  /**
   * Check if provider is configured and healthy
   */
  isAvailable(): Promise<boolean>;
}

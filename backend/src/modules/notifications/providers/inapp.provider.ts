import {
  INotificationProvider,
  NotificationPayload,
  NotificationResult,
} from './notification-provider.interface';
import prisma from '../../../utils/prisma';
import { NotificationType, NotificationChannel } from '@prisma/client';

/**
 * In-App Notification Provider
 * Stores notifications in the database for retrieval by the mobile app
 */
export class InAppNotificationProvider implements INotificationProvider {
  readonly type = 'IN_APP' as const;

  async send(payload: NotificationPayload, _token?: string): Promise<NotificationResult> {
    try {
      const notification = await prisma.notification.create({
        data: {
          userId: payload.userId,
          type: (payload.data?.type as NotificationType) || NotificationType.SYSTEM,
          channel: NotificationChannel.IN_APP,
          title: payload.title,
          body: payload.body,
          data: payload.data || {},
          isSent: true,
          sentAt: new Date(),
        },
      });

      return {
        success: true,
        messageId: notification.id,
      };
    } catch (error: any) {
      return {
        success: false,
        error: error.message,
      };
    }
  }

  async sendBatch(payloads: NotificationPayload[]): Promise<NotificationResult[]> {
    const results = await Promise.all(
      payloads.map((payload) => this.send(payload))
    );

    return results;
  }

  async isAvailable(): Promise<boolean> {
    // In-app is always available if database is connected
    try {
      await prisma.$queryRaw`SELECT 1`;
      return true;
    } catch {
      return false;
    }
  }
}


import prisma from '../../utils/prisma';
import { NotificationType, NotificationChannel } from '@prisma/client';
import {
  NotificationProviderFactory,
  NotificationPayload,
  NotificationChannelType,
} from './providers';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class NotificationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'NotificationError';
  }
}

// ─── Types ───────────────────────────────────────────────────────────────────

export interface SendNotificationOptions {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, any>;
  channels?: NotificationChannelType[];
  scheduleAt?: Date;
}

export interface BulkNotificationOptions {
  userIds: string[];
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, any>;
  channels?: NotificationChannelType[];
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class NotificationService {
  /**
   * Get public notification configuration for mobile app
   */
  static async getPublicConfig() {
    const cfg = await prisma.pushNotificationConfig.findUnique({
      where: { id: 'singleton' },
    });

    return {
      fcmEnabled:   cfg?.fcmEnabled   ?? false,
      fcmProjectId: cfg?.fcmProjectId || null,
    };
  }

  /**
   * Send a notification to a user
   */
  static async send(options: SendNotificationOptions) {
    const {
      userId,
      type,
      title,
      body,
      data,
      channels = ['IN_APP', 'PUSH'],
      scheduleAt,
    } = options;

    // Get user preferences
    const preferences = await prisma.notificationPreference.findUnique({
      where: { userId },
    });

    // Check quiet hours
    if (preferences?.quietHoursEnabled && !scheduleAt) {
      const inQuietHours = this.isInQuietHours(
        preferences.quietHoursStart,
        preferences.quietHoursEnd
      );
      if (inQuietHours) {
        // Store for later delivery
        return this.scheduleNotification({
          ...options,
          scheduleAt: this.getNextActiveTime(preferences.quietHoursEnd),
        });
      }
    }

    // Check if notification type is enabled
    if (!this.isNotificationTypeEnabled(type, preferences)) {
      return { sent: false, reason: 'Notification type disabled by user' };
    }

    const results: { channel: string; success: boolean; messageId?: string }[] = [];

    // Get user for email
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { email: true },
    });

    for (const channel of channels) {
      // Check channel preference
      if (!this.isChannelEnabled(channel, preferences)) {
        continue;
      }

      const provider = NotificationProviderFactory.getProvider(channel);
      const payload: NotificationPayload = {
        userId,
        title,
        body,
        data: { ...data, type },
      };

      let token: string | undefined;

      switch (channel) {
        case 'PUSH':
          token = preferences?.fcmToken || undefined;
          break;
        case 'EMAIL':
          token = user?.email;
          break;
      }

      const result = await provider.send(payload, token);
      results.push({
        channel,
        success: result.success,
        messageId: result.messageId,
      });

      // Always store in-app notification as well
      if (channel !== 'IN_APP') {
        await prisma.notification.create({
          data: {
            userId,
            type,
            channel: channel as NotificationChannel,
            title,
            body,
            data: data || {},
            isSent: result.success,
            sentAt: result.success ? new Date() : null,
          },
        });
      }
    }

    return { sent: true, results };
  }

  /**
   * Send notifications to multiple users
   */
  static async sendBulk(options: BulkNotificationOptions) {
    const { userIds, ...rest } = options;

    const results = await Promise.all(
      userIds.map((userId) =>
        this.send({ userId, ...rest }).then((result) => ({ userId, ...result }))
      )
    );

    return results;
  }

  /**
   * Schedule a notification for later
   */
  static async scheduleNotification(options: SendNotificationOptions) {
    const { userId, type, title, body, data, scheduleAt } = options;

    if (!scheduleAt) {
      throw new NotificationError('scheduleAt is required for scheduled notifications');
    }

    const notification = await prisma.notification.create({
      data: {
        userId,
        type,
        channel: NotificationChannel.PUSH,
        title,
        body,
        data: data || {},
        scheduledAt: scheduleAt,
        isSent: false,
      },
    });

    return { scheduled: true, notificationId: notification.id, scheduleAt };
  }

  /**
   * Get user notifications
   */
  static async getUserNotifications(
    userId: string,
    options?: {
      unreadOnly?: boolean;
      type?: NotificationType;
      limit?: number;
      offset?: number;
    }
  ) {
    // Only return IN_APP records — PUSH/EMAIL records are delivery-tracking
    // records and must not appear in the user-facing notification centre.
    const where: any = { userId, channel: NotificationChannel.IN_APP };

    if (options?.unreadOnly) {
      where.isRead = false;
    }

    if (options?.type) {
      where.type = options.type;
    }

    const [notifications, total, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: options?.limit || 50,
        skip: options?.offset || 0,
      }),
      prisma.notification.count({ where }),
      prisma.notification.count({ where: { userId, channel: NotificationChannel.IN_APP, isRead: false } }),
    ]);

    return { notifications, total, unreadCount };
  }

  /**
   * Mark notification as read
   */
  static async markAsRead(notificationId: string, userId: string) {
    return prisma.notification.updateMany({
      where: { id: notificationId, userId },
      data: { isRead: true },
    });
  }

  /**
   * Mark all notifications as read
   */
  static async markAllAsRead(userId: string) {
    return prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
  }

  /**
   * Get or create notification preferences
   */
  static async getPreferences(userId: string) {
    let preferences = await prisma.notificationPreference.findUnique({
      where: { userId },
    });

    if (!preferences) {
      preferences = await prisma.notificationPreference.create({
        data: { userId },
      });
    }

    return preferences;
  }

  /**
   * Update notification preferences
   */
  static async updatePreferences(
    userId: string,
    data: {
      pushEnabled?: boolean;
      emailEnabled?: boolean;
      smsEnabled?: boolean;
      paymentReminders?: boolean;
      workoutReminders?: boolean;
      mealReminders?: boolean;
      waterReminders?: boolean;
      motivationalMessages?: boolean;
      quietHoursEnabled?: boolean;
      quietHoursStart?: string;
      quietHoursEnd?: string;
      fcmToken?: string;
      apnsToken?: string;
    }
  ) {
    return prisma.notificationPreference.upsert({
      where: { userId },
      update: data,
      create: { userId, ...data },
    });
  }

  /**
   * Process scheduled notifications (called by cron job)
   */
  static async processScheduledNotifications() {
    const now = new Date();

    const pendingNotifications = await prisma.notification.findMany({
      where: {
        scheduledAt: { lte: now },
        isSent: false,
      },
      include: {
        user: {
          include: {
            notificationPreference: true,
          },
        },
      },
    });

    for (const notification of pendingNotifications) {
      const provider = NotificationProviderFactory.getProvider(
        notification.channel as NotificationChannelType
      );

      const token =
        notification.channel === 'PUSH'
          ? notification.user.notificationPreference?.fcmToken
          : notification.user.email;

      const result = await provider.send(
        {
          userId: notification.userId,
          title: notification.title,
          body: notification.body,
          data: (notification.data as Record<string, any>) || {},
        },
        token || undefined
      );

      await prisma.notification.update({
        where: { id: notification.id },
        data: {
          isSent: result.success,
          sentAt: result.success ? new Date() : null,
        },
      });
    }

    return { processed: pendingNotifications.length };
  }

  // ─── Payment Reminder Helpers ────────────────────────────────────────────────

  /**
   * Send subscription expiring reminder (2 days before)
   */
  static async sendSubscriptionExpiringReminder(membershipId: string) {
    const membership = await prisma.gymMembership.findUnique({
      where: { id: membershipId },
      include: {
        user: true,
        gym: true,
        plan: true,
      },
    });

    if (!membership) return;

    return this.send({
      userId: membership.userId,
      type: NotificationType.SUBSCRIPTION_EXPIRING,
      title: 'Subscription Expiring Soon ⏳',
      body: `Your ${membership.plan.name} subscription at ${membership.gym.name} expires in 2 days. Renew now to maintain your peak performance! ✨`,
      data: {
        membershipId,
        gymId: membership.gymId,
        expiresAt: membership.endDate.toISOString(),
        path: '/profile'
      },
      channels: ['PUSH', 'EMAIL', 'IN_APP'],
    });
  }

  /**
   * Send subscription expired notification
   */
  static async sendSubscriptionExpiredNotification(membershipId: string) {
    const membership = await prisma.gymMembership.findUnique({
      where: { id: membershipId },
      include: {
        user: true,
        gym: true,
      },
    });

    if (!membership) return;

    return this.send({
      userId: membership.userId,
      type: NotificationType.SUBSCRIPTION_EXPIRED,
      title: 'Subscription Expired 🔒',
      body: `Your subscription at ${membership.gym.name} has expired. Join us back soon to continue your journey! 💪`,
      data: {
        membershipId,
        gymId: membership.gymId,
        path: '/profile'
      },
      channels: ['PUSH', 'EMAIL', 'IN_APP'],
    });
  }

  // ─── Private Helpers ─────────────────────────────────────────────────────────

  private static isInQuietHours(start?: string | null, end?: string | null): boolean {
    if (!start || !end) return false;

    const now = new Date();
    const currentMinutes = now.getHours() * 60 + now.getMinutes();

    const [startH, startM] = start.split(':').map(Number);
    const [endH, endM] = end.split(':').map(Number);

    const startMinutes = startH * 60 + startM;
    const endMinutes = endH * 60 + endM;

    if (startMinutes <= endMinutes) {
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    } else {
      // Quiet hours span midnight
      return currentMinutes >= startMinutes || currentMinutes < endMinutes;
    }
  }

  private static getNextActiveTime(quietHoursEnd?: string | null): Date {
    if (!quietHoursEnd) {
      return new Date(Date.now() + 60 * 60 * 1000); // 1 hour from now
    }

    const [endH, endM] = quietHoursEnd.split(':').map(Number);
    const next = new Date();
    next.setHours(endH, endM, 0, 0);

    if (next <= new Date()) {
      next.setDate(next.getDate() + 1);
    }

    return next;
  }

  private static isNotificationTypeEnabled(
    type: NotificationType,
    preferences: any
  ): boolean {
    if (!preferences) return true;

    switch (type) {
      case NotificationType.PAYMENT_REMINDER:
      case NotificationType.SUBSCRIPTION_EXPIRING:
      case NotificationType.SUBSCRIPTION_EXPIRED:
        return preferences.paymentReminders !== false;
      case NotificationType.WORKOUT_REMINDER:
        return preferences.workoutReminders !== false;
      case NotificationType.MEAL_REMINDER:
        return preferences.mealReminders !== false;
      case NotificationType.WATER_REMINDER:
        return preferences.waterReminders !== false;
      case NotificationType.MOTIVATIONAL:
        return preferences.motivationalMessages !== false;
      default:
        return true;
    }
  }

  private static isChannelEnabled(
    channel: NotificationChannelType,
    preferences: any
  ): boolean {
    if (!preferences) return true;

    switch (channel) {
      case 'PUSH':
        return preferences.pushEnabled !== false;
      case 'EMAIL':
        return preferences.emailEnabled !== false;
      case 'SMS':
        return preferences.smsEnabled !== false;
      case 'IN_APP':
        return true; // Always enabled
      default:
        return true;
    }
  }
}

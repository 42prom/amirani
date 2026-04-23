import { Job } from 'bullmq';
import { NotificationType, NotificationChannel } from '@prisma/client';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

export interface PushNotificationPayload {
  userIds: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

export async function processPushNotification(job: Job<PushNotificationPayload>) {
  for (const userId of job.data.userIds) {
    await prisma.notification.create({
      data: {
        userId,
        type: NotificationType.MOTIVATIONAL,
        channel: NotificationChannel.PUSH,
        title: job.data.title,
        body: job.data.body,
        data: (job.data.data ?? undefined) as any,
        isSent: false,
      },
    });
  }
  
  logger.info(`[PUSH] ${job.data.userIds.length} notification record(s) created (isSent=false) — awaiting dispatcher.`, {
    userIds: job.data.userIds,
    title: job.data.title,
  });
  
  return { notified: job.data.userIds.length };
}

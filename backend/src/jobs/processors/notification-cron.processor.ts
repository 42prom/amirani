import { NotificationService } from '../../modules/notifications/notification.service';
import logger from '../../lib/logger';

export async function processNotificationCron() {
  logger.debug('[CRON] Processing scheduled notifications');
  await NotificationService.processScheduledNotifications();
}

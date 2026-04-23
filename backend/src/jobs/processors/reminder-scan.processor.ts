import { SchedulerService } from '../../modules/notifications/scheduler.service';
import logger from '../../lib/logger';

export async function processReminderScan() {
  logger.debug('[CRON] Running reminder scan');
  await SchedulerService.runOnce();
}

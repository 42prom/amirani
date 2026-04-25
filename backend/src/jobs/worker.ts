import { Worker } from 'bullmq';
import logger from '../lib/logger';
import {
  redisConnection,
  leaderboardResetQueue,
  automationCronQueue,
  notificationCronQueue,
  qrCleanupCronQueue,
  reminderScanCronQueue,
} from './queue.config';
import { processAiJob } from './processors/ai-job.processor';
import { processPushNotification } from './processors/push-notification.processor';
import { processLeaderboardReset } from './processors/leaderboard-reset.processor';
import { processLangPackGenerate } from './processors/lang-pack-generate.processor';
import { processAutomationHourly } from './processors/automation-hourly.processor';
import { processNotificationCron } from './processors/notification-cron.processor';
import { processQrCleanup } from './processors/qr-cleanup.processor';
import { processReminderScan } from './processors/reminder-scan.processor';

export function startAiWorkers() {
  const workoutWorker = new Worker(
    'ai-workout-generation',
    async (job) => processAiJob(job as any, 'WORKOUT'),
    { connection: redisConnection, concurrency: 1, lockDuration: 120_000, stalledInterval: 30_000 }
  );

  const dietWorker = new Worker(
    'ai-diet-generation',
    async (job) => processAiJob(job as any, 'DIET'),
    { connection: redisConnection, concurrency: 1, lockDuration: 120_000, stalledInterval: 30_000 }
  );

  const pushWorker = new Worker(
    'push-notifications',
    async (job) => processPushNotification(job as any),
    { connection: redisConnection, concurrency: 5 }
  );

  const langPackWorker = new Worker(
    'lang-pack-generate',
    async (job) => processLangPackGenerate(job as any),
    { connection: redisConnection, concurrency: 1, lockDuration: 120_000 }
  );
  langPackWorker.on('completed', (job) => logger.info('[LangPack] Generated', { language: job.data.language }));
  langPackWorker.on('failed', (job, err) => logger.error('[LangPack] Failed', { jobId: job?.id, err: err.message }));

  const leaderboardResetWorker = new Worker(
    'leaderboard-reset',
    async () => processLeaderboardReset(),
    { connection: redisConnection, concurrency: 1 }
  );

  workoutWorker.on('completed', (job) => logger.info('Workout plan generated', { userId: job.data.userId }));
  workoutWorker.on('failed', (job, err) => logger.error('Workout generation failed', { jobId: job?.id, err: err.message }));

  dietWorker.on('completed', (job) => logger.info('Diet plan generated', { userId: job.data.userId }));
  dietWorker.on('failed', (job, err) => logger.error('Diet generation failed', { jobId: job?.id, err: err.message }));

  leaderboardResetWorker.on('completed', () => logger.info('Leaderboard weekly reset complete'));
  leaderboardResetWorker.on('failed', (job, err) => logger.error('Leaderboard reset failed', { jobId: job?.id, err: err.message }));

  const automationWorker = new Worker('automation-hourly', async () => processAutomationHourly(), { connection: redisConnection, concurrency: 1 });
  const notificationCronWorker = new Worker('notification-cron', async () => processNotificationCron(), { connection: redisConnection, concurrency: 1 });
  const qrCleanupWorker = new Worker('qr-cleanup', async () => processQrCleanup(), { connection: redisConnection, concurrency: 1 });
  const reminderScanWorker = new Worker('reminder-scan', async () => processReminderScan(), { connection: redisConnection, concurrency: 1 });

  automationWorker.on('failed', (job, err) => logger.error('Automation cron failed', { jobId: job?.id, err: err.message }));
  notificationCronWorker.on('failed', (job, err) => logger.error('Notification cron failed', { jobId: job?.id, err: err.message }));
  qrCleanupWorker.on('failed', (job, err) => logger.error('QR cleanup failed', { jobId: job?.id, err: err.message }));
  reminderScanWorker.on('failed', (job, err) => logger.error('Reminder scan failed', { jobId: job?.id, err: err.message }));

  // ── Register cron schedules (BullMQ deduplicates by pattern) ─────────────────
  const cronSchedules = [
    [automationCronQueue,   'automation-hourly',   '0 * * * *'   ],  // every hour
    [notificationCronQueue, 'notification-cron',   '*/5 * * * *' ],  // every 5 min
    [qrCleanupCronQueue,    'qr-cleanup',          '0 3 * * *'   ],  // daily 3am UTC
    [reminderScanCronQueue, 'reminder-scan',        '*/15 * * * *'],  // every 15 min
    [leaderboardResetQueue, 'weekly-reset',         '0 0 * * 1'  ],  // Monday midnight UTC
  ] as const;

  for (const [q, name, pattern] of cronSchedules) {
    (q as typeof automationCronQueue).add(name, {}, { repeat: { pattern, tz: 'UTC' } })
      .catch((err) => logger.warn(`Failed to schedule ${name}`, { err }));
  }

  logger.info('Workers started', { concurrency: { workout: 1, diet: 1, push: 5, crons: 5 } });

  return { workoutWorker, dietWorker, pushWorker, leaderboardResetWorker, automationWorker, notificationCronWorker, qrCleanupWorker, reminderScanWorker, langPackWorker };
}

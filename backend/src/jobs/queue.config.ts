import { Queue } from 'bullmq';
import config from '../config/env';

function parseRedisUrl(url: string): { host: string; port: number; password?: string; username?: string } {
  try {
    const u = new URL(url);
    return {
      host: u.hostname || '127.0.0.1',
      port: parseInt(u.port || '6379', 10),
      ...(u.password ? { password: decodeURIComponent(u.password) } : {}),
      ...(u.username ? { username: decodeURIComponent(u.username) } : {}),
    };
  } catch {
    return { host: '127.0.0.1', port: 6379 };
  }
}

export const redisConnection = {
  ...parseRedisUrl(config.redis.url),
  maxRetriesPerRequest: null as null,
  enableReadyCheck: false,
};

export const aiWorkoutQueue = new Queue('ai-workout-generation', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 1,
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
  },
});

export const aiDietQueue = new Queue('ai-diet-generation', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 1,
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
  },
});

export const pushNotificationQueue = new Queue('push-notifications', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 2,
    backoff: { type: 'fixed', delay: 5000 },
    removeOnComplete: { count: 200 },
    removeOnFail: { count: 100 },
  },
});

export const langPackGenerateQueue = new Queue('lang-pack-generate', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 2,
    backoff: { type: 'fixed', delay: 10_000 },
    removeOnComplete: { count: 50 },
    removeOnFail: { count: 50 },
  },
});

export const leaderboardResetQueue = new Queue('leaderboard-reset', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: { type: 'exponential', delay: 10_000 },
    removeOnComplete: { count: 10 },
    removeOnFail: { count: 20 },
  },
});

const cronJobOptions = {
  attempts: 2,
  backoff: { type: 'fixed' as const, delay: 30_000 },
  removeOnComplete: { count: 5 },
  removeOnFail: { count: 10 },
};

export const automationCronQueue   = new Queue('automation-hourly',    { connection: redisConnection, defaultJobOptions: cronJobOptions });
export const notificationCronQueue = new Queue('notification-cron',    { connection: redisConnection, defaultJobOptions: cronJobOptions });
export const qrCleanupCronQueue    = new Queue('qr-cleanup',           { connection: redisConnection, defaultJobOptions: cronJobOptions });
export const reminderScanCronQueue = new Queue('reminder-scan',        { connection: redisConnection, defaultJobOptions: cronJobOptions });

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

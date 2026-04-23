import { Worker } from 'bullmq';
import logger from '../lib/logger';
import { redisConnection } from './queue.config';
import { processAiJob } from './processors/ai-job.processor';
import { processPushNotification } from './processors/push-notification.processor';

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

  workoutWorker.on('completed', (job) => logger.info('Workout plan generated', { userId: job.data.userId }));
  workoutWorker.on('failed', (job, err) => logger.error('Workout generation failed', { jobId: job?.id, err: err.message }));

  dietWorker.on('completed', (job) => logger.info('Diet plan generated', { userId: job.data.userId }));
  dietWorker.on('failed', (job, err) => logger.error('Diet generation failed', { jobId: job?.id, err: err.message }));

  logger.info('AI workers started', { concurrency: { workout: 1, diet: 1, push: 5 } });

  return { workoutWorker, dietWorker, pushWorker };
}

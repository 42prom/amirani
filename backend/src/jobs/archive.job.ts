import { Worker, Job } from 'bullmq';
import prisma from '../lib/prisma';
import logger from '../lib/logger';

const ARCHIVE_WINDOW_DAYS = 90;

/**
 * BullMQ Worker: coaching-engine-archiver
 * This job identifies inactive AI and Trainer plans that are older than 90 days
 * and sets deletedAt to keep the active sync layers (mobile.controller)
 * lean and high-performance.
 */
export const archiveWorker = new Worker(
  'coaching-engine-archiver',
  async (job: Job) => {
    logger.info(`START: Archiving inactive plans (Window: ${ARCHIVE_WINDOW_DAYS} days)`);

    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - ARCHIVE_WINDOW_DAYS);
    const now = new Date();

    // 1. Archive Inactive Diet Plans
    const archivedDiets = await prisma.dietPlan.updateMany({
      where: {
        isActive: false,
        deletedAt: null,
        updatedAt: { lt: cutoff }
      },
      data: { deletedAt: now }
    });

    // 2. Archive Inactive Workout Plans
    const archivedWorkouts = await prisma.workoutPlan.updateMany({
      where: {
        isActive: false,
        deletedAt: null,
        updatedAt: { lt: cutoff }
      },
      data: { deletedAt: now }
    });

    logger.info(`COMPLETED: Archived ${archivedDiets.count} Diet Plans and ${archivedWorkouts.count} Workout Plans.`);
    return { dietCount: archivedDiets.count, workoutCount: archivedWorkouts.count };
  },
  {
    connection: {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379'),
    }
  }
);

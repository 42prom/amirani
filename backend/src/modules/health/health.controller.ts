import { Router, Request, Response } from 'express';
import { randomUUID } from 'crypto';
import prisma from '../../lib/prisma';
import { getRedisClient } from '../../lib/redis';
import { aiWorkoutQueue } from '../../jobs/queue.config';

const router = Router();

const START_TIME = Date.now();
const VERSION = process.env.npm_package_version ?? '1.0.0';

// GET /health — shallow liveness probe (no external checks)
router.get('/', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    uptime: Math.floor((Date.now() - START_TIME) / 1000),
    version: VERSION,
    timestamp: new Date().toISOString(),
  });
});

// GET /health/deep — readiness probe: DB + Redis + queue
router.get('/deep', async (_req: Request, res: Response) => {
  const checks = await Promise.allSettled([
    prisma.$queryRaw`SELECT 1`,
    getRedisClient().ping(),
    aiWorkoutQueue.getJobCounts(),
  ]);

  const [dbResult, redisResult, queueResult] = checks;

  const db    = dbResult.status    === 'fulfilled' ? 'ok' : 'err';
  const redis = redisResult.status === 'fulfilled' ? 'ok' : 'err';
  const queue = queueResult.status === 'fulfilled' ? 'ok' : 'err';

  const allOk = db === 'ok' && redis === 'ok' && queue === 'ok';

  res.status(allOk ? 200 : 503).json({
    status: allOk ? 'ok' : 'degraded',
    uptime: Math.floor((Date.now() - START_TIME) / 1000),
    version: VERSION,
    timestamp: new Date().toISOString(),
    checks: { db, redis, queue },
    ...(db    === 'err' && { dbError:    (dbResult    as PromiseRejectedResult).reason?.message }),
    ...(redis === 'err' && { redisError: (redisResult as PromiseRejectedResult).reason?.message }),
    ...(queue === 'err' && { queueError: (queueResult as PromiseRejectedResult).reason?.message }),
  });
});

export default router;

// X-Request-ID middleware — attach to app before routes
export function requestIdMiddleware(req: Request, res: Response, next: () => void): void {
  const existing = req.headers['x-request-id'];
  const id = Array.isArray(existing) ? existing[0] : (existing ?? randomUUID());
  (req as any).requestId = id;
  res.setHeader('X-Request-ID', id);
  next();
}

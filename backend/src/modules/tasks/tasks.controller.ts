import { Router, Response } from 'express';
import {
  authenticate,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

const router = Router();
router.use(authenticate);

// ─── GET /api/tasks/today ─────────────────────────────────────────────────────

router.get('/today', async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.userId;

  try {
    const tasks = await (prisma as any).userTask.findMany({
      where: {
        userId,
        dueDate: {
          gte: new Date(new Date().setHours(0, 0, 0, 0)),
          lte: new Date(new Date().setHours(23, 59, 59, 999)),
        },
      },
      orderBy: [{ isCompleted: 'asc' }, { createdAt: 'asc' }],
    });

    return res.json({ data: tasks });
  } catch (err: any) {
    logger.error('[Tasks] GET /today failed', { userId, err: err.message });
    return res.status(500).json({ error: 'Failed to load tasks' });
  }
});

// ─── PATCH /api/tasks/:id/complete ───────────────────────────────────────────

router.patch('/:id/complete', async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.userId;
  const { id }  = req.params;

  try {
    const task = await (prisma as any).userTask.findUnique({ where: { id } });

    if (!task) return res.status(404).json({ error: 'Task not found' });
    if (task.userId !== userId) return res.status(403).json({ error: 'Access denied' });
    if (task.isCompleted) return res.json({ data: task }); // idempotent

    const updated = await (prisma as any).userTask.update({
      where: { id },
      data: { isCompleted: true, completedAt: new Date() },
    });

    // Update DailyProgress.tasksCompleted (fire-and-forget)
    _incrementDailyTasksCompleted(userId).catch((err: any) =>
      logger.warn('[Tasks] DailyProgress sync failed', { userId, err: err.message })
    );

    logger.info('[Tasks] Task completed', { userId, taskId: id, title: task.title });
    return res.json({ data: updated });
  } catch (err: any) {
    logger.error('[Tasks] PATCH /:id/complete failed', { userId, id, err: err.message });
    return res.status(500).json({ error: 'Failed to complete task' });
  }
});

// ─── GET /api/tasks — all tasks (with optional date filter) ──────────────────

router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.userId;
  const { date } = req.query;

  try {
    const where: any = { userId };

    if (date) {
      const d = new Date(date as string);
      where.dueDate = {
        gte: new Date(d.setHours(0, 0, 0, 0)),
        lte: new Date(d.setHours(23, 59, 59, 999)),
      };
    }

    const tasks = await (prisma as any).userTask.findMany({
      where,
      orderBy: [{ dueDate: 'asc' }, { isCompleted: 'asc' }],
    });

    return res.json({ data: tasks });
  } catch (err: any) {
    logger.error('[Tasks] GET / failed', { userId, err: err.message });
    return res.status(500).json({ error: 'Failed to load tasks' });
  }
});

// ─── Helper ───────────────────────────────────────────────────────────────────

async function _incrementDailyTasksCompleted(userId: string) {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  await prisma.dailyProgress.upsert({
    where: { userId_date: { userId, date: today } },
    update: { tasksCompleted: { increment: 1 } },
    create: {
      userId,
      date: today,
      tasksCompleted: 1,
      tasksTotal: 1,
    },
  });
}

export default router;

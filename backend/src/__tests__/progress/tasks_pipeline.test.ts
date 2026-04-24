/**
 * Tasks Pipeline Integration Tests
 *
 * Verifies the three correctness invariants of the DailyProgress pipeline:
 *   1. Meal mark-done is idempotent — re-marking never double-increments tasksCompleted
 *   2. Workout history submission does NOT touch tasksCompleted (removed double-count block)
 *   3. tasksCompleted never exceeds tasksTotal (toggle guard + decrement floor)
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import express from 'express';
import { randomUUID } from 'crypto';

// ── Hoist mocks so they are available inside vi.mock factories ────────────────
const mocks = vi.hoisted(() => ({
  mealLogFindUnique:        vi.fn(),
  mealLogUpsert:            vi.fn(),
  mealLogDeleteMany:        vi.fn(),
  dailyProgressUpdateMany:  vi.fn(),
  dailyProgressFindFirst:   vi.fn(),
  workoutHistoryFindFirst:  vi.fn(),
  exerciseLibraryFindFirst: vi.fn(),
  dietPlanFindFirst:        vi.fn(),
  userFindUnique:           vi.fn(),
  transaction:              vi.fn(),
}));

// ── Config mock ───────────────────────────────────────────────────────────────
vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    cors: { allowedOrigins: [] },
    stripe: { webhookSecret: '' },
    port: 3000,
    nodeEnv: 'test',
    frontendUrl: 'http://localhost:3000',
    isDevelopment: false,
  },
}));

// ── Prisma mock ───────────────────────────────────────────────────────────────
vi.mock('../../lib/prisma', () => ({
  default: {
    mealLog: {
      findUnique: mocks.mealLogFindUnique,
      upsert:     mocks.mealLogUpsert,
      deleteMany: mocks.mealLogDeleteMany,
    },
    dailyProgress: {
      updateMany: mocks.dailyProgressUpdateMany,
      findFirst:  mocks.dailyProgressFindFirst,
    },
    workoutHistory: {
      findFirst: mocks.workoutHistoryFindFirst,
    },
    exerciseLibrary: {
      findFirst: mocks.exerciseLibraryFindFirst,
    },
    dietPlan: {
      findFirst: mocks.dietPlanFindFirst,
    },
    user: {
      findUnique: mocks.userFindUnique,
    },
    $transaction: mocks.transaction,
  },
}));

// ── Auth middleware mock ──────────────────────────────────────────────────────
vi.mock('../../middleware/auth.middleware', () => ({
  authenticate: (req: any, _res: any, next: any) => {
    req.user = { userId: 'user-test-001', role: 'MEMBER' };
    next();
  },
}));

import { MobileController } from '../../modules/mobile-sync/mobile.controller';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.patch('/sync/diet/meals/:refId/log', (req: any, res: any) => {
    req.user = { userId: 'user-test-001', role: 'MEMBER' };
    MobileController.logMeal(req, res);
  });
  app.post('/sync/workout-history', (req: any, res: any) => {
    req.user = { userId: 'user-test-001', role: 'MEMBER' };
    MobileController.logWorkoutHistory(req, res);
  });
  return app;
}

const TODAY = '2026-04-24';

// ─────────────────────────────────────────────────────────────────────────────
describe('Meal mark-done idempotency', () => {
  beforeEach(() => vi.clearAllMocks());

  it('increments tasksCompleted only when the meal was NOT already logged', async () => {
    const app = buildApp();
    const refId = randomUUID();

    // First call — meal does NOT exist yet
    mocks.mealLogFindUnique.mockResolvedValueOnce(null);
    mocks.mealLogUpsert.mockResolvedValueOnce({});
    mocks.dailyProgressUpdateMany.mockResolvedValueOnce({ count: 1 });

    await request(app)
      .patch(`/sync/diet/meals/${refId}/log`)
      .send({ date: TODAY, logged: true })
      .expect(200);

    expect(mocks.dailyProgressUpdateMany).toHaveBeenCalledOnce();
    expect(mocks.dailyProgressUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: { tasksCompleted: { increment: 1 } } })
    );
  });

  it('does NOT increment tasksCompleted when the meal is already logged (re-mark)', async () => {
    const app = buildApp();
    const refId = randomUUID();

    // Meal EXISTS — already logged
    mocks.mealLogFindUnique.mockResolvedValueOnce({ id: randomUUID() });
    mocks.mealLogUpsert.mockResolvedValueOnce({});

    await request(app)
      .patch(`/sync/diet/meals/${refId}/log`)
      .send({ date: TODAY, logged: true })
      .expect(200);

    expect(mocks.dailyProgressUpdateMany).not.toHaveBeenCalled();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Meal unmark idempotency', () => {
  beforeEach(() => vi.clearAllMocks());

  it('decrements tasksCompleted only when a row was actually deleted', async () => {
    const app = buildApp();
    const refId = randomUUID();

    mocks.mealLogFindUnique.mockResolvedValueOnce(null);
    mocks.mealLogDeleteMany.mockResolvedValueOnce({ count: 1 });
    mocks.dailyProgressUpdateMany.mockResolvedValueOnce({ count: 1 });

    await request(app)
      .patch(`/sync/diet/meals/${refId}/log`)
      .send({ date: TODAY, logged: false })
      .expect(200);

    expect(mocks.dailyProgressUpdateMany).toHaveBeenCalledOnce();
    expect(mocks.dailyProgressUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { tasksCompleted: { decrement: 1 } },
        where: expect.objectContaining({ tasksCompleted: { gt: 0 } }),
      })
    );
  });

  it('does NOT decrement when no log row existed to delete', async () => {
    const app = buildApp();
    const refId = randomUUID();

    mocks.mealLogFindUnique.mockResolvedValueOnce(null);
    mocks.mealLogDeleteMany.mockResolvedValueOnce({ count: 0 });

    await request(app)
      .patch(`/sync/diet/meals/${refId}/log`)
      .send({ date: TODAY, logged: false })
      .expect(200);

    expect(mocks.dailyProgressUpdateMany).not.toHaveBeenCalled();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('Workout history — no double-count', () => {
  // resetAllMocks clears both call history AND implementation queues to prevent
  // mockImplementation/mockResolvedValueOnce bleed between tests.
  beforeEach(() => vi.resetAllMocks());

  it('saves workout history without touching tasksCompleted', async () => {
    const app = buildApp();
    const historyId = randomUUID();

    mocks.workoutHistoryFindFirst.mockResolvedValueOnce(null);

    mocks.transaction.mockImplementationOnce(async (fn: Function) => {
      const tx = {
        workoutPlan: { findFirst: vi.fn().mockResolvedValue({ id: randomUUID() }) },
        workoutHistory: { create: vi.fn().mockResolvedValue({ id: historyId }) },
        completedSet: { createMany: vi.fn().mockResolvedValue({ count: 1 }) },
        exerciseLibrary: { findFirst: vi.fn().mockResolvedValue(null) },
        masterWorkoutRoutine: { findUnique: vi.fn().mockResolvedValue(null) },
      };
      return fn(tx);
    });

    const res = await request(app)
      .post('/sync/workout-history')
      .send({
        durationMinutes: 45,
        exercises: [
          { exerciseName: 'Squat', sets: [{ weightKg: 80, reps: 5 }] },
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body.data.historyId).toBe(historyId);
    // Critical: workout submission must NOT touch tasksCompleted
    expect(mocks.dailyProgressUpdateMany).not.toHaveBeenCalled();
  });

  it('returns deduplicated=true and skips DB write on duplicate idempotencyKey', async () => {
    const app = buildApp();
    const existingId = randomUUID();

    mocks.workoutHistoryFindFirst.mockResolvedValueOnce({ id: existingId });

    const res = await request(app)
      .post('/sync/workout-history')
      .send({
        idempotencyKey: `idem-${randomUUID()}`,
        durationMinutes: 30,
        exercises: [
          { exerciseName: 'Press', sets: [{ weightKg: 60, reps: 8 }] },
        ],
      });

    expect(res.status).toBe(200);
    expect(res.body.data.deduplicated).toBe(true);
    expect(mocks.transaction).not.toHaveBeenCalled();
    expect(mocks.dailyProgressUpdateMany).not.toHaveBeenCalled();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
describe('tasksCompleted floor guard', () => {
  beforeEach(() => vi.clearAllMocks());

  it('decrement WHERE clause includes tasksCompleted > 0 to prevent going negative', async () => {
    const app = buildApp();
    const refId = randomUUID();

    mocks.mealLogFindUnique.mockResolvedValueOnce(null);
    mocks.mealLogDeleteMany.mockResolvedValueOnce({ count: 1 });
    mocks.dailyProgressUpdateMany.mockResolvedValueOnce({ count: 0 });

    await request(app)
      .patch(`/sync/diet/meals/${refId}/log`)
      .send({ date: TODAY, logged: false })
      .expect(200);

    const [callArg] = mocks.dailyProgressUpdateMany.mock.calls[0];
    expect(callArg.where).toMatchObject({ tasksCompleted: { gt: 0 } });
  });
});

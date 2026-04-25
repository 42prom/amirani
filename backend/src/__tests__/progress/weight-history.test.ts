import { describe, it, expect, vi, beforeEach } from 'vitest';
import { randomUUID } from 'crypto';

// ── Hoisted mock handles ──────────────────────────────────────────────────────
const mocks = vi.hoisted(() => ({
  weightUpsert: vi.fn(),
  userUpdate:   vi.fn(),
}));

// ── Config mock ───────────────────────────────────────────────────────────────
vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    redis: { url: 'redis://localhost:6379' },
    port: 3000,
    nodeEnv: 'test',
    isDevelopment: false,
  },
}));

// ── Prisma mock ───────────────────────────────────────────────────────────────
vi.mock('../../lib/prisma', () => ({
  default: {
    user:              { update: mocks.userUpdate },
    // Other models used by mobile.controller.ts top-level imports
    dailyProgress:     { upsert: vi.fn(), update: vi.fn(), findUnique: vi.fn() },
    mealLog:           { findUnique: vi.fn(), upsert: vi.fn(), deleteMany: vi.fn(), findMany: vi.fn() },
    workoutHistory:    { findFirst: vi.fn(), create: vi.fn(), update: vi.fn() },
    dietPlan:          { findFirst: vi.fn() },
    exerciseLibrary:   { findFirst: vi.fn() },
    gymMembership:     { findFirst: vi.fn(), findMany: vi.fn() },
    attendance:        { findFirst: vi.fn(), create: vi.fn(), update: vi.fn(), count: vi.fn() },
    gym:               { findUnique: vi.fn(), findFirst: vi.fn() },
    userWeightHistory: { upsert: mocks.weightUpsert, findMany: vi.fn() },
  },
}));

vi.mock('../../lib/logger', () => ({
  default: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() },
}));

vi.mock('../../modules/platform/platform-config.service', () => ({
  PlatformConfigService: { getConfig: vi.fn().mockResolvedValue({}) },
}));

vi.mock('../../utils/leaderboard.service', () => ({
  awardPoints: vi.fn().mockResolvedValue(undefined),
  POINTS: { WORKOUT_COMPLETE: 10, CHECKIN: 5, STREAK_BONUS: 15, CHALLENGE_DONE: 20, PERFECT_DAY: 50, TASK_COMPLETE: 2 },
}));

vi.mock('../../utils/response', () => ({
  serverError: vi.fn((res: any, err: any) => res.status(500).json({ error: err.message })),
  success:     vi.fn((res: any, data: any) => res.status(200).json({ success: true, data })),
  badRequest:  vi.fn((res: any, msg: any) => res.status(400).json({ error: msg })),
}));

import { MobileController } from '../../modules/mobile-sync/mobile.controller';

// ── Minimal req/res fakes ─────────────────────────────────────────────────────

function makeReqRes(body: Record<string, unknown>, userId = 'user-1') {
  const req: any = {
    body,
    user: { userId, role: 'MEMBER', managedGymId: null },
    params: {},
    query: {},
  };

  const res: any = (() => {
    const r: any = {};
    r.status = vi.fn(() => r);
    r.json = vi.fn(() => r);
    return r;
  })();

  return { req, res };
}

// ─────────────────────────────────────────────────────────────────────────────

describe('MobileController.logWeightEntry — upsert idempotency', () => {
  const userId = 'user-1';
  const dateStr = '2026-04-25';
  const expectedDate = new Date('2026-04-25T00:00:00.000Z');

  beforeEach(() => {
    vi.clearAllMocks();
    mocks.userUpdate.mockResolvedValue({});
  });

  it('calls upsert with the composite userId_date key', async () => {
    const entry = { id: randomUUID(), userId, weight: 75, date: expectedDate };
    mocks.weightUpsert.mockResolvedValue(entry);

    const { req, res } = makeReqRes({ weightKg: 75, date: dateStr });
    await MobileController.logWeightEntry(req, res);

    expect(res.status).not.toHaveBeenCalledWith(422);
    expect(mocks.weightUpsert).toHaveBeenCalledOnce();

    const args = mocks.weightUpsert.mock.calls[0][0];
    expect(args.where).toEqual({ userId_date: { userId, date: expectedDate } });
    expect(args.create).toMatchObject({ userId, weight: 75 });
    expect(args.update).toMatchObject({ weight: 75 });
  });

  it('uses the same composite key on two calls with the same date (upsert prevents duplicates)', async () => {
    mocks.weightUpsert
      .mockResolvedValueOnce({ id: 'e1', userId, weight: 70, date: expectedDate })
      .mockResolvedValueOnce({ id: 'e1', userId, weight: 72, date: expectedDate });

    const { req: req1, res: res1 } = makeReqRes({ weightKg: 70, date: dateStr });
    const { req: req2, res: res2 } = makeReqRes({ weightKg: 72, date: dateStr });

    await MobileController.logWeightEntry(req1, res1);
    await MobileController.logWeightEntry(req2, res2);

    expect(mocks.weightUpsert).toHaveBeenCalledTimes(2);
    const firstKey  = mocks.weightUpsert.mock.calls[0][0].where;
    const secondKey = mocks.weightUpsert.mock.calls[1][0].where;
    expect(firstKey).toEqual(secondKey);
  });

  it('syncs User.weight after every upsert', async () => {
    mocks.weightUpsert.mockResolvedValue({ id: 'e1', userId, weight: 78, date: expectedDate });

    const { req, res } = makeReqRes({ weightKg: 78, date: dateStr });
    await MobileController.logWeightEntry(req, res);

    expect(mocks.userUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: userId },
        data:  { weight: 78 },
      }),
    );
  });

  it('uses today UTC midnight when no date is provided', async () => {
    mocks.weightUpsert.mockResolvedValue({ id: 'e2', userId, weight: 80, date: new Date() });

    const { req, res } = makeReqRes({ weightKg: 80 });
    await MobileController.logWeightEntry(req, res);

    const usedDate: Date = mocks.weightUpsert.mock.calls[0][0].where.userId_date.date;
    const todayUtc = new Date();
    todayUtc.setUTCHours(0, 0, 0, 0);
    expect(usedDate.getUTCFullYear()).toBe(todayUtc.getUTCFullYear());
    expect(usedDate.getUTCMonth()).toBe(todayUtc.getUTCMonth());
    expect(usedDate.getUTCDate()).toBe(todayUtc.getUTCDate());
  });

  it('returns 422 when weightKg is below minimum (20)', async () => {
    const { req, res } = makeReqRes({ weightKg: 10 });
    await MobileController.logWeightEntry(req, res);

    expect(res.status).toHaveBeenCalledWith(422);
    expect(mocks.weightUpsert).not.toHaveBeenCalled();
  });

  it('returns 422 when weightKg exceeds maximum (500)', async () => {
    const { req, res } = makeReqRes({ weightKg: 600 });
    await MobileController.logWeightEntry(req, res);

    expect(res.status).toHaveBeenCalledWith(422);
  });

  it('returns 422 when date format is invalid', async () => {
    const { req, res } = makeReqRes({ weightKg: 70, date: '25-04-2026' });
    await MobileController.logWeightEntry(req, res);

    expect(res.status).toHaveBeenCalledWith(422);
  });
});

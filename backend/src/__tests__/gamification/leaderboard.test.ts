import { describe, it, expect, vi, beforeEach } from 'vitest';

// ── Hoisted mock handles ──────────────────────────────────────────────────────
const mocks = vi.hoisted(() => ({
  roomMembershipFindMany: vi.fn(),
  roomMembershipUpdate:   vi.fn(),
  pointEventCreate:       vi.fn(),
  pointEventAggregate:    vi.fn(),
  dailyProgressFindMany:  vi.fn(),
  userUpdate:             vi.fn(),
  transaction:            vi.fn(),
  zadd:                   vi.fn(),
  zrevrange:              vi.fn(),
  zrevrank:               vi.fn(),
  zscore:                 vi.fn(),
  checkAndAwardBadges:    vi.fn(),
  getIO:                  vi.fn(),
}));

// ── Mocks ─────────────────────────────────────────────────────────────────────

vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    redis: { url: 'redis://localhost:6379' },
    port: 3000,
    nodeEnv: 'test',
  },
}));

vi.mock('../../lib/prisma', () => ({
  default: {
    roomMembership: {
      findMany: mocks.roomMembershipFindMany,
      update:   mocks.roomMembershipUpdate,
    },
    pointEvent: {
      create:    mocks.pointEventCreate,
      aggregate: mocks.pointEventAggregate,
    },
    dailyProgress: {
      findMany: mocks.dailyProgressFindMany,
    },
    user: {
      update: mocks.userUpdate,
      findMany: vi.fn().mockResolvedValue([]),
    },
    $transaction: mocks.transaction,
  },
}));

vi.mock('ioredis', () => ({
  default: vi.fn(function() {
    return {
      zadd:      mocks.zadd,
      zrevrange: mocks.zrevrange,
      zrevrank:  mocks.zrevrank,
      zscore:    mocks.zscore,
    };
  }),
}));

vi.mock('../../lib/socket', () => ({
  getIO: mocks.getIO,
}));

vi.mock('../../modules/gamification/badge.service', () => ({
  checkAndAwardBadges: mocks.checkAndAwardBadges,
}));

import { awardPoints, recalculateUserStats } from '../../utils/leaderboard.service';

// ─────────────────────────────────────────────────────────────────────────────

describe('awardPoints', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.getIO.mockImplementation(() => { throw new Error('no socket'); });
    mocks.checkAndAwardBadges.mockResolvedValue(undefined);
    mocks.zadd.mockResolvedValue(1);
    mocks.zrevrange.mockResolvedValue([]);
    mocks.pointEventAggregate.mockResolvedValue({ _sum: { delta: 0 } });
    mocks.dailyProgressFindMany.mockResolvedValue([]);
    mocks.userUpdate.mockResolvedValue({});
    mocks.roomMembershipFindMany.mockResolvedValue([]);
  });

  it('creates a global PointEvent (roomId: null) when the user has no active rooms', async () => {
    mocks.roomMembershipFindMany.mockResolvedValue([]);
    mocks.pointEventCreate.mockResolvedValue({ id: 'pe-1' });

    await awardPoints({
      userId:     'user-1',
      sourceId:   'src-1',
      sourceType: 'WORKOUT',
      delta:      10,
      reason:     'workout done',
    });

    expect(mocks.pointEventCreate).toHaveBeenCalledOnce();
    const call = mocks.pointEventCreate.mock.calls[0][0].data;
    expect(call.roomId).toBeNull();
    expect(call.membershipId).toBeNull();
    expect(call.userId).toBe('user-1');
    expect(call.delta).toBe(10);
  });

  it('creates per-room PointEvents and updates membership when active rooms exist', async () => {
    const membership = {
      id:       'm-1',
      roomId:   'room-1',
      room:     { id: 'room-1', isActive: true },
    };
    mocks.roomMembershipFindMany.mockResolvedValue([membership]);
    mocks.transaction.mockResolvedValue([{}, {}]);
    mocks.pointEventCreate.mockResolvedValue({ id: 'pe-2' });

    await awardPoints({
      userId:     'user-2',
      sourceId:   'src-2',
      sourceType: 'CHECKIN',
      delta:      5,
      reason:     'daily check-in',
    });

    // $transaction called for room update + room-scoped PointEvent
    expect(mocks.transaction).toHaveBeenCalledOnce();
    // pointEventCreate is called to build the ops array passed to $transaction
    const createCall = mocks.pointEventCreate.mock.calls[0][0].data;
    expect(createCall.roomId).toBe('room-1');
    expect(createCall.membershipId).toBe('m-1');
    expect(createCall.delta).toBe(5);
  });

  it('does not award points to inactive rooms', async () => {
    mocks.roomMembershipFindMany.mockResolvedValue([
      { id: 'm-2', roomId: 'room-inactive', room: { id: 'room-inactive', isActive: false } },
    ]);
    mocks.pointEventCreate.mockResolvedValue({ id: 'pe-3' });

    await awardPoints({
      userId:     'user-3',
      sourceId:   'src-3',
      sourceType: 'PERFECT_DAY',
      delta:      50,
      reason:     'perfect day',
    });

    // Falls through to global PointEvent path (no active memberships)
    expect(mocks.pointEventCreate).toHaveBeenCalledOnce();
    const call = mocks.pointEventCreate.mock.calls[0][0].data;
    expect(call.roomId).toBeNull();
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe('recalculateUserStats', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.zadd.mockResolvedValue(1);
    mocks.checkAndAwardBadges.mockResolvedValue(undefined);
    mocks.roomMembershipFindMany.mockResolvedValue([]);
    mocks.userUpdate.mockResolvedValue({});
  });

  it('computes totalPoints as the sum of all PointEvents', async () => {
    mocks.pointEventAggregate.mockResolvedValue({ _sum: { delta: 250 } });
    mocks.dailyProgressFindMany.mockResolvedValue([]);

    const { totalPoints } = await recalculateUserStats('user-1');

    expect(totalPoints).toBe(250);
    expect(mocks.userUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'user-1' },
        data:  expect.objectContaining({ totalPoints: 250 }),
      }),
    );
  });

  it('returns 0 totalPoints when no PointEvents exist', async () => {
    mocks.pointEventAggregate.mockResolvedValue({ _sum: { delta: null } });
    mocks.dailyProgressFindMany.mockResolvedValue([]);

    const { totalPoints, streak } = await recalculateUserStats('user-solo');

    expect(totalPoints).toBe(0);
    expect(streak).toBe(0);
  });

  it('calculates streak correctly for consecutive perfect days', async () => {
    mocks.pointEventAggregate.mockResolvedValue({ _sum: { delta: 100 } });

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const yesterday = new Date(today);
    yesterday.setUTCDate(today.getUTCDate() - 1);
    const twoDaysAgo = new Date(today);
    twoDaysAgo.setUTCDate(today.getUTCDate() - 2);

    mocks.dailyProgressFindMany.mockResolvedValue([
      { date: today,       tasksCompleted: 3, tasksTotal: 3 },
      { date: yesterday,   tasksCompleted: 2, tasksTotal: 2 },
      { date: twoDaysAgo,  tasksCompleted: 1, tasksTotal: 1 },
    ]);

    const { streak } = await recalculateUserStats('user-streak');

    expect(streak).toBe(3);
  });

  it('breaks streak on an incomplete day (tasksCompleted < tasksTotal)', async () => {
    mocks.pointEventAggregate.mockResolvedValue({ _sum: { delta: 60 } });

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    const yesterday = new Date(today);
    yesterday.setUTCDate(today.getUTCDate() - 1);
    const twoDaysAgo = new Date(today);
    twoDaysAgo.setUTCDate(today.getUTCDate() - 2);

    mocks.dailyProgressFindMany.mockResolvedValue([
      { date: today,      tasksCompleted: 3, tasksTotal: 3 },
      { date: yesterday,  tasksCompleted: 1, tasksTotal: 3 }, // incomplete — breaks streak
      { date: twoDaysAgo, tasksCompleted: 3, tasksTotal: 3 },
    ]);

    const { streak } = await recalculateUserStats('user-broken');

    expect(streak).toBe(1); // only today counts
  });

  it('competitive score = totalPoints + streak * 10', async () => {
    mocks.pointEventAggregate.mockResolvedValue({ _sum: { delta: 200 } });

    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    mocks.dailyProgressFindMany.mockResolvedValue([
      { date: today, tasksCompleted: 2, tasksTotal: 2 },
    ]);

    const { competitiveScore, totalPoints, streak } = await recalculateUserStats('user-comp');

    expect(competitiveScore).toBe(totalPoints + streak * 10);
  });
});

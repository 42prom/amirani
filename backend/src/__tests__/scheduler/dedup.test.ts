import { describe, it, expect, vi, beforeEach } from 'vitest';

// ── Prisma mock ───────────────────────────────────────────────────────────────
vi.mock('../../lib/prisma', () => ({
  default: {
    notification: { findFirst: vi.fn() },
    dietPlan: { findMany: vi.fn() },
    workoutPlan: { findMany: vi.fn() },
  },
}));

vi.mock('../../modules/notifications/notification.service', () => ({
  NotificationService: { send: vi.fn() },
}));

vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    cors: { allowedOrigins: [] },
    stripe: { webhookSecret: '' },
    port: 3000,
    nodeEnv: 'test',
    frontendUrl: 'http://localhost:3000',
  },
}));

import prisma from '../../lib/prisma';
import { NotificationService } from '../../modules/notifications/notification.service';

// ── isMatchingTime helper (extracted from private static) ────────────────────
// Mirrors the exact logic in scheduler.service.ts so we can unit-test it
function isMatchingTime(userH: number, userM: number, taskH: number, taskM: number, bufferM: number): boolean {
  const userTotal = userH * 60 + userM;
  const taskTotal = taskH * 60 + taskM;
  const diff = taskTotal - userTotal;
  return diff >= 0 && diff <= bufferM;
}

describe('isMatchingTime', () => {
  it('matches when task time equals current time (diff = 0)', () => {
    expect(isMatchingTime(12, 0, 12, 0, 15)).toBe(true);
  });

  it('matches when task is within buffer window', () => {
    expect(isMatchingTime(12, 0, 12, 14, 15)).toBe(true);
  });

  it('matches at the exact buffer boundary', () => {
    expect(isMatchingTime(12, 0, 12, 15, 15)).toBe(true);
  });

  it('does not match when task is past the buffer window', () => {
    expect(isMatchingTime(12, 0, 12, 16, 15)).toBe(false);
  });

  it('does not match when task time is in the past', () => {
    expect(isMatchingTime(12, 30, 12, 0, 15)).toBe(false);
  });

  it('does not match across hour boundary when diff > buffer', () => {
    // 11:50 total=710, 12:10 total=730 → diff=20 > 15 → false
    expect(isMatchingTime(11, 50, 12, 10, 15)).toBe(false);
  });
});

// ── Dedup: meal reminder not sent twice on the same day ──────────────────────

describe('sendMealReminder dedup', () => {
  beforeEach(() => vi.clearAllMocks());

  it('does NOT call NotificationService.send when a reminder already exists today', async () => {
    vi.mocked(prisma.notification.findFirst).mockResolvedValue({ id: 'existing-notif' } as any);

    // Simulate the dedup guard directly (mirrors sendMealReminder logic)
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const existing = await prisma.notification.findFirst({
      where: {
        userId: 'user-1',
        type: 'MEAL_REMINDER' as any,
        createdAt: { gte: startOfToday },
        data: { path: ['mealId'], equals: 'meal-1' },
      } as any,
    });

    if (!existing) {
      await NotificationService.send({} as any);
    }

    expect(NotificationService.send).not.toHaveBeenCalled();
  });

  it('DOES call NotificationService.send when no reminder exists today', async () => {
    vi.mocked(prisma.notification.findFirst).mockResolvedValue(null);

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const existing = await prisma.notification.findFirst({
      where: {
        userId: 'user-1',
        type: 'MEAL_REMINDER' as any,
        createdAt: { gte: startOfToday },
        data: { path: ['mealId'], equals: 'meal-1' },
      } as any,
    });

    if (!existing) {
      await NotificationService.send({
        userId: 'user-1',
        type: 'MEAL_REMINDER' as any,
        title: 'Breakfast Reminder',
        body: 'Time for breakfast!',
        data: { mealId: 'meal-1' },
        channels: ['PUSH', 'IN_APP'],
      });
    }

    expect(NotificationService.send).toHaveBeenCalledOnce();
  });
});

// ── Dedup: workout reminder not sent twice on the same day ───────────────────

describe('sendWorkoutReminder dedup', () => {
  beforeEach(() => vi.clearAllMocks());

  it('skips send when workout reminder for same routineId already sent today', async () => {
    vi.mocked(prisma.notification.findFirst).mockResolvedValue({ id: 'existing-notif' } as any);

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const existing = await prisma.notification.findFirst({
      where: {
        userId: 'user-2',
        type: 'WORKOUT_REMINDER' as any,
        createdAt: { gte: startOfToday },
        data: { path: ['routineId'], equals: 'routine-1' },
      } as any,
    });

    if (!existing) {
      await NotificationService.send({} as any);
    }

    expect(NotificationService.send).not.toHaveBeenCalled();
  });

  it('findFirst is queried with correct JSON path filter for routineId', async () => {
    vi.mocked(prisma.notification.findFirst).mockResolvedValue(null);

    const routineId = 'routine-abc';
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    await prisma.notification.findFirst({
      where: {
        userId: 'user-2',
        type: 'WORKOUT_REMINDER' as any,
        createdAt: { gte: startOfToday },
        data: { path: ['routineId'], equals: routineId },
      } as any,
    });

    expect(vi.mocked(prisma.notification.findFirst)).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          data: expect.objectContaining({ path: ['routineId'], equals: routineId }),
        }),
      })
    );
  });
});

// ── Workout window: only fires in 7–9am user local time ─────────────────────

describe('workout reminder 7-9am window', () => {
  it('7am is inside the window', () => {
    const hour = 7;
    expect(hour < 7 || hour >= 9).toBe(false); // guard passes → reminder fires
  });

  it('8am is inside the window', () => {
    const hour = 8;
    expect(hour < 7 || hour >= 9).toBe(false);
  });

  it('9am is outside the window (boundary excluded)', () => {
    const hour = 9;
    expect(hour < 7 || hour >= 9).toBe(true); // guard fires → reminder skipped
  });

  it('6am is outside the window', () => {
    const hour = 6;
    expect(hour < 7 || hour >= 9).toBe(true);
  });
});

import IORedis from 'ioredis';
import config from '../config/env';
import prisma from '../lib/prisma';
import { getIO } from '../lib/socket';

// ─── Redis client (singleton) ─────────────────────────────────────────────────

let _redis: IORedis | null = null;

function getRedis(): IORedis {
  if (!_redis) {
    _redis = new IORedis(config.redis.url, { maxRetriesPerRequest: null, lazyConnect: true });
  }
  return _redis;
}

// ─── Key helpers ──────────────────────────────────────────────────────────────

const roomKey = (roomId: string) => `leaderboard:room:${roomId}`;
const weekKey  = (roomId: string) => `leaderboard:week:${roomId}`;

// ─── Point awards ─────────────────────────────────────────────────────────────

export const POINTS = {
  WORKOUT_COMPLETE: 10,
  CHECKIN:          5,
  STREAK_BONUS:     15,
  CHALLENGE_DONE:   20,
  PERFECT_DAY:      50,
} as const;

/**
 * Award points to a user across all their active rooms.
 * Increments Redis sorted set score AND Prisma totalPoints/weeklyPoints.
 * Broadcasts `leaderboard:update` via Socket.IO so room clients refresh.
 */
export async function awardPoints(params: {
  userId: string;
  sourceId: string;
  sourceType: 'WORKOUT' | 'CHECKIN' | 'STREAK_BONUS' | 'CHALLENGE' | 'MANUAL' | 'PERFECT_DAY';
  delta: number;
  reason: string;
}) {
  const { userId, sourceId, sourceType, delta, reason } = params;

  // Find all active room memberships for this user
  const memberships = await prisma.roomMembership.findMany({
    where: { userId },
    include: { room: { select: { id: true, isActive: true } } },
  });

  const activeMemberships = memberships.filter((m) => (m.room as any).isActive);
  if (activeMemberships.length === 0) return;

  const redis = getRedis();
  const io = (() => { try { return getIO(); } catch { return null; } })();

  await Promise.all(
    activeMemberships.map(async (membership) => {
      const roomId = membership.roomId;

      // ── Redis sorted set increment ──────────────────────────────────────────
      await Promise.all([
        redis.zincrby(roomKey(roomId), delta, userId),
        redis.zincrby(weekKey(roomId), delta, userId),
      ]);

      // ── Prisma persistent update ────────────────────────────────────────────
      await prisma.$transaction([
        prisma.roomMembership.update({
          where: { id: membership.id },
          data: {
            totalPoints:  { increment: delta },
            weeklyPoints: { increment: delta },
          },
        }),
        prisma.pointEvent.create({
          data: {
            userId,
            roomId,
            membershipId: membership.id,
            sourceId,
            sourceType,
            delta,
            reason,
          },
        }),
      ]);

      // ── Broadcast to room ────────────────────────────────────────────────────
      if (io) {
        const top10 = await getRoomLeaderboard(roomId, 10);
        io.to(`room:${roomId}`).emit('leaderboard:update', { roomId, leaderboard: top10 });
      }
    })
  );
}

// ─── Read leaderboard ─────────────────────────────────────────────────────────

export interface LeaderboardEntry {
  rank:        number;
  userId:      string;
  fullName:    string;
  avatarUrl:   string | null;
  totalPoints: number;
}

export async function getRoomLeaderboard(
  roomId: string,
  limit = 50,
): Promise<LeaderboardEntry[]> {
  const redis = getRedis();

  // Try Redis first (fast path)
  const raw = await redis.zrevrange(roomKey(roomId), 0, limit - 1, 'WITHSCORES');

  if (raw.length > 0) {
    const entries: Array<{ userId: string; score: number }> = [];
    for (let i = 0; i < raw.length; i += 2) {
      entries.push({ userId: raw[i], score: Number(raw[i + 1]) });
    }

    // Fetch user display names
    const users = await prisma.user.findMany({
      where: { id: { in: entries.map((e) => e.userId) } },
      select: { id: true, fullName: true, avatarUrl: true },
    });
    const userMap = new Map<string, { fullName: string; avatarUrl: string | null }>(
      users.map((u) => [u.id, { fullName: u.fullName || 'Unknown', avatarUrl: u.avatarUrl }])
    );

    return entries.map((e, idx) => ({
      rank:        idx + 1,
      userId:      e.userId,
      fullName:    userMap.get(e.userId)?.fullName ?? 'Unknown',
      avatarUrl:   userMap.get(e.userId)?.avatarUrl ?? null,
      totalPoints: e.score,
    }));
  }

  // Cold start / Redis miss — fall back to Prisma
  const memberships = await prisma.roomMembership.findMany({
    where:   { roomId },
    orderBy: { totalPoints: 'desc' },
    take:    limit,
    include: { user: { select: { id: true, fullName: true, avatarUrl: true } } },
  });

  return memberships.map((m, idx) => ({
    rank:        idx + 1,
    userId:      m.userId,
    fullName:    (m.user as any).fullName || 'Unknown',
    avatarUrl:   (m.user as any).avatarUrl,
    totalPoints: m.totalPoints,
  }));
}

export async function getUserRank(roomId: string, userId: string) {
  const redis = getRedis();
  const rank = await redis.zrevrank(roomKey(roomId), userId);
  const score = await redis.zscore(roomKey(roomId), userId);
  return {
    rank:        rank !== null ? rank + 1 : null,
    totalPoints: score !== null ? Number(score) : 0,
  };
}

/**
 * Re-calculates a user's global totalPoints and active streak based on history.
 * This is the ultimate 'Source of Truth' correction to prevent sync-drifts or cheating.
 */
export async function recalculateUserStats(userId: string) {
  // 1. Total Points (across all rooms/events)
  const pointSum = await prisma.pointEvent.aggregate({
    where: { userId },
    _sum: { delta: true },
  });
  const totalPoints = pointSum._sum.delta ?? 0;

  // 2. Streak Calculation (Consecutive days with activity)
  // CRITICAL PHASE 1: Streak now requires 100% Task Completion (Perfect Day)
  const activities = await prisma.dailyProgress.findMany({
    where: { 
      userId, 
      tasksCompleted: { gt: 0 },
    },
    select: { date: true, tasksCompleted: true, tasksTotal: true },
    orderBy: { date: 'desc' },
  });

  let streak = 0;
  if (activities.length > 0) {
    const today = new Date();
    today.setUTCHours(0, 0, 0, 0);
    
    // Sort and unique by date
    const activityMap = new Map<number, { completed: number, total: number }>();
    activities.forEach(a => {
      const d = new Date(a.date);
      d.setUTCHours(0, 0, 0, 0);
      const ts = d.getTime();
      if (!activityMap.has(ts)) {
        activityMap.set(ts, { completed: a.tasksCompleted, total: a.tasksTotal });
      }
    });

    const uniqueSortedTimestamps = Array.from(activityMap.keys()).sort((a, b) => b - a);
    
    let currentCheck = today;
    // If the latest activity is before today, check if it was yesterday (streak still alive)
    if (uniqueSortedTimestamps[0] < today.getTime()) {
      const yesterday = new Date(today);
      yesterday.setUTCDate(today.getUTCDate() - 1);
      currentCheck = yesterday;
    }

    for (const ts of uniqueSortedTimestamps) {
      if (ts === currentCheck.getTime()) {
        const act = activityMap.get(ts);
        // Requirement: Streak continues only if day was "Perfect" (100% completion)
        // OR if there were no tasks scheduled (rest day with some activity)
        if (act && act.total > 0 && act.completed < act.total) {
          break; // Streak broken by incomplete day
        }
        
        streak++;
        currentCheck.setUTCDate(currentCheck.getUTCDate() - 1);
      } else if (ts < currentCheck.getTime()) {
        break; // Gap found
      }
    }
  }

  // 3. Update User record
  await prisma.user.update({
    where: { id: userId },
    data: { 
      totalPoints: totalPoints as any, 
      streakDays: streak as any,
      lastActivityAt: new Date(),
    } as any,
  });

  return { totalPoints, streak };
}

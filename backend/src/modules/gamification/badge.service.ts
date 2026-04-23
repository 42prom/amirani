import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

// ─── Level thresholds ─────────────────────────────────────────────────────────

const LEVELS = [
  { level: 1, name: 'Rookie',      min: 0    },
  { level: 2, name: 'Contender',   min: 100  },
  { level: 3, name: 'Fighter',     min: 300  },
  { level: 4, name: 'Warrior',     min: 600  },
  { level: 5, name: 'Champion',    min: 1000 },
  { level: 6, name: 'Legend',      min: 2000 },
] as const;

export function calcLevel(totalPoints: number): {
  level: number;
  levelName: string;
  nextLevelPoints: number | null;
} {
  let idx = 0;
  for (let i = 0; i < LEVELS.length; i++) {
    if (totalPoints >= LEVELS[i].min) idx = i;
    else break;
  }
  const current = LEVELS[idx];
  const next = idx + 1 < LEVELS.length ? LEVELS[idx + 1].min : null;
  return { level: current.level, levelName: current.name, nextLevelPoints: next };
}

// ─── Badge evaluation ─────────────────────────────────────────────────────────

/**
 * Check all badge conditions for a user and award any newly earned badges.
 * Called after recalculateUserStats to catch point / streak milestones.
 * Safe to call multiple times — createMany with skipDuplicates is idempotent.
 */
export async function checkAndAwardBadges(userId: string): Promise<void> {
  try {
    const defs = await prisma.badgeDefinition.findMany({ where: { isActive: true } });
    if (defs.length === 0) return;

    const owned = await prisma.userBadge.findMany({
      where: { userId },
      select: { badgeId: true },
    });
    const ownedSet = new Set(owned.map((b) => b.badgeId));
    const unearned = defs.filter((d) => !ownedSet.has(d.id));
    if (unearned.length === 0) return;

    // Load stats once — minimise round-trips
    const [user, checkinCount, workoutCount, perfectDayCount] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: { totalPoints: true, streakDays: true },
      }),
      prisma.pointEvent.count({ where: { userId, sourceType: 'CHECKIN' } }),
      prisma.pointEvent.count({ where: { userId, sourceType: 'WORKOUT' } }),
      prisma.pointEvent.count({ where: { userId, sourceType: 'PERFECT_DAY' } }),
    ]);
    if (!user) return;

    const toAward: string[] = [];
    for (const badge of unearned) {
      let earned = false;
      switch (badge.key) {
        case 'first_checkin': earned = checkinCount >= 1;           break;
        case 'streak_3':      earned = user.streakDays >= 3;        break;
        case 'streak_7':      earned = user.streakDays >= 7;        break;
        case 'streak_30':     earned = user.streakDays >= 30;       break;
        case 'workout_5':     earned = workoutCount >= 5;           break;
        case 'workout_25':    earned = workoutCount >= 25;          break;
        case 'workout_100':   earned = workoutCount >= 100;         break;
        case 'points_100':    earned = user.totalPoints >= 100;     break;
        case 'points_500':    earned = user.totalPoints >= 500;     break;
        case 'points_2000':   earned = user.totalPoints >= 2000;    break;
        case 'perfect_day':   earned = perfectDayCount >= 1;        break;
        case 'perfect_week':  earned = user.streakDays >= 7 && perfectDayCount >= 7; break;
      }
      if (earned) toAward.push(badge.id);
    }

    if (toAward.length === 0) return;

    await prisma.userBadge.createMany({
      data: toAward.map((badgeId) => ({ userId, badgeId })),
      skipDuplicates: true,
    });
    logger.info('[Badges] Awarded', { userId, count: toAward.length });
  } catch (err) {
    // Non-critical — don't surface errors to callers
    logger.error('[Badges] checkAndAwardBadges failed', { userId, err });
  }
}

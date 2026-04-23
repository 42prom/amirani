import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import prisma from '../../lib/prisma';
import { success } from '../../utils/response';
import { calcLevel } from './badge.service';
import logger from '../../lib/logger';

const router = Router();
router.use(authenticate);

/**
 * GET /api/gamification/profile
 * Returns the authenticated user's points, level, streak, and recent badges.
 */
router.get('/profile', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;

    const [user, recentBadges] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: { totalPoints: true, streakDays: true },
      }),
      prisma.userBadge.findMany({
        where: { userId },
        orderBy: { earnedAt: 'desc' },
        take: 10,
        include: { badge: true },
      }),
    ]);

    if (!user) return res.status(404).json({ error: 'User not found' });

    const { level, levelName, nextLevelPoints } = calcLevel(user.totalPoints);

    return success(res, {
      totalPoints:     user.totalPoints,
      level,
      levelName,
      streakDays:      user.streakDays,
      nextLevelPoints,
      recentBadges: recentBadges.map((ub) => ({
        id:       ub.id,
        earnedAt: ub.earnedAt.toISOString(),
        badge: {
          id:          ub.badge.id,
          name:        ub.badge.name,
          description: ub.badge.description,
          iconUrl:     ub.badge.iconUrl ?? null,
          tier:        ub.badge.tier,
        },
      })),
    });
  } catch (err) {
    logger.error('[Gamification] profile error', { err });
    res.status(500).json({ error: 'Internal server error' });
  }
});

export default router;

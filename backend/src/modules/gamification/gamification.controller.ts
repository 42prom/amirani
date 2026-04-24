import { Router, Response } from 'express';
import { z } from 'zod';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import prisma from '../../lib/prisma';
import { success, badRequest, notFound, internalError } from '../../utils/response';
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

/**
 * GET /api/gamification/rewards
 * Lists active rewards available to the authenticated user (gym-specific + platform-wide).
 */
router.get('/rewards', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;

    const membership = await prisma.gymMembership.findFirst({
      where: { userId, status: 'ACTIVE' },
      select: { gymId: true },
    });

    const rewards = await prisma.reward.findMany({
      where: {
        isActive: true,
        OR: [
          { gymId: membership?.gymId ?? '__none__' },
          { gymId: null },
        ],
        AND: [
          { OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }] },
          { OR: [{ stock: null }, { stock: { gt: 0 } }] },
        ],
      },
      orderBy: { pointsCost: 'asc' },
    });

    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { totalPoints: true },
    });

    return success(res, {
      totalPoints: user?.totalPoints ?? 0,
      rewards,
    });
  } catch (err) {
    logger.error('[Gamification] rewards list error', { err });
    internalError(res);
  }
});

const RedeemSchema = z.object({
  rewardId: z.string().uuid(),
});

/**
 * POST /api/gamification/redeem
 * Spends points to redeem a reward. Atomic — deducts points and creates redemption record.
 */
router.post('/redeem', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;

    const parsed = RedeemSchema.safeParse(req.body);
    if (!parsed.success) {
      return badRequest(res, 'rewardId (UUID) is required');
    }
    const { rewardId } = parsed.data;

    const redemption = await prisma.$transaction(async (tx) => {
      const reward = await tx.reward.findUnique({ where: { id: rewardId } });
      if (!reward || !reward.isActive) throw Object.assign(new Error('Reward not found'), { status: 404 });
      if (reward.expiresAt && reward.expiresAt < new Date()) throw Object.assign(new Error('Reward has expired'), { status: 400 });
      if (reward.stock !== null && reward.stock <= 0) throw Object.assign(new Error('Reward is out of stock'), { status: 400 });

      const user = await tx.user.findUnique({ where: { id: userId }, select: { totalPoints: true } });
      if (!user || user.totalPoints < reward.pointsCost) {
        throw Object.assign(new Error('Insufficient points'), { status: 400 });
      }

      // Deduct points and decrement stock atomically
      await tx.user.update({
        where: { id: userId },
        data: { totalPoints: { decrement: reward.pointsCost } },
      });

      if (reward.stock !== null) {
        await tx.reward.update({ where: { id: rewardId }, data: { stock: { decrement: 1 } } });
      }

      return tx.rewardRedemption.create({
        data: { userId, rewardId, pointsSpent: reward.pointsCost, status: 'PENDING' },
        include: { reward: { select: { name: true, imageUrl: true } } },
      });
    });

    logger.info('[Gamification] reward redeemed', { userId, rewardId });
    return success(res, redemption, undefined, 201);
  } catch (err: any) {
    if (err.status === 404) return notFound(res, err.message);
    if (err.status === 400) return badRequest(res, err.message);
    logger.error('[Gamification] redeem error', { err });
    internalError(res);
  }
});

/**
 * GET /api/gamification/redemption-history?limit=20&offset=0
 * Returns the authenticated user's past reward redemptions, newest first.
 */
router.get('/redemption-history', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const limit  = Math.min(parseInt(req.query.limit  as string ?? '20', 10) || 20, 50);
    const offset = parseInt(req.query.offset as string ?? '0',  10) || 0;

    const [items, total] = await Promise.all([
      prisma.rewardRedemption.findMany({
        where: { userId },
        orderBy: { redeemedAt: 'desc' },
        skip: offset,
        take: limit,
        include: { reward: { select: { name: true, imageUrl: true, pointsCost: true } } },
      }),
      prisma.rewardRedemption.count({ where: { userId } }),
    ]);

    return success(res, { items, total, limit, offset });
  } catch (err) {
    logger.error('[Gamification] redemption-history error', { err });
    internalError(res);
  }
});

export default router;

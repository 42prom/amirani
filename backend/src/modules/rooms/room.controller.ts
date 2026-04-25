import { Router, Response } from 'express';
import { z } from 'zod';
import { authenticate, AuthenticatedRequest, branchAdminOrAbove } from '../../middleware/auth.middleware';
import { RoomService } from './room.service';
import { getRoomLeaderboard, getUserRank } from '../../utils/leaderboard.service';
import prisma from '../../lib/prisma';

const router = Router();
router.use(authenticate);

// ─── Member routes ────────────────────────────────────────────────────────────

/** GET /api/rooms/mine — my rooms + available at my gym */
router.get('/mine', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await RoomService.getForMember(req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** GET /api/rooms/:id — room detail + leaderboard */
router.get('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await RoomService.getRoom(req.params.id, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** GET /api/rooms/:id/messages — fetch room messages (paginated) */
router.get('/:id/messages', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const limit = parseInt(String(req.query.limit ?? '50'));
    const cursor = req.query.cursor as string | undefined;
    const messages = await RoomService.getMessages(req.params.id, req.user!.userId, limit, cursor);
    res.json({ data: messages });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** POST /api/rooms/:id/messages — REST fallback for sending a message (used if Socket.IO unavailable) */
router.post('/:id/messages', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { body, imageUrl } = req.body;
    const message = await RoomService.sendMessage(req.params.id, req.user!.userId, body, imageUrl);
    res.status(201).json({ data: message });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** POST /api/rooms — member creates room (gym auto-detected from membership) */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const room = await RoomService.createForMember(req.user!.userId, req.body);
    res.status(201).json({ data: room });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** PATCH /api/rooms/:id — edit room (creator only) */
router.patch('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const room = await RoomService.update(req.params.id, req.user!.userId, req.body);
    res.json({ data: room });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** DELETE /api/rooms/:id — delete room (creator only) */
router.delete('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await RoomService.deleteRoom(req.params.id, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** POST /api/rooms/:id/join — join public room */
router.post('/:id/join', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await RoomService.join(req.params.id, req.user!.userId);
    res.status(201).json({ data: { joined: true } });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** POST /api/rooms/join-by-code — join private room with code */
router.post('/join-by-code', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { code } = req.body;
    if (!code) return res.status(400).json({ error: 'code is required' });
    const room = await RoomService.joinByCode(code, req.user!.userId);
    res.status(201).json({ data: { joined: true, roomId: room.id } });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** DELETE /api/rooms/:id/leave — leave room */
router.delete('/:id/leave', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await RoomService.leave(req.params.id, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** DELETE /api/rooms/:id/members/:userId — kick member (creator only) */
router.delete('/:id/members/:userId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await RoomService.kickMember(req.params.id, req.params.userId, req.user!.userId);
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Leaderboard routes ───────────────────────────────────────────────────────

/** GET /api/rooms/:id/leaderboard — top-50 by points (Redis-backed) */
router.get('/:id/leaderboard', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const limit = Math.min(parseInt(String(req.query.limit ?? '50')), 100);
    const leaderboard = await getRoomLeaderboard(req.params.id, limit);
    res.json({ data: leaderboard });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** GET /api/rooms/:id/my-rank — caller's rank + score */
router.get('/:id/my-rank', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const rank = await getUserRank(req.params.id, req.user!.userId);
    res.json({ data: rank });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** GET /api/rooms/:id/share-card — shareable room metadata for viral sharing */
router.get('/:id/share-card', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const room = await prisma.progressRoom.findUnique({
      where: { id: req.params.id },
      include: { _count: { select: { memberships: true } } },
    });
    if (!room) return res.status(404).json({ error: 'Room not found' });

    const topPlayers = await getRoomLeaderboard(req.params.id, 3);

    res.json({
      data: {
        roomName: room.name,
        memberCount: room._count.memberships,
        metric: room.metric,
        period: room.period,
        inviteCode: room.inviteCode,
        shareLink: `amirani://rooms/join?code=${room.inviteCode}`,
        topPlayers: topPlayers.map(e => ({ name: e.fullName, score: e.totalPoints, rank: e.rank })),
      },
    });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Admin routes ─────────────────────────────────────────────────────────────

/** GET /api/rooms/gyms/:gymId — admin: list all rooms */
router.get('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const rooms = await RoomService.listForGym(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: rooms });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** POST /api/rooms/gyms/:gymId — admin: create room for gym */
router.post('/gyms/:gymId', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const room = await RoomService.createForAdmin(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId,
      req.body
    );
    res.status(201).json({ data: room });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** DELETE /api/rooms/gyms/:gymId/:id — admin: delete any room */
router.delete('/gyms/:gymId/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await RoomService.adminDeleteRoom(
      req.params.id,
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

// ─── Challenge Routes ─────────────────────────────────────────────────────────

const CreateChallengeSchema = z.object({
  title:        z.string().min(2).max(120),
  description:  z.string().max(500).optional(),
  targetValue:  z.number().int().positive(),
  unit:         z.string().min(1).max(40),
  pointsReward: z.number().int().positive().default(25),
  endDate:      z.string().optional(),
});

const ProgressSchema = z.object({
  increment: z.number().int().positive().default(1),
});

/** POST /api/rooms/:id/challenges — create a challenge in a room (creator only) */
router.post('/:id/challenges', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const room = await prisma.progressRoom.findUnique({ where: { id: req.params.id } });
    if (!room) return res.status(404).json({ error: 'Room not found' });
    if (room.creatorId !== userId) return res.status(403).json({ error: 'Only the room creator can add challenges' });

    const parsed = CreateChallengeSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'Validation failed', issues: parsed.error.issues });

    const challenge = await prisma.roomChallenge.create({
      data: {
        roomId:      req.params.id,
        title:       parsed.data.title,
        description: parsed.data.description ?? null,
        targetValue: parsed.data.targetValue,
        unit:        parsed.data.unit,
        pointsReward: parsed.data.pointsReward,
        endDate:     parsed.data.endDate ? new Date(parsed.data.endDate) : null,
      },
    });
    res.status(201).json({ data: challenge });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** GET /api/rooms/:id/challenges — list all active challenges with my progress */
router.get('/:id/challenges', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const challenges = await prisma.roomChallenge.findMany({
      where: { roomId: req.params.id, isActive: true },
      orderBy: { createdAt: 'asc' },
      include: {
        progress: { where: { userId }, select: { currentValue: true, completed: true, completedAt: true } },
      },
    });

    const result = challenges.map((c) => ({
      ...c,
      myProgress: c.progress[0] ?? { currentValue: 0, completed: false, completedAt: null },
      progress: undefined,
    }));

    res.json({ data: result });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

/** PATCH /api/rooms/:id/challenges/:cid/progress — log progress on a challenge */
router.patch('/:id/challenges/:cid/progress', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { id: roomId, cid: challengeId } = req.params;

    const parsed = ProgressSchema.safeParse(req.body);
    if (!parsed.success) return res.status(400).json({ error: 'increment must be a positive integer' });

    const membership = await prisma.roomMembership.findUnique({ where: { roomId_userId: { roomId, userId } } });
    if (!membership) return res.status(403).json({ error: 'Not a member of this room' });

    const challenge = await prisma.roomChallenge.findFirst({ where: { id: challengeId, roomId, isActive: true } });
    if (!challenge) return res.status(404).json({ error: 'Challenge not found' });

    const updated = await prisma.$transaction(async (tx) => {
      const existing = await tx.challengeProgress.findUnique({
        where: { challengeId_userId: { challengeId, userId } },
      });

      const newValue = Math.min(
        (existing?.currentValue ?? 0) + parsed.data.increment,
        challenge.targetValue
      );
      const completed  = newValue >= challenge.targetValue;
      const completedAt = completed && !existing?.completed ? new Date() : (existing?.completedAt ?? null);

      const progress = await tx.challengeProgress.upsert({
        where: { challengeId_userId: { challengeId, userId } },
        create: { challengeId, userId, currentValue: newValue, completed, completedAt },
        update: { currentValue: newValue, completed, completedAt },
      });

      // Award points on first completion
      if (completed && !existing?.completed) {
        await tx.user.update({
          where: { id: userId },
          data: { totalPoints: { increment: challenge.pointsReward } },
        });
      }

      return progress;
    });

    res.json({ data: updated });
  } catch (err: any) {
    res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;


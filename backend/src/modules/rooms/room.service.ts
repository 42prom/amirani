import crypto from 'crypto';
import prisma from '../../lib/prisma';
import { Role, ProgressRoom, RoomMembership, RoomMessage } from '@prisma/client';
import { getIO } from '../../lib/socket';

// ─── Types ────────────────────────────────────────────────────────────────────

export type RoomMetric  = 'CHECKINS' | 'SESSIONS' | 'STREAK' | 'COMPOSITE';
export type RoomPeriod  = 'WEEKLY' | 'MONTHLY' | 'ONGOING' | 'CUSTOM';

export interface CreateRoomData {
  name: string;
  description?: string;
  metric: RoomMetric;
  period: RoomPeriod;
  startDate?: string;
  endDate?: string;
  isPublic?: boolean;
  maxMembers?: number;
}

export interface LeaderboardEntry {
  rank: number;
  userId: string;
  fullName: string;
  avatarUrl: string | null;
  score: number;
  isMe: boolean;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from({ length: 6 }, () =>
    chars[crypto.randomInt(0, chars.length)]
  ).join('');
}

function getPeriodRange(room: ProgressRoom): { start: Date; end: Date } {
  const now = new Date();
  const roomStart = new Date(room.startDate);
  const roomEnd = room.endDate ? new Date(room.endDate) : null;
  const end = roomEnd && roomEnd < now ? roomEnd : now;

  let start: Date;

  if (room.period === 'WEEKLY') {
    const day = now.getDay() === 0 ? 6 : now.getDay() - 1; // 0=Mon
    const monday = new Date(now);
    monday.setDate(now.getDate() - day);
    monday.setHours(0, 0, 0, 0);
    start = monday > roomStart ? monday : roomStart;
  } else if (room.period === 'MONTHLY') {
    const firstOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    start = firstOfMonth > roomStart ? firstOfMonth : roomStart;
  } else {
    // ONGOING or CUSTOM
    start = roomStart;
  }

  return { start, end };
}

async function computeLeaderboard(
  room: ProgressRoom,
  memberIds: string[],
  requesterId: string
): Promise<LeaderboardEntry[]> {
  if (memberIds.length === 0) return [];

  const { start, end } = getPeriodRange(room);

  // Fetch member profiles
  const profiles = await prisma.user.findMany({
    where: { id: { in: memberIds } },
    select: { id: true, fullName: true, avatarUrl: true },
  });

  const profileMap = new Map(profiles.map((p) => [p.id, p]));
  let scoreMap: Map<string, number>;

  if (room.metric === 'CHECKINS') {
    const counts = await prisma.attendance.groupBy({
      by: ['userId'],
      where: { userId: { in: memberIds }, gymId: room.gymId, checkIn: { gte: start, lte: end } },
      _count: { id: true },
    });
    scoreMap = new Map(counts.map((c) => [c.userId, c._count.id]));

  } else if (room.metric === 'SESSIONS') {
    // groupBy doesn't support relation filters — pre-fetch matching session IDs first
    const matchingSessions = await prisma.trainingSession.findMany({
      where: { gymId: room.gymId, startTime: { gte: start, lte: end } },
      select: { id: true },
    });
    const sessionIds = matchingSessions.map((s) => s.id);

    const counts = await prisma.sessionBooking.groupBy({
      by: ['userId'],
      where: {
        userId: { in: memberIds },
        status: 'ATTENDED',
        sessionId: { in: sessionIds },
      },
      _count: { id: true },
    });
    scoreMap = new Map(counts.map((c) => [c.userId, c._count.id]));

  } else if (room.metric === 'COMPOSITE') {
    // COMPOSITE: (check_ins×10) + (sessions×15) + (streak×5) + (challenges_completed×25)

    // Check-ins
    const checkInCounts = await prisma.attendance.groupBy({
      by: ['userId'],
      where: { userId: { in: memberIds }, gymId: room.gymId, checkIn: { gte: start, lte: end } },
      _count: { id: true },
    });
    const checkInMap = new Map<string, number>(checkInCounts.map((c: any) => [c.userId as string, c._count.id as number]));

    // Sessions attended
    const matchingSessions = await prisma.trainingSession.findMany({
      where: { gymId: room.gymId, startTime: { gte: start, lte: end } },
      select: { id: true },
    });
    const sessionIds = matchingSessions.map((s: any) => s.id);
    const sessionCounts = await prisma.sessionBooking.groupBy({
      by: ['userId'],
      where: { userId: { in: memberIds }, status: 'ATTENDED', sessionId: { in: sessionIds } },
      _count: { id: true },
    });
    const sessionMap = new Map<string, number>(sessionCounts.map((c: any) => [c.userId as string, c._count.id as number]));

    // Streak (reuse the same logic)
    const attendances = await prisma.attendance.findMany({
      where: { userId: { in: memberIds }, gymId: room.gymId, checkIn: { gte: start, lte: end } },
      select: { userId: true, checkIn: true },
    });
    const dateSetMap = new Map<string, Set<string>>();
    for (const att of attendances) {
      const uid = att.userId;
      if (!dateSetMap.has(uid)) dateSetMap.set(uid, new Set());
      dateSetMap.get(uid)!.add(new Date(att.checkIn).toISOString().split('T')[0]);
    }
    const streakMap = new Map<string, number>();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    for (const uid of memberIds) {
      const dates = dateSetMap.get(uid) ?? new Set<string>();
      let streak = 0;
      const cur = new Date(today);
      while (true) {
        if (cur < start) break;
        const ds = cur.toISOString().split('T')[0];
        if (dates.has(ds)) { streak++; cur.setDate(cur.getDate() - 1); } else break;
      }
      streakMap.set(uid, streak);
    }

    // Challenges completed in this room during period
    const completions = await prisma.challengeProgress.findMany({
      where: {
        userId: { in: memberIds },
        completed: true,
        completedAt: { gte: start, lte: end },
        challenge: { roomId: room.id, isActive: true },
      },
      select: { userId: true },
    });
    const challengeMap = new Map<string, number>();
    for (const c of completions) {
      challengeMap.set(c.userId, (challengeMap.get(c.userId) ?? 0) + 1);
    }

    scoreMap = new Map(memberIds.map((uid) => [
      uid,
      (checkInMap.get(uid) ?? 0) * 10 +
      (sessionMap.get(uid) ?? 0) * 15 +
      (streakMap.get(uid) ?? 0) * 5 +
      (challengeMap.get(uid) ?? 0) * 25,
    ]));

  } else {
    // STREAK — consecutive days with attendance, counting backwards from today
    const attendances = await prisma.attendance.findMany({
      where: { userId: { in: memberIds }, gymId: room.gymId, checkIn: { gte: start, lte: end } },
      select: { userId: true, checkIn: true },
    });

    const dateSetMap = new Map<string, Set<string>>();
    for (const att of attendances) {
      const uid = att.userId;
      if (!dateSetMap.has(uid)) dateSetMap.set(uid, new Set());
      dateSetMap.get(uid)!.add(new Date(att.checkIn).toISOString().split('T')[0]);
    }

    scoreMap = new Map();
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    for (const uid of memberIds) {
      const dates = dateSetMap.get(uid) ?? new Set();
      let streak = 0;
      const cur = new Date(today);
      while (true) {
        if (cur < start) break; // cap streak at the room's period boundary
        const ds = cur.toISOString().split('T')[0];
        if (dates.has(ds)) {
          streak++;
          cur.setDate(cur.getDate() - 1);
        } else break;
      }
      scoreMap.set(uid, streak);
    }
  }

  const entries = memberIds.map((uid) => ({
    userId: uid,
    fullName: (profileMap.get(uid) as any)?.fullName ?? 'Unknown',
    avatarUrl: (profileMap.get(uid) as any)?.avatarUrl ?? null,
    score: scoreMap.get(uid) ?? 0,
    isMe: uid === requesterId,
  }));

  entries.sort((a, b) => b.score - a.score);
  return entries.map((e, i) => ({ ...e, rank: i + 1 }));
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class RoomService {

  // ─── Mobile: get my rooms + available at gym ──────────────────────────────

  static async getForMember(userId: string) {
    // Find user's gym from active membership
    const membership = await prisma.gymMembership.findFirst({
      where: { userId, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
    if (!membership) return { myRooms: [], gymRooms: [], availableRooms: [], gymId: null };

    const gymId = membership.gymId;

    // Rooms I've joined
    const myMemberships = await prisma.roomMembership.findMany({
      where: { userId },
      include: {
        room: {
          include: {
            creator: { select: { id: true, fullName: true, avatarUrl: true } },
            _count: { select: { members: true } },
          },
        },
      },
    });

    const myRoomIds = new Set(myMemberships.map((m: any) => m.room.id));
    const myRooms = myMemberships.map((m: any) => m.room);

    // Gym-owner-created rooms: visible to all active members regardless of isPublic
    const gym = await prisma.gym.findUnique({ where: { id: gymId }, select: { ownerId: true } });
    const gymRooms = await prisma.progressRoom.findMany({
      where: {
        gymId,
        isActive: true,
        creatorId: gym!.ownerId,
        id: { notIn: [...myRoomIds] },
      },
      include: {
        creator: { select: { id: true, fullName: true, avatarUrl: true } },
        _count: { select: { members: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    const gymRoomIds = new Set(gymRooms.map((r: any) => r.id));

    // Public member-created rooms at gym I haven't joined
    const availableRooms = await prisma.progressRoom.findMany({
      where: {
        gymId,
        isPublic: true,
        isActive: true,
        id: { notIn: [...myRoomIds, ...gymRoomIds] },
      },
      include: {
        creator: { select: { id: true, fullName: true, avatarUrl: true } },
        _count: { select: { members: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    return { myRooms, gymRooms, availableRooms, gymId };
  }

  // ─── Get room detail with leaderboard ─────────────────────────────────────

  static async getRoom(roomId: string, requesterId: string) {
    const room = await prisma.progressRoom.findUnique({
      where: { id: roomId },
      include: {
        creator: { select: { id: true, fullName: true, avatarUrl: true } },
        _count: { select: { members: true } },
      },
    });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });

    const memberships = await prisma.roomMembership.findMany({
      where: { roomId },
      select: { userId: true, joinedAt: true },
    });
    const memberIds = memberships.map((m: any) => m.userId);

    const leaderboard = await computeLeaderboard(room, memberIds, requesterId);
    const isMember = memberIds.includes(requesterId);
    const isCreator = room.creatorId === requesterId;
    const myEntry = leaderboard.find((e) => e.isMe) ?? null;

    return { room, leaderboard, isMember, isCreator, myEntry };
  }

  // ─── Create room (member) ─────────────────────────────────────────────────

  static async createForMember(userId: string, data: CreateRoomData) {
    const membership = await prisma.gymMembership.findFirst({
      where: { userId, status: 'ACTIVE' },
      orderBy: { createdAt: 'desc' },
    });
    if (!membership) throw Object.assign(new Error('Active gym membership required'), { status: 403 });

    return this._createRoom(membership.gymId, userId, data);
  }

  // ─── Create room (admin) ─────────────────────────────────────────────────

  static async createForAdmin(
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: CreateRoomData
  ) {
    await this.assertAdminAccess(gymId, adminId, role, managedGymId);
    return this._createRoom(gymId, adminId, data);
  }

  private static async _createRoom(gymId: string, creatorId: string, data: CreateRoomData) {
    if (!data.name?.trim()) throw Object.assign(new Error('Name is required'), { status: 400 });

    // Generate unique invite code
    let inviteCode: string;
    let attempt = 0;
    do {
      inviteCode = generateInviteCode();
      const exists = await prisma.progressRoom.findUnique({ where: { inviteCode } });
      if (!exists) break;
      attempt++;
    } while (attempt < 5);

    const room = await prisma.progressRoom.create({
      data: {
        gymId,
        creatorId,
        name: data.name.trim(),
        description: data.description?.trim() || null,
        metric: data.metric ?? 'CHECKINS',
        period: data.period ?? 'WEEKLY',
        startDate: data.startDate ? new Date(data.startDate) : new Date(),
        endDate: data.endDate ? new Date(data.endDate) : null,
        isPublic: data.isPublic !== false,
        inviteCode: inviteCode!,
        maxMembers: data.maxMembers ?? 30,
        isActive: true,
      },
      include: {
        creator: { select: { id: true, fullName: true, avatarUrl: true } },
        _count: { select: { members: true } },
      },
    });

    // Auto-join creator
    await prisma.roomMembership.create({ data: { roomId: room.id, userId: creatorId } });

    return room;
  }

  // ─── Join ─────────────────────────────────────────────────────────────────

  static async join(roomId: string, userId: string) {
    const room = await prisma.progressRoom.findUnique({ where: { id: roomId } });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });
    if (!room.isActive) throw Object.assign(new Error('Room is no longer active'), { status: 400 });

    if (!room.isPublic) {
      // Private rooms: allow if it's a gym-owner room and user has active membership
      const gym = await prisma.gym.findUnique({ where: { id: room.gymId }, select: { ownerId: true } });
      if (room.creatorId !== gym!.ownerId) {
        throw Object.assign(new Error('Room is private — use invite code'), { status: 403 });
      }
      const activeMembership = await prisma.gymMembership.findFirst({
        where: { userId, gymId: room.gymId, status: 'ACTIVE' },
      });
      if (!activeMembership) throw Object.assign(new Error('Active gym membership required'), { status: 403 });
    }

    // Atomic check + create to prevent exceeding maxMembers under concurrent joins
    return prisma.$transaction(async (tx) => {
      const existing = await tx.roomMembership.findUnique({
        where: { roomId_userId: { roomId, userId } },
      });
      if (existing) throw Object.assign(new Error('Already a member'), { status: 400 });

      const memberCount = await tx.roomMembership.count({ where: { roomId } });
      if (memberCount >= room.maxMembers) throw Object.assign(new Error('Room is full'), { status: 400 });

      return tx.roomMembership.create({ data: { roomId, userId } });
    });
  }

  static async joinByCode(code: string, userId: string) {
    const room = await prisma.progressRoom.findUnique({ where: { inviteCode: code.toUpperCase() } });
    if (!room) throw Object.assign(new Error('Invalid invite code'), { status: 404 });
    if (!room.isActive) throw Object.assign(new Error('Room is no longer active'), { status: 400 });

    return prisma.$transaction(async (tx) => {
      const existing = await tx.roomMembership.findUnique({
        where: { roomId_userId: { roomId: room.id, userId } },
      });
      if (existing) throw Object.assign(new Error('Already a member'), { status: 400 });

      const memberCount = await tx.roomMembership.count({ where: { roomId: room.id } });
      if (memberCount >= room.maxMembers) throw Object.assign(new Error('Room is full'), { status: 400 });

      await tx.roomMembership.create({ data: { roomId: room.id, userId } });
      return room;
    });
  }

  // ─── Leave ────────────────────────────────────────────────────────────────

  static async leave(roomId: string, userId: string) {
    const room = await prisma.progressRoom.findUnique({ where: { id: roomId } });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });
    if (room.creatorId === userId) throw Object.assign(new Error('Creator cannot leave — delete the room instead'), { status: 400 });

    const existing = await prisma.roomMembership.findUnique({ where: { roomId_userId: { roomId, userId } } });
    if (!existing) throw Object.assign(new Error('Not a member'), { status: 400 });

    await prisma.roomMembership.delete({ where: { roomId_userId: { roomId, userId } } });
    return { left: true };
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  static async deleteRoom(roomId: string, userId: string) {
    const room = await prisma.progressRoom.findUnique({ where: { id: roomId } });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });
    if (room.creatorId !== userId) throw Object.assign(new Error('Only the creator can delete this room'), { status: 403 });

    await prisma.progressRoom.delete({ where: { id: roomId } });
    return { deleted: true };
  }

  // ─── Admin delete (any room in gym) ───────────────────────────────────────

  static async adminDeleteRoom(
    roomId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAdminAccess(gymId, adminId, role, managedGymId);
    const room = await prisma.progressRoom.findFirst({ where: { id: roomId, gymId } });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });
    await prisma.progressRoom.delete({ where: { id: roomId } });
    return { deleted: true };
  }

  // ─── Update room (creator only) ───────────────────────────────────────────

  static async update(
    roomId: string,
    userId: string,
    data: Partial<Pick<CreateRoomData, 'name' | 'description' | 'isPublic' | 'maxMembers' | 'endDate'>>
  ) {
    const room = await prisma.progressRoom.findUnique({ where: { id: roomId } });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });
    if (room.creatorId !== userId) throw Object.assign(new Error('Only the creator can edit this room'), { status: 403 });

    const updateData: any = {};
    if (data.name !== undefined)        updateData.name = data.name.trim();
    if (data.description !== undefined) updateData.description = data.description?.trim() || null;
    if (data.isPublic !== undefined)    updateData.isPublic = data.isPublic;
    if (data.maxMembers !== undefined)  updateData.maxMembers = data.maxMembers;
    if (data.endDate !== undefined)     updateData.endDate = data.endDate ? new Date(data.endDate) : null;

    return prisma.progressRoom.update({ where: { id: roomId }, data: updateData });
  }

  // ─── Kick member (creator only) ───────────────────────────────────────────

  static async kickMember(roomId: string, targetUserId: string, requesterId: string) {
    const room = await prisma.progressRoom.findUnique({ where: { id: roomId } });
    if (!room) throw Object.assign(new Error('Room not found'), { status: 404 });
    if (room.creatorId !== requesterId) throw Object.assign(new Error('Only the creator can remove members'), { status: 403 });
    if (targetUserId === requesterId) throw Object.assign(new Error('Cannot kick yourself'), { status: 400 });

    const existing = await prisma.roomMembership.findUnique({ where: { roomId_userId: { roomId, userId: targetUserId } } });
    if (!existing) throw Object.assign(new Error('Not a member'), { status: 404 });

    await prisma.roomMembership.delete({ where: { roomId_userId: { roomId, userId: targetUserId } } });
    return { kicked: true };
  }

  // ─── Messaging ────────────────────────────────────────────────────────────

  static async sendMessage(roomId: string, userId: string, body: string, imageUrl?: string) {
    const trimmed = body?.trim() ?? '';
    if (!trimmed && !imageUrl) throw Object.assign(new Error('Message body is required'), { status: 400 });
    if (trimmed.length > 2000) throw Object.assign(new Error('Message too long (max 2000 characters)'), { status: 400 });

    // Check if user is a member
    const membership = await prisma.roomMembership.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!membership) throw Object.assign(new Error('Not a member of this room'), { status: 403 });

    const message = await prisma.roomMessage.create({
      data: {
        roomId,
        userId,
        body: trimmed,
        imageUrl,
      },
      include: {
        user: { select: { id: true, fullName: true, avatarUrl: true } },
      },
    });

    try {
      getIO().of('/challenge-rooms').to(`room:${roomId}`).emit('new_message', message);
    } catch { /* Socket.IO not yet initialized */ }

    return message;
  }

  static async getMessages(roomId: string, userId: string, limit: number = 50, cursor?: string) {
    // Check if user is a member
    const membership = await prisma.roomMembership.findUnique({
      where: { roomId_userId: { roomId, userId } },
    });
    if (!membership) throw Object.assign(new Error('Not a member of this room'), { status: 403 });

    return prisma.roomMessage.findMany({
      where: { roomId },
      take: limit,
      skip: cursor ? 1 : 0,
      cursor: cursor ? { id: cursor } : undefined,
      orderBy: { createdAt: 'desc' },
      include: {
        user: { select: { id: true, fullName: true, avatarUrl: true } },
      },
    });
  }

  // ─── Admin: list all rooms for gym ────────────────────────────────────────

  static async listForGym(
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAdminAccess(gymId, adminId, role, managedGymId);
    return prisma.progressRoom.findMany({
      where: { gymId },
      orderBy: { createdAt: 'desc' },
      include: {
        creator: { select: { id: true, fullName: true, avatarUrl: true } },
        _count: { select: { members: true } },
      },
    });
  }

  // ─── Private ──────────────────────────────────────────────────────────────

  private static async assertAdminAccess(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw Object.assign(new Error('Gym not found'), { status: 404 });
    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw Object.assign(new Error('Access denied'), { status: 403 });
    }
  }
}

import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import { AuditLogService } from '../audit/audit.service';
import { WebhookService } from '../webhooks/webhook.service';

// ─── Types ────────────────────────────────────────────────────────────────────

export type SessionType = 'GROUP_CLASS' | 'ONE_ON_ONE' | 'WORKSHOP';
export type SessionStatus = 'SCHEDULED' | 'CANCELLED' | 'COMPLETED';
export type BookingStatus = 'CONFIRMED' | 'CANCELLED' | 'ATTENDED' | 'NO_SHOW';

export interface CreateSessionData {
  trainerId: string;
  title: string;
  description?: string;
  type: SessionType;
  startTime: string; // ISO string
  endTime: string;
  maxCapacity: number;
  location?: string;
  color?: string;
}

export interface SessionWithStats {
  id: string;
  gymId: string;
  trainerId: string;
  title: string;
  description: string | null;
  type: string;
  startTime: Date;
  endTime: Date;
  maxCapacity: number;
  location: string | null;
  status: string;
  color: string | null;
  createdAt: Date;
  trainer: { id: string; fullName: string; avatarUrl: string | null; specialization: string | null };
  bookingCount: number;
  attendedCount: number;
  availableSpots: number;
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class SessionService {

  // ─── Admin CRUD ────────────────────────────────────────────────────────────

  static async listForGym(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined,
    options: { from?: string; to?: string; trainerId?: string; status?: string } = {}
  ): Promise<SessionWithStats[]> {
    await this.assertAccess(gymId, userId, role, managedGymId);

    const where: any = { gymId };
    if (options.trainerId) where.trainerId = options.trainerId;
    if (options.status)    where.status = options.status;
    if (options.from || options.to) {
      where.startTime = {};
      if (options.from) where.startTime.gte = new Date(options.from);
      if (options.to)   where.startTime.lte = new Date(options.to);
    }

    const prismaAny = prisma as any;
    const sessions = await prismaAny.trainingSession.findMany({
      where,
      orderBy: { startTime: 'asc' },
      include: {
        trainer: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                avatarUrl: true,
              }
            }
          }
        },
        _count: { select: { bookings: true } },
      },
    });

    // Get attended counts
    const sessionIds = sessions.map((s: any) => s.id);
    const attendedCounts = sessionIds.length > 0
      ? await prismaAny.sessionBooking.groupBy({
          by: ['sessionId'],
          where: { sessionId: { in: sessionIds }, status: 'ATTENDED' },
          _count: { id: true },
        })
      : [];
    const attendedMap = new Map(attendedCounts.map((a: any) => [a.sessionId, a._count.id]));

    return sessions.map((s: any) => ({
      ...s,
      trainer: {
        ...s.trainer,
        fullName: s.trainer.user?.fullName || s.trainer.fullName,
        avatarUrl: s.trainer.user?.avatarUrl || s.trainer.avatarUrl,
      },
      bookingCount: s._count.bookings,
      attendedCount: attendedMap.get(s.id) ?? 0,
      availableSpots: Math.max(0, s.maxCapacity - s._count.bookings),
    }));
  }

  static async create(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: CreateSessionData
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);

    // Verify trainer belongs to gym
    const prismaAny = prisma as any;
    const trainer = await prismaAny.trainerProfile.findFirst({
      where: { id: data.trainerId, gymId },
    });
    if (!trainer) throw Object.assign(new Error('Trainer not found in this gym'), { status: 404 });

    const start = new Date(data.startTime);
    const end   = new Date(data.endTime);
    if (end <= start) throw Object.assign(new Error('End time must be after start time'), { status: 400 });

    const created = await prismaAny.trainingSession.create({
      data: {
        gymId,
        trainerId: data.trainerId,
        title: data.title,
        description: data.description || null,
        type: data.type,
        startTime: start,
        endTime: end,
        maxCapacity: data.maxCapacity,
        location: data.location || null,
        color: data.color || null,
        status: 'SCHEDULED',
      },
      include: {
        trainer: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                avatarUrl: true,
              }
            }
          }
        },
      },
    });
    AuditLogService.log(gymId, userId, 'SESSION_CREATED', 'session', `Scheduled "${data.title}" with ${created.trainer.fullName} on ${start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`, created.id);
    WebhookService.dispatch(gymId, 'session.created', { sessionId: created.id, title: data.title, startTime: start, trainerId: data.trainerId });
    return {
      ...created,
      trainer: {
        ...created.trainer,
        fullName: created.trainer.user?.fullName || created.trainer.fullName,
        avatarUrl: created.trainer.user?.avatarUrl || created.trainer.avatarUrl,
      }
    };
  }

  static async update(
    id: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: Partial<CreateSessionData> & { status?: SessionStatus }
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const session = await prismaAny.trainingSession.findFirst({ where: { id, gymId } });
    if (!session) throw Object.assign(new Error('Session not found'), { status: 404 });

    const updateData: any = {};
    if (data.title !== undefined)       updateData.title = data.title;
    if (data.description !== undefined) updateData.description = data.description;
    if (data.type !== undefined)        updateData.type = data.type;
    if (data.startTime !== undefined)   updateData.startTime = new Date(data.startTime);
    if (data.endTime !== undefined)     updateData.endTime = new Date(data.endTime);
    if (data.maxCapacity !== undefined) updateData.maxCapacity = data.maxCapacity;
    if (data.location !== undefined)    updateData.location = data.location;
    if (data.color !== undefined)       updateData.color = data.color;
    if (data.status !== undefined)      updateData.status = data.status;

    const updated = await prismaAny.trainingSession.update({
      where: { id },
      data: updateData,
      include: {
        trainer: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                avatarUrl: true,
              }
            }
          }
        },
      },
    });

    if (data.status === 'CANCELLED') {
      AuditLogService.log(gymId, userId, 'SESSION_CANCELLED', 'session', `Cancelled session "${session.title}"`, id);
      WebhookService.dispatch(gymId, 'session.cancelled', { sessionId: id, title: session.title });
    } else {
      AuditLogService.log(gymId, userId, 'SESSION_UPDATED', 'session', `Updated session "${session.title}"`, id);
    }

    // If cancelled, notify confirmed bookings
    if (data.status === 'CANCELLED') {
      const bookings = await prismaAny.sessionBooking.findMany({
        where: { sessionId: id, status: 'CONFIRMED' },
        select: { userId: true },
      });
      if (bookings.length > 0) {
        await NotificationService.sendBulk({
          userIds: bookings.map((b: any) => b.userId),
          type: 'SYSTEM' as any,
          title: 'Class Cancelled ❌',
          body: `"${session.title}" scheduled for ${new Date(session.startTime).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })} has been cancelled.`,
          data: { sessionId: id, gymId, path: '/gym' },
          channels: ['PUSH', 'IN_APP'],
        });
      }
    }

    return {
      ...updated,
      trainer: {
        ...updated.trainer,
        fullName: updated.trainer.user?.fullName || updated.trainer.fullName,
        avatarUrl: updated.trainer.user?.avatarUrl || updated.trainer.avatarUrl,
      }
    };
  }

  static async deleteSession(
    id: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const session = await prismaAny.trainingSession.findFirst({ where: { id, gymId } });
    if (!session) throw Object.assign(new Error('Session not found'), { status: 404 });
    await prismaAny.trainingSession.delete({ where: { id } });
    AuditLogService.log(gymId, userId, 'SESSION_DELETED', 'session', `Deleted session "${session.title}"`, id);
    return { deleted: true };
  }

  // ─── Bookings (admin view) ─────────────────────────────────────────────────

  static async getBookings(
    sessionId: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const session = await prismaAny.trainingSession.findFirst({ where: { id: sessionId, gymId } });
    if (!session) throw Object.assign(new Error('Session not found'), { status: 404 });

    const bookings = await prismaAny.sessionBooking.findMany({
      where: { sessionId },
      orderBy: { bookedAt: 'asc' },
      include: {
        user: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
      },
    });

    return bookings.map((b: any) => ({
      ...b,
      session: {
        ...b.session,
        trainer: {
          ...b.session.trainer,
          fullName: b.session.trainer.user?.fullName || b.session.trainer.fullName,
          avatarUrl: b.session.trainer.user?.avatarUrl || b.session.trainer.avatarUrl,
        }
      }
    }));
  }

  static async markAttendance(
    sessionId: string,
    memberId: string,
    status: BookingStatus,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const booking = await prismaAny.sessionBooking.findUnique({
      where: { sessionId_userId: { sessionId, userId: memberId } },
    });
    if (!booking) throw Object.assign(new Error('Booking not found'), { status: 404 });
    return prismaAny.sessionBooking.update({
      where: { sessionId_userId: { sessionId, userId: memberId } },
      data: { status },
    });
  }

  // ─── Member booking (called from mobile) ──────────────────────────────────

  static async bookSession(sessionId: string, userId: string) {
    const prismaAny = prisma as any;
    const session = await prismaAny.trainingSession.findUnique({ where: { id: sessionId } });
    if (!session) throw Object.assign(new Error('Session not found'), { status: 404 });
    if (session.status !== 'SCHEDULED') throw Object.assign(new Error('Session is not available'), { status: 400 });

    // Check capacity
    const bookingCount = await prismaAny.sessionBooking.count({
      where: { sessionId, status: 'CONFIRMED' },
    });
    if (bookingCount >= session.maxCapacity) {
      throw Object.assign(new Error('Session is full'), { status: 400 });
    }

    // Check active membership
    const membership = await prisma.gymMembership.findFirst({
      where: { userId, gymId: session.gymId, status: 'ACTIVE' },
    });
    if (!membership) throw Object.assign(new Error('Active membership required'), { status: 403 });

    const booking = await prismaAny.sessionBooking.upsert({
      where: { sessionId_userId: { sessionId, userId } },
      update: { status: 'CONFIRMED' },
      create: { sessionId, userId, status: 'CONFIRMED' },
    });

    // Notify member
    await NotificationService.send({
      userId,
      type: 'SYSTEM' as any,
      title: 'Booking Confirmed! ✅',
      body: `You're booked for "${session.title}" on ${new Date(session.startTime).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}.`,
      data: { sessionId, gymId: session.gymId, path: '/gym' },
      channels: ['PUSH', 'IN_APP'],
    });

    return booking;
  }

  static async cancelBooking(sessionId: string, userId: string) {
    const prismaAny = prisma as any;
    const booking = await prismaAny.sessionBooking.findUnique({
      where: { sessionId_userId: { sessionId, userId } },
    });
    if (!booking) throw Object.assign(new Error('Booking not found'), { status: 404 });
    return prismaAny.sessionBooking.update({
      where: { sessionId_userId: { sessionId, userId } },
      data: { status: 'CANCELLED' },
    });
  }

  static async getMemberBookings(userId: string, gymId?: string) {
    const prismaAny = prisma as any;
    const where: any = { userId, status: 'CONFIRMED' };
    const bookings = await prismaAny.sessionBooking.findMany({
      where,
      orderBy: { bookedAt: 'desc' },
      include: {
        session: {
          include: {
            trainer: {
              include: {
                user: {
                  select: {
                    id: true,
                    fullName: true,
                    avatarUrl: true,
                  }
                }
              }
            },
            gym: { select: { id: true, name: true } },
          },
        },
      },
    });

    return bookings.map((b: any) => ({
      ...b,
      session: {
        ...b.session,
        trainer: {
          ...b.session.trainer,
          fullName: b.session.trainer.user?.fullName || b.session.trainer.fullName,
          avatarUrl: b.session.trainer.user?.avatarUrl || b.session.trainer.avatarUrl,
        }
      }
    }));
  }

  // ─── Trainer stats ─────────────────────────────────────────────────────────

  static async getTrainerStats(gymId: string, userId: string, role: Role, managedGymId: string | null | undefined) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;

    const trainers = await prismaAny.trainerProfile.findMany({
      where: { gymId },
      select: { id: true, fullName: true, avatarUrl: true, specialization: true },
    });

    const now = new Date();
    const ago30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const stats = await Promise.all(trainers.map(async (t: any) => {
      const [totalSessions, completedSessions, totalBookings] = await Promise.all([
        prismaAny.trainingSession.count({ where: { trainerId: t.id, gymId } }),
        prismaAny.trainingSession.count({ where: { trainerId: t.id, gymId, status: 'COMPLETED', startTime: { gte: ago30 } } }),
        prismaAny.sessionBooking.count({
          where: {
            session: { trainerId: t.id, gymId },
            status: { in: ['CONFIRMED', 'ATTENDED'] },
          },
        }),
      ]);
      return { ...t, totalSessions, completedSessions, totalBookings };
    }));

    return stats.sort((a, b) => b.totalBookings - a.totalBookings);
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  private static async assertAccess(
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

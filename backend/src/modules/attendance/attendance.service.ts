import prisma, { Prisma } from '../../lib/prisma';
import { Role } from '@prisma/client';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class AttendanceNotFoundError extends Error {
  constructor(public resource: string = 'Attendance') {
    super(`${resource} not found`);
    this.name = 'AttendanceNotFoundError';
  }
}

export class AttendanceAccessDeniedError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'AttendanceAccessDeniedError';
  }
}

export class AttendanceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AttendanceValidationError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class AttendanceService {
  /**
   * Check in a member to a gym
   */
  static async checkIn(
    userId: string,
    gymId: string,
    requesterId: string,
    requesterRole: Role
  ) {
    // Verify gym exists
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new AttendanceNotFoundError('Gym');
    }

    // Check if user has active membership at this gym
    const membership = await prisma.gymMembership.findUnique({
      where: {
        userId_gymId: { userId, gymId },
      },
    });

    if (!membership) {
      throw new AttendanceValidationError('User is not a member of this gym');
    }

    if (membership.status !== 'ACTIVE') {
      throw new AttendanceValidationError('Membership is not active');
    }

    if (new Date() > membership.endDate) {
      throw new AttendanceValidationError('Membership has expired');
    }

    // Check + create in a serializable transaction to prevent duplicate active check-ins
    // from concurrent requests (e.g., double-tap on NFC reader).
    return prisma.$transaction(async (tx) => {
      const existingCheckIn = await tx.attendance.findFirst({
        where: { userId, gymId, checkOut: null },
      });

      if (existingCheckIn) {
        throw new AttendanceValidationError('Already checked in. Please check out first.');
      }

      return tx.attendance.create({
        data: { userId, gymId },
        include: {
          user: { select: { id: true, fullName: true, email: true } },
          gym:  { select: { id: true, name: true } },
        },
      });
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  /**
   * Check out a member from a gym
   */
  static async checkOut(attendanceId: string, requesterId: string, requesterRole: Role) {
    const attendance = await prisma.attendance.findUnique({
      where: { id: attendanceId },
      include: { gym: true },
    });

    if (!attendance) {
      throw new AttendanceNotFoundError();
    }

    if (attendance.checkOut) {
      throw new AttendanceValidationError('Already checked out');
    }

    // Calculate duration in minutes
    const checkOutTime = new Date();
    const duration = Math.round(
      (checkOutTime.getTime() - attendance.checkIn.getTime()) / (1000 * 60)
    );

    return prisma.attendance.update({
      where: { id: attendanceId },
      data: {
        checkOut: checkOutTime,
        duration,
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
          },
        },
        gym: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });
  }

  /**
   * Get attendance records for a gym
   */
  static async getGymAttendance(
    gymId: string,
    userId: string,
    role: Role,
    options?: {
      startDate?: Date;
      endDate?: Date;
      limit?: number;
      offset?: number;
    }
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new AttendanceNotFoundError('Gym');
    }

    // Check access
    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
      // Check if user is a trainer at this gym
      const trainer = await prisma.trainerProfile.findFirst({
        where: { userId, gymId },
      });
      if (!trainer) {
        throw new AttendanceAccessDeniedError();
      }
    }

    const where: any = { gymId };
    if (options?.startDate || options?.endDate) {
      where.checkIn = {};
      if (options.startDate) where.checkIn.gte = options.startDate;
      if (options.endDate) where.checkIn.lte = options.endDate;
    }

    const [records, total] = await Promise.all([
      prisma.attendance.findMany({
        where,
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
              email: true,
              avatarUrl: true,
            },
          },
        },
        orderBy: { checkIn: 'desc' },
        take: options?.limit || 50,
        skip: options?.offset || 0,
      }),
      prisma.attendance.count({ where }),
    ]);

    return { records, total };
  }

  /**
   * Get attendance records for a specific user
   */
  static async getUserAttendance(
    targetUserId: string,
    requesterId: string,
    requesterRole: Role,
    gymId?: string
  ) {
    // Users can see their own attendance, admins/owners can see all
    if (requesterRole === Role.GYM_MEMBER || requesterRole === Role.HOME_USER) {
      if (targetUserId !== requesterId) {
        throw new AttendanceAccessDeniedError();
      }
    }

    const where: any = { userId: targetUserId };
    if (gymId) where.gymId = gymId;

    return prisma.attendance.findMany({
      where,
      include: {
        gym: {
          select: {
            id: true,
            name: true,
            city: true,
          },
        },
      },
      orderBy: { checkIn: 'desc' },
      take: 100,
    });
  }

  /**
   * Get today's attendance for a gym
   */
  static async getTodayAttendance(gymId: string, userId: string, role: Role) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new AttendanceNotFoundError('Gym');
    }

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
      throw new AttendanceAccessDeniedError();
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    return prisma.attendance.findMany({
      where: {
        gymId,
        checkIn: { gte: today },
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { checkIn: 'desc' },
    });
  }

  /**
   * Get attendance statistics for a gym
   */
  static async getGymAttendanceStats(gymId: string, userId: string, role: Role) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new AttendanceNotFoundError('Gym');
    }

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
      throw new AttendanceAccessDeniedError();
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const weekAgo = new Date(today);
    weekAgo.setDate(weekAgo.getDate() - 7);

    const monthAgo = new Date(today);
    monthAgo.setDate(monthAgo.getDate() - 30);

    const [
      todayCount,
      weekCount,
      monthCount,
      currentlyInGym,
      avgDuration,
    ] = await Promise.all([
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: today } },
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: weekAgo } },
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: monthAgo } },
      }),
      prisma.attendance.count({
        where: { gymId, checkOut: null },
      }),
      prisma.attendance.aggregate({
        where: { gymId, duration: { not: null } },
        _avg: { duration: true },
      }),
    ]);

    // Peak hours analysis (last 30 days)
    const recentAttendances = await prisma.attendance.findMany({
      where: { gymId, checkIn: { gte: monthAgo } },
      select: { checkIn: true },
    });

    const hourCounts: Record<number, number> = {};
    recentAttendances.forEach((a) => {
      const hour = a.checkIn.getHours();
      hourCounts[hour] = (hourCounts[hour] || 0) + 1;
    });

    const peakHours = Object.entries(hourCounts)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 3)
      .map(([hour, count]) => ({ hour: parseInt(hour), count }));

    return {
      todayCount,
      weekCount,
      monthCount,
      currentlyInGym,
      avgDurationMinutes: Math.round(avgDuration._avg.duration || 0),
      peakHours,
    };
  }

  /**
   * Get missed days for a user (days with no attendance in active membership period)
   */
  static async getMissedDays(userId: string, gymId: string, days: number = 30) {
    const membership = await prisma.gymMembership.findUnique({
      where: { userId_gymId: { userId, gymId } },
    });

    if (!membership) {
      throw new AttendanceNotFoundError('Membership');
    }

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const attendances = await prisma.attendance.findMany({
      where: {
        userId,
        gymId,
        checkIn: { gte: startDate },
      },
      select: { checkIn: true },
    });

    // Get unique days with attendance
    const attendedDays = new Set(
      attendances.map((a) => a.checkIn.toISOString().split('T')[0])
    );

    // Calculate missed days
    const missedDays: string[] = [];
    const current = new Date(startDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    while (current <= today) {
      const dateStr = current.toISOString().split('T')[0];
      if (!attendedDays.has(dateStr)) {
        missedDays.push(dateStr);
      }
      current.setDate(current.getDate() + 1);
    }

    return {
      totalDays: days,
      attendedDays: attendedDays.size,
      missedDays: missedDays.length,
      attendanceRate: Math.round((attendedDays.size / days) * 100),
      missedDates: missedDays.slice(-10), // Last 10 missed days
    };
  }
}

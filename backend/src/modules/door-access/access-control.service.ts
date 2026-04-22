import prisma from '../../utils/prisma';
import { DayOfWeek } from '@prisma/client';
import { validateMembershipAccess } from '../memberships/membership-utils';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface AccessValidationResult {
  allowed: boolean;
  reason?: string;
  membership?: {
    id: string;
    planName: string;
    startDate: Date;
    endDate: Date;
  };
  restrictions?: {
    hasTimeRestriction: boolean;
    accessStartTime?: string;
    accessEndTime?: string;
    accessDays?: DayOfWeek[];
    currentTime: string;
    currentDay: DayOfWeek;
  };
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class AccessControlService {
  /**
   * Get current day of week as enum value
   */
  private static getCurrentDayOfWeek(): DayOfWeek {
    const days: DayOfWeek[] = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
    return days[new Date().getDay()];
  }

  /**
   * Get current time in HH:MM format
   */
  private static getCurrentTime(): string {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
  }

  /**
   * Check if current time is within allowed access hours
   */
  private static isWithinAccessHours(startTime: string, endTime: string): boolean {
    const currentTime = this.getCurrentTime();
    const [currentHour, currentMin] = currentTime.split(':').map(Number);
    const [startHour, startMin] = startTime.split(':').map(Number);
    const [endHour, endMin] = endTime.split(':').map(Number);

    const currentMinutes = currentHour * 60 + currentMin;
    const startMinutes = startHour * 60 + startMin;
    const endMinutes = endHour * 60 + endMin;

    // Handle overnight access (e.g., 22:00 - 06:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  /**
   * Validate if a user can access a gym based on their membership and plan restrictions
   */
  static async validateAccess(userId: string, gymId: string): Promise<AccessValidationResult> {
    const currentDay = this.getCurrentDayOfWeek();
    const currentTime = this.getCurrentTime();

    // Find active membership
    const membership = await prisma.gymMembership.findFirst({
      where: {
        userId,
        gymId,
        status: 'ACTIVE',
        startDate: { lte: new Date() },
        endDate: { gte: new Date() },
      },
      include: {
        plan: true,
      },
    });

    const membershipCheck = validateMembershipAccess(membership ?? null);
    if (!membershipCheck.valid) {
      return {
        allowed: false,
        reason: membershipCheck.message,
        restrictions: {
          hasTimeRestriction: membership?.plan?.hasTimeRestriction ?? false,
          currentTime,
          currentDay,
        },
        ...(membership && {
          membership: {
            id: membership.id,
            planName: membership.plan.name,
            startDate: membership.startDate,
            endDate: membership.endDate,
          },
        }),
      };
    }

    // membership is guaranteed non-null here — validateMembershipAccess returned valid
    const m = membership!;
    const plan = m.plan;



    // Check time-based restrictions
    if (plan.hasTimeRestriction) {
      // Check if current day is allowed
      if (plan.accessDays && !plan.accessDays.includes(currentDay)) {
        return {
          allowed: false,
          reason: `Access not allowed on ${currentDay}. Your plan allows access on: ${plan.accessDays.join(', ')}`,
          membership: {
            id: m.id,
            planName: plan.name,
            startDate: m.startDate,
            endDate: m.endDate,
          },
          restrictions: {
            hasTimeRestriction: true,
            accessStartTime: plan.accessStartTime || undefined,
            accessEndTime: plan.accessEndTime || undefined,
            accessDays: plan.accessDays,
            currentTime,
            currentDay,
          },
        };
      }

      // Check if current time is within allowed hours
      if (plan.accessStartTime && plan.accessEndTime) {
        if (!this.isWithinAccessHours(plan.accessStartTime, plan.accessEndTime)) {
          return {
            allowed: false,
            reason: `Access only allowed between ${plan.accessStartTime} and ${plan.accessEndTime}. Current time: ${currentTime}`,
            membership: {
              id: m.id,
              planName: plan.name,
              startDate: m.startDate,
              endDate: m.endDate,
            },
            restrictions: {
              hasTimeRestriction: true,
              accessStartTime: plan.accessStartTime,
              accessEndTime: plan.accessEndTime,
              accessDays: plan.accessDays,
              currentTime,
              currentDay,
            },
          };
        }
      }
    }

    // Access granted!
    return {
      allowed: true,
      membership: {
        id: m.id,
        planName: plan.name,
        startDate: m.startDate,
        endDate: m.endDate,
      },
      restrictions: {
        hasTimeRestriction: plan.hasTimeRestriction,
        accessStartTime: plan.accessStartTime || undefined,
        accessEndTime: plan.accessEndTime || undefined,
        accessDays: plan.accessDays,
        currentTime,
        currentDay,
      },
    };
  }

  /**
   * Validate access and log the attempt
   */
  static async validateAndLogAccess(
    userId: string,
    gymId: string,
    doorSystemId: string,
    deviceInfo?: string
  ): Promise<AccessValidationResult> {
    const result = await this.validateAccess(userId, gymId);

    // Get door system to determine method
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
    });

    if (doorSystem) {
      // Log the access attempt
      await prisma.doorAccessLog.create({
        data: {
          doorSystemId,
          userId,
          accessGranted: result.allowed,
          method: doorSystem.type,
          deviceInfo,
        },
      });
    }

    return result;
  }

  /**
   * Get user's access schedule for a gym
   */
  static async getUserAccessSchedule(userId: string, gymId: string) {
    const membership = await prisma.gymMembership.findFirst({
      where: {
        userId,
        gymId,
        status: 'ACTIVE',
      },
      include: {
        plan: true,
        gym: {
          select: {
            name: true,
            address: true,
          },
        },
      },
    });

    if (!membership) {
      return null;
    }

    const plan = membership.plan;

    return {
      gym: membership.gym,
      membership: {
        id: membership.id,
        startDate: membership.startDate,
        endDate: membership.endDate,
        status: membership.status,
      },
      plan: {
        id: plan.id,
        name: plan.name,
        planType: plan.planType,
      },
      accessSchedule: {
        hasTimeRestriction: plan.hasTimeRestriction,
        accessStartTime: plan.accessStartTime,
        accessEndTime: plan.accessEndTime,
        accessDays: plan.accessDays,
      },
      isCurrentlyAccessible: (await this.validateAccess(userId, gymId)).allowed,
    };
  }

  /**
   * Get upcoming access windows for a user
   */
  static async getUpcomingAccessWindows(userId: string, gymId: string, days: number = 7) {
    const schedule = await this.getUserAccessSchedule(userId, gymId);

    if (!schedule) {
      return [];
    }

    if (!schedule.accessSchedule.hasTimeRestriction) {
      // Full access - return all days
      const windows = [];
      const startDate = new Date();

      for (let i = 0; i < days; i++) {
        const date = new Date(startDate);
        date.setDate(date.getDate() + i);
        windows.push({
          date: date.toISOString().split('T')[0],
          dayOfWeek: this.getDayName(date.getDay()),
          accessStart: '00:00',
          accessEnd: '23:59',
          isFullDay: true,
        });
      }

      return windows;
    }

    // Time-restricted access
    const windows = [];
    const startDate = new Date();
    const dayMapping: Record<number, DayOfWeek> = {
      0: 'SUNDAY',
      1: 'MONDAY',
      2: 'TUESDAY',
      3: 'WEDNESDAY',
      4: 'THURSDAY',
      5: 'FRIDAY',
      6: 'SATURDAY',
    };

    for (let i = 0; i < days; i++) {
      const date = new Date(startDate);
      date.setDate(date.getDate() + i);
      const dayOfWeek = dayMapping[date.getDay()];

      if (schedule.accessSchedule.accessDays?.includes(dayOfWeek)) {
        windows.push({
          date: date.toISOString().split('T')[0],
          dayOfWeek: this.getDayName(date.getDay()),
          accessStart: schedule.accessSchedule.accessStartTime || '00:00',
          accessEnd: schedule.accessSchedule.accessEndTime || '23:59',
          isFullDay: false,
        });
      }
    }

    return windows;
  }

  private static getDayName(dayIndex: number): string {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[dayIndex];
  }
}

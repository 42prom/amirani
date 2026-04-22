import prisma from '../../lib/prisma';
import { Role, SubscriptionStatus } from '@prisma/client';
import { hasGymAccess, isBranchAdminOf } from '../memberships/membership-utils';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import config from '../../config/env';
import logger from '../../lib/logger';
import {
  validateRequired,
  validateEmail,
  combineValidations,
  sanitize,
} from '../../utils/validation';

// ─── Simple In-Memory Cache for Occupancy Stats ─────────────────────────────

interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}

const statsCache = new Map<string, CacheEntry<unknown>>();

const CACHE_TTL_MS = 30 * 1000; // 30 seconds TTL

function getCached<T>(key: string): T | null {
  const entry = statsCache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    statsCache.delete(key);
    return null;
  }
  return entry.data as T;
}

function setCache<T>(key: string, data: T, ttlMs: number = CACHE_TTL_MS): void {
  statsCache.set(key, {
    data,
    expiresAt: Date.now() + ttlMs,
  });
}

// ─── Stats Response Types ───────────────────────────────────────────────────

export interface TrendData {
  count: number;
  previousCount: number;
  growthRate: number; // percentage
}

export interface BranchStatsResponse {
  activeSubscriptions: number;
  registeredCustomers: number;
  currentHallOccupancy: number;
  trainersCount: number;
  trends: {
    daily: {
      attendance: TrendData;
      checkIns: number;
      retentionRate: number;
      growthRate: number;
    };
    weekly: {
      attendance: TrendData;
      checkIns: number;
      retentionRate: number;
      growthRate: number;
    };
    monthly: {
      attendance: TrendData;
      checkIns: number;
      retentionRate: number;
      growthRate: number;
    };
    custom?: {
      attendance: TrendData;
      checkIns: number;
      retentionRate: number;
      growthRate: number;
    };
  };
}

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class GymValidationError extends Error {
  constructor(
    message: string,
    public details: { field: string; message: string }[]
  ) {
    super(message);
    this.name = 'GymValidationError';
  }
}

export class GymNotFoundError extends Error {
  constructor(public resource: string = 'Gym') {
    super(`${resource} not found`);
    this.name = 'GymNotFoundError';
  }
}

export class GymAccessDeniedError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'GymAccessDeniedError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class GymService {
  /**
   * Create a new gym (Super Admin only)
   */
  static async create(data: {
    name: string;
    address: string;
    city: string;
    country: string;
    ownerId: string;
    phone?: string;
    email?: string;
    description?: string;
  }) {
    // Validate input
    const validation = combineValidations(
      validateRequired(data.name, 'name', { minLength: 2, maxLength: 100 }),
      validateRequired(data.address, 'address', { minLength: 5, maxLength: 200 }),
      validateRequired(data.city, 'city', { minLength: 2, maxLength: 100 }),
      validateRequired(data.country, 'country', { minLength: 2, maxLength: 100 }),
      validateRequired(data.ownerId, 'ownerId')
    );

    if (!validation.valid) {
      throw new GymValidationError('Validation failed', validation.errors);
    }

    // Verify owner exists and is a GYM_OWNER
    const owner = await prisma.user.findUnique({
      where: { id: data.ownerId },
    });

    if (!owner) {
      throw new GymNotFoundError('Owner');
    }

    if (owner.role !== Role.GYM_OWNER) {
      throw new GymValidationError('Invalid owner role', [
        { field: 'ownerId', message: 'User must have GYM_OWNER role to own a gym' }
      ]);
    }

    return prisma.gym.create({
      data: {
        name: data.name,
        address: data.address,
        city: data.city,
        country: data.country,
        ownerId: data.ownerId,
        phone: data.phone,
        email: data.email,
        description: data.description,
      },
      include: {
        owner: {
          select: {
            id: true,
            email: true,
            fullName: true,
          },
        },
        branches: true,
      },
    });
  }

  /**
   * Get all gyms (Super Admin) or owned gyms (Gym Owner)
   */
  static async findAll(userId: string, role: Role, managedGymId?: string | null) {
    let where: any = { ownerId: userId, deletedAt: null };
    
    if (role === Role.SUPER_ADMIN) {
      where = { deletedAt: null };
    } else if (role === Role.BRANCH_ADMIN && managedGymId) {
      where = { id: managedGymId, deletedAt: null };
    }

    return prisma.gym.findMany({
      where,
      include: {
        owner: {
          select: {
            id: true,
            email: true,
            fullName: true,
          },
        },
        _count: {
          select: {
            memberships: true,
            trainers: true,
            equipment: true,
          },
        },
        branches: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Get gym by ID with full details
   */
  static async findById(gymId: string, userId: string, role: Role, managedGymId?: string | null) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
      include: {
        owner: {
          select: {
            id: true,
            email: true,
            fullName: true,
          },
        },
        trainers: {
          include: {
            user: {
              select: {
                id: true,
                email: true,
                fullName: true,
                avatarUrl: true,
              },
            },
          },
        },
        subscriptionPlans: true,
        _count: {
          select: {
            memberships: true,
            equipment: true,
            attendances: true,
          },
        },
        branches: true,
      },
    });

    if (!gym) {
      throw new GymNotFoundError();
    }

    // Check access permission
    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
    
    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new GymAccessDeniedError();
    }

    // ─── Staff Aggregation & Fallback Logic ───────────────────────────────────
    
    // 1. Get Branch Admins who are not explicitly in the trainers list
    const trainers = (gym as any).trainers || [];
    const explicitTrainerUserIds = trainers
      .map((t: any) => t.userId)
      .filter((id: string | null): id is string => !!id);

    const admins = await prisma.user.findMany({
      where: {
        managedGymId: gymId,
        role: Role.BRANCH_ADMIN,
        id: { notIn: explicitTrainerUserIds }
      },
      select: {
        id: true,
        fullName: true,
        avatarUrl: true,
        email: true,
      }
    });

    // 2. Map trainers to include fallback logic (User profile is source of truth)
    const mappedTrainers = trainers.map((t: any) => ({
      ...t,
      fullName: t.user?.fullName || t.fullName,
      avatarUrl: t.user?.avatarUrl || t.avatarUrl,
    }));

    // 3. Map admins to Trainer-like structures for UI compatibility
    const mappedAdmins = admins.map(a => ({
      id: a.id,
      fullName: a.fullName,
      avatarUrl: a.avatarUrl,
      isAvailable: true,
      specialization: 'Branch Staff',
      bio: '',
      userId: a.id,
      gymId: gymId,
    }));

    // Replace the trainers list in the gym object for the response
    (gym as any).trainers = [...mappedTrainers, ...mappedAdmins];

    return gym;
  }

  /**
   * Update gym details
   */
  static async update(
    gymId: string,
    userId: string,
    role: Role,
    data: {
      name?: string;
      address?: string;
      city?: string;
      country?: string;
      phone?: string;
      email?: string;
      description?: string;
      logoUrl?: string;
      isActive?: boolean;
      registrationRequirements?: any;
      themeColor?: string;
      welcomeMessage?: string;
    },
    managedGymId?: string | null
  ) {
    // Check ownership
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) {
      throw new GymNotFoundError();
    }

    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new GymAccessDeniedError();
    }

    return prisma.gym.update({
      where: { id: gymId },
      data,
      include: {
        owner: {
          select: {
            id: true,
            email: true,
            fullName: true,
          },
        },
      },
    });
  }

  /**
   * Delete gym
   */
  static async delete(gymId: string) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) {
      throw new GymNotFoundError();
    }

    // Clear managedGymId from users who are branch admins of this gym
    await prisma.user.updateMany({
      where: { managedGymId: gymId },
      data: { managedGymId: null },
    });

    return prisma.gym.update({
      where: { id: gymId },
      data: { deletedAt: new Date(), isActive: false }
    });
  }

  /**
   * Get gym statistics with trends and caching
   *
   * Returns branch-scoped stats:
   * - activeSubscriptions: count of active memberships
   * - registeredCustomers: total customers assigned to branch
   * - currentHallOccupancy: derived from attendance (check-in without check-out)
   * - trainersCount: branch trainers only
   *
   * Trend metrics include:
   * - Attendance count with growth rate
   * - Check-ins
   * - Retention rate
   * - Growth rate %
   *
   * BRANCH_ADMIN: Strictly branch filtered, no financial data
   */
  static async getStats(gymId: string, userId: string, role: Role, managedGymId?: string | null): Promise<BranchStatsResponse> {
    try {
      const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) {
      throw new GymNotFoundError();
    }

    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new GymAccessDeniedError();
    }

    // Check cache for occupancy (short TTL)
    const occupancyCacheKey = `occupancy:${gymId}`;
    let currentHallOccupancy = getCached<number>(occupancyCacheKey);

    // Date calculations
    const now = new Date();
    const todayStart = new Date(now);
    todayStart.setHours(0, 0, 0, 0);

    const yesterdayStart = new Date(todayStart);
    yesterdayStart.setDate(yesterdayStart.getDate() - 1);

    const weekStart = new Date(todayStart);
    weekStart.setDate(weekStart.getDate() - 7);

    const previousWeekStart = new Date(weekStart);
    previousWeekStart.setDate(previousWeekStart.getDate() - 7);

    const monthStart = new Date(todayStart);
    monthStart.setDate(monthStart.getDate() - 30);

    const previousMonthStart = new Date(monthStart);
    previousMonthStart.setDate(previousMonthStart.getDate() - 30);

    // Parallel queries for all stats
    const [
      activeSubscriptions,
      registeredCustomers,
      trainersCount,
      // Occupancy (if not cached)
      occupancyFromDb,
      // Today's stats
      todayAttendance,
      yesterdayAttendance,
      todayCheckIns,
      // Weekly stats
      weeklyAttendance,
      previousWeekAttendance,
      weeklyCheckIns,
      // Monthly stats
      monthlyAttendance,
      previousMonthAttendance,
      monthlyCheckIns,
      // Retention data
      uniqueMembersLastMonth,
      returningMembersThisMonth,
    ] = await Promise.all([
      // Active subscriptions (ACTIVE status only)
      prisma.gymMembership.count({
        where: { gymId, status: SubscriptionStatus.ACTIVE }
      }),
      // Registered customers (all memberships for this branch)
      prisma.gymMembership.count({ where: { gymId } }),
      // Trainers count
      prisma.trainerProfile.count({ where: { gymId } }),
      // Current hall occupancy (check-in without check-out)
      currentHallOccupancy !== null
        ? Promise.resolve(currentHallOccupancy)
        : prisma.attendance.count({
            where: {
              gymId,
              checkOut: null,
              checkIn: { gte: todayStart }, // Only count today's check-ins without checkout
            },
          }),
      // Daily attendance
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: todayStart } }
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: yesterdayStart, lt: todayStart } }
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: todayStart } }
      }),
      // Weekly attendance
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: weekStart } }
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: previousWeekStart, lt: weekStart } }
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: weekStart } }
      }),
      // Monthly attendance
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: monthStart } }
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: previousMonthStart, lt: monthStart } }
      }),
      prisma.attendance.count({
        where: { gymId, checkIn: { gte: monthStart } }
      }),
      // Unique members last month (for retention calculation)
      prisma.attendance.groupBy({
        by: ['userId'],
        where: { gymId, checkIn: { gte: previousMonthStart, lt: monthStart } },
      }).then(result => result.length),
      // Returning members (visited both this month and last)
      prisma.$queryRaw<{ count: bigint }[]>`
        SELECT COUNT(DISTINCT a1."userId") as count
        FROM attendances a1
        WHERE a1."gymId" = ${gymId}
          AND a1."checkIn" >= ${monthStart}
          AND EXISTS (
            SELECT 1 FROM attendances a2
            WHERE a2."gymId" = ${gymId}
              AND a2."userId" = a1."userId"
              AND a2."checkIn" >= ${previousMonthStart}
              AND a2."checkIn" < ${monthStart}
          )
      `.then(result => GymService.safeNumber(result[0]?.count)),
    ]);

    // Cache occupancy if fetched from DB
    if (currentHallOccupancy === null) {
      currentHallOccupancy = occupancyFromDb as number;
      setCache(occupancyCacheKey, currentHallOccupancy, CACHE_TTL_MS);
    }

    // Calculate growth rates
    const calcGrowthRate = (current: number, previous: number): number => {
      if (previous === 0) return current > 0 ? 100 : 0;
      return Math.round(((current - previous) / previous) * 100 * 10) / 10;
    };

    // Calculate retention rate
    const calcRetentionRate = (returning: number, previousUnique: number): number => {
      if (previousUnique === 0) return 0;
      return Math.round((returning / previousUnique) * 100 * 10) / 10;
    };

    const dailyGrowthRate = calcGrowthRate(todayAttendance, yesterdayAttendance);
    const weeklyGrowthRate = calcGrowthRate(weeklyAttendance, previousWeekAttendance);
    const monthlyGrowthRate = calcGrowthRate(monthlyAttendance, previousMonthAttendance);
    const retentionRate = calcRetentionRate(returningMembersThisMonth, uniqueMembersLastMonth);

    return {
      activeSubscriptions,
      registeredCustomers,
      currentHallOccupancy,
      trainersCount,
      trends: {
        daily: {
          attendance: {
            count: todayAttendance,
            previousCount: yesterdayAttendance,
            growthRate: dailyGrowthRate,
          },
          checkIns: todayCheckIns,
          retentionRate, // Monthly retention shown in all views
          growthRate: dailyGrowthRate,
        },
        weekly: {
          attendance: {
            count: weeklyAttendance,
            previousCount: previousWeekAttendance,
            growthRate: weeklyGrowthRate,
          },
          checkIns: weeklyCheckIns,
          retentionRate,
          growthRate: weeklyGrowthRate,
        },
        monthly: {
          attendance: {
            count: monthlyAttendance,
            previousCount: previousMonthAttendance,
            growthRate: monthlyGrowthRate,
          },
          checkIns: monthlyCheckIns,
          retentionRate,
          growthRate: monthlyGrowthRate,
        },
      },
    };
    } catch (error: any) {
      logger.error('[GymService] Critical Stats Error', { gymId, error });
      throw new Error(`Analytics Engine Failure: ${error.message}`);
    }
  }

  /**
   * Get or generate a stable registration code for the gym.
   * Returns QR content string encoding amirani://register?gymId=...&code=...
   */
  static async getRegistrationQr(gymId: string, userId: string, role: Role, managedGymId?: string | null) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) throw new GymNotFoundError();

    if (!hasGymAccess(role, gym.ownerId, userId, gym.id, managedGymId)) {
      throw new GymAccessDeniedError();
    }

    // Generate a stable code if not already set
    let code = gym.registrationCode;
    if (!code) {
      code = crypto.randomBytes(12).toString('hex'); // 24-char hex string
      await prisma.gym.update({
        where: { id: gymId },
        data: { registrationCode: code },
      });
    }

    const qrContent = `amirani://register?gymId=${gymId}&code=${code}`;
    return { registrationCode: code, qrContent, gymId, gymName: gym.name };
  }

  /**
   * Get public gym info for registration (No auth needed)
   */
  static async getPublicRegistrationInfo(gymId: string) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
      select: {
        id: true,
        name: true,
        registrationRequirements: true,
      },
    });

    if (!gym) throw new GymNotFoundError();

    return {
      id: gym.id,
      name: gym.name,
      requirements: gym.registrationRequirements || {},
    };
  }

  // TODO(cleanup): Dead method — registration requirements are updated via GymService.update()
  // which is called by PATCH /gyms/:id. Remove once PATCH /gyms/:id/registration-config is deleted.
  //
  // static async updateRegistrationConfig(
  //   gymId: string, userId: string, role: Role,
  //   requirements: Record<string, boolean>, managedGymId?: string | null
  // ) {
  //   const gym = await prisma.gym.findUnique({ where: { id: gymId } });
  //   if (!gym) throw new GymNotFoundError();
  //   const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
  //   if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
  //     throw new GymAccessDeniedError();
  //   }
  //   return prisma.gym.update({
  //     where: { id: gymId },
  //     data: { registrationRequirements: requirements },
  //     select: { id: true, registrationRequirements: true },
  //   });
  // }

  /**
   * Self-register a member via QR code scan.
   * Public endpoint — validates registrationCode then creates membership.
   */
  static async selfRegister(gymId: string, code: string, data: {
    fullName: string;
    email: string;
    password: string;
    dateOfBirth?: string;
    personalNumber?: string;
    phoneNumber?: string;
    address?: string;
    healthInfo?: string;
    selfiePhotoUrl?: string;
    idPhotoUrl?: string;
  }) {
    // Validate code
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
      select: {
        id: true,
        name: true,
        registrationCode: true,
        registrationRequirements: true,
        isActive: true,
      },
    });

    if (!gym) throw new GymNotFoundError();
    if (!gym.isActive) throw new Error('This gym is not currently accepting registrations');
    if (gym.registrationCode !== code) throw new Error('Invalid registration code');

    // Check if user already exists
    const userEmail = data.email?.toLowerCase();
    const existing = userEmail ? await prisma.user.findUnique({ where: { email: userEmail } }) : null;

    // Validate required fields (account for existing user's profile data)
    const reqs: Record<string, boolean> = (gym.registrationRequirements as any) || {};
    if (reqs.dateOfBirth && !data.dateOfBirth && !existing?.dob) throw new Error('Date of birth is required');
    if (reqs.personalNumber && !data.personalNumber && !existing?.personalNumber) throw new Error('Personal/ID number is required');
    if (reqs.phoneNumber && !data.phoneNumber && !existing?.phoneNumber) throw new Error('Phone number is required');
    if (reqs.address && !data.address && !existing?.address) throw new Error('Address is required');
    if (reqs.healthInfo && !data.healthInfo && !existing?.medicalConditions && !existing?.noMedicalConditions) {
      throw new Error('Health information is required');
    }
    if (reqs.selfiePhoto && !data.selfiePhotoUrl && !existing?.avatarUrl) {
      throw new Error('Selfie photo is required for registration at this gym');
    }
    if (reqs.idPhoto && !data.idPhotoUrl && !existing?.idPhotoUrl) {
      throw new Error('ID / Passport photo is required for registration at this gym');
    }

    if (existing) {
      // Check if already a member
      const existingMembership = await prisma.gymMembership.findFirst({
        where: { userId: existing.id, gymId },
      });

      if (existingMembership) {
        // If already active or pending, don't allow duplicate registration
        if (existingMembership.status === 'ACTIVE' || existingMembership.status === 'PENDING') {
          throw new Error('You are already registered at this gym');
        }

        // Reactivate CANCELLED or EXPIRED membership.
        // If the existing subscription is still within its paid window, restore to ACTIVE.
        // If it is expired, set to PENDING only — do NOT auto-extend the end date.
        // A Branch Admin must manually activate with a chosen plan and payment before
        // the member can enter. This prevents free 30-day extensions on re-scan.
        const now = new Date();
        const hasValidSubscription = existingMembership.endDate > now;

        const updatedMembership = await prisma.gymMembership.update({
          where: { id: existingMembership.id },
          data: {
            status: hasValidSubscription ? 'ACTIVE' : 'PENDING',
            updatedAt: now,
            // Never extend endDate automatically — staff must activate with plan selection.
          },
        });

        return {
          userId: existing.id,
          membershipId: updatedMembership.id,
          isNewUser: false,
          gymName: gym.name,
          reActivated: hasValidSubscription,
          // Signal to mobile that staff action is required before entry is possible
          requiresStaffActivation: !hasValidSubscription,
        };
      }

      // Update existing user's profile with any new registration data
      await prisma.user.update({
        where: { id: existing.id },
        data: {
          fullName: data.fullName,
          phoneNumber: data.phoneNumber ?? undefined,
          avatarUrl: data.selfiePhotoUrl ?? undefined,
          dob: data.dateOfBirth ?? undefined,
          personalNumber: data.personalNumber ?? undefined,
          address: data.address ?? undefined,
          medicalConditions: data.healthInfo ?? undefined,
          idPhotoUrl: data.idPhotoUrl ?? undefined,
        },
      });

      // Create membership for existing user (no plan required for self-registration)
      // Find the first available plan to satisfy the Prisma required field.
      const firstPlan = await prisma.subscriptionPlan.findFirst({
        where: { gymId, isActive: true },
        select: { id: true, durationValue: true, durationUnit: true },
      });

      if (!firstPlan) throw new Error('This gym does not have any active subscription plans');

      // Create PENDING membership with the plan's real duration — no hardcoded 30 days.
      // Staff must activate this membership before the member can enter.
      const { calcMembershipEndDate } = await import('../memberships/membership-utils');
      const pendingStart = new Date();
      const pendingEnd   = calcMembershipEndDate(
        pendingStart,
        firstPlan.durationValue,
        firstPlan.durationUnit,
      );

      const membership = await prisma.gymMembership.create({
        data: {
          userId: existing.id,
          gymId,
          planId: firstPlan.id,
          status: 'PENDING',
          startDate: pendingStart,
          endDate: pendingEnd,
          autoRenew: false,
        },
      });
      return {
        userId: existing.id,
        membershipId: membership.id,
        isNewUser: false,
        gymName: gym.name,
        requiresStaffActivation: true,
      };
    }

    // Create new user
    const hashedPassword = await bcrypt.hash(data.password, 12);

    const user = await prisma.user.create({
      data: {
        fullName: data.fullName,
        email: data.email,
        password: hashedPassword,
        role: 'GYM_MEMBER',
        phoneNumber: data.phoneNumber,
        avatarUrl: data.selfiePhotoUrl,
        dob: data.dateOfBirth,
        personalNumber: data.personalNumber,
        address: data.address,
        medicalConditions: data.healthInfo,
        idPhotoUrl: data.idPhotoUrl,
      },
    });

    // Create membership (no plan required for self-registration)
    // Find the first available plan to satisfy the Prisma required field.
    const firstPlan = await prisma.subscriptionPlan.findFirst({
      where: { gymId, isActive: true },
      select: { id: true }
    });

    if (!firstPlan) throw new Error('This gym does not have any active subscription plans');

    const membership = await prisma.gymMembership.create({
      data: {
        userId: user.id,
        gymId,
        planId: firstPlan.id,
        status: 'PENDING',
        startDate: new Date(),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        autoRenew: false,
      },
    });

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, role: user.role, managedGymId: null },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn as jwt.SignOptions['expiresIn'] }
    );

    return {
      userId: user.id,
      membershipId: membership.id,
      isNewUser: true,
      gymName: gym.name,
      token,
      user: { id: user.id, fullName: user.fullName, email: user.email, role: user.role },
    };
  }

  /**
   * Get real-time hall occupancy (cached with short TTL)
   */
  static async getOccupancy(gymId: string): Promise<number> {
    const cacheKey = `occupancy:${gymId}`;
    const cached = getCached<number>(cacheKey);

    if (cached !== null) {
      return cached;
    }

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const occupancy = await prisma.attendance.count({
      where: {
        gymId,
        checkOut: null,
        checkIn: { gte: todayStart },
      },
    });

    setCache(cacheKey, occupancy, CACHE_TTL_MS);
    return occupancy;
  }

  /**
   * Safe casting for Prisma queryRaw results that may contain BigInt
   */
  private static safeNumber(val: any): number {
    if (val === null || val === undefined) return 0;
    if (typeof val === 'bigint') return Number(val);
    if (typeof val === 'string') return parseFloat(val) || 0;
    return Number(val) || 0;
  }
}


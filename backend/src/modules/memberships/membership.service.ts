import prisma from '../../lib/prisma';
import { Role, SubscriptionStatus, NotificationType } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { NotificationService } from '../notifications/notification.service';
import { calcMembershipEndDate, hasGymAccess, isBranchAdminOf } from './membership-utils';
import { AuditLogService, AuditAction } from '../audit/audit.service';
import logger from '../../lib/logger';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class MembershipValidationError extends Error {
  constructor(
    message: string,
    public details: { field: string; message: string }[]
  ) {
    super(message);
    this.name = 'MembershipValidationError';
  }
}

export class MembershipNotFoundError extends Error {
  constructor(public resource: string = 'Membership') {
    super(`${resource} not found`);
    this.name = 'MembershipNotFoundError';
  }
}

export class MembershipAccessDeniedError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'MembershipAccessDeniedError';
  }
}

// ─── Request/Response Types ──────────────────────────────────────────────────

export interface ManualRegistrationRequest {
  fullName: string;
  email: string;
  phoneNumber?: string;
  subscriptionPlanId: string;
  startDate?: string; // ISO date string
  sendNotification?: boolean;
  dateOfBirth?: string;
  personalNumber?: string;
  address?: string;
  healthInfo?: string;
  selfiePhoto?: string;
  idPhoto?: string;
}

export interface ManualActivationRequest {
  memberId: string;
  planId: string;
  durationValue?: number; // Override plan duration amount
  durationUnit?: string;  // Override plan duration unit ('days', 'months')
  startDate?: string; // ISO date string, defaults to now
}

export interface ManualRegistrationResponse {
  user: {
    id: string;
    email: string;
    fullName: string;
    phoneNumber: string | null;
    avatarUrl: string | null;
  };
  membership: {
    id: string;
    status: SubscriptionStatus;
    startDate: Date;
    endDate: Date;
    plan: {
      id: string;
      name: string;
    };
  };
}

export interface ManualActivationResponse {
  membership: {
    id: string;
    status: SubscriptionStatus;
    startDate: Date;
    endDate: Date;
    previousEndDate?: Date;
    plan: {
      id: string;
      name: string;
    };
  };
  user: {
    id: string;
    fullName: string;
    email: string;
  };
}

export class MembershipService {
  /**
   * Get all members of a gym
   */
  static async getGymMembers(gymId: string, userId: string, role: Role, managedGymId?: string | null) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) {
      throw new Error('Gym not found');
    }

    if (!hasGymAccess(role, gym.ownerId, userId, gym.id, managedGymId)) {
      throw new Error('Access denied');
    }

    return prisma.gymMembership.findMany({
      where: { gymId },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            fullName: true,
            phoneNumber: true,
            avatarUrl: true,
            idPhotoUrl: true,
            dob: true,
            personalNumber: true,
            address: true,
            medicalConditions: true,
            noMedicalConditions: true,
            weightHistory: {
              orderBy: { date: 'desc' },
              take: 20
            },
          },
        },
        plan: {
          select: {
            id: true,
            name: true,
            price: true,
          },
        },
        trainer: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
              },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Assign a trainer to a member
   */
  static async assignTrainer(
    membershipId: string,
    trainerId: string,
    userId: string,
    role: Role,
    managedGymId?: string | null
  ) {
    const membership = await prisma.gymMembership.findUnique({
      where: { id: membershipId },
      include: { gym: true },
    });

    if (!membership) {
      throw new Error('Membership not found');
    }

    if (!hasGymAccess(role, membership.gym.ownerId, userId, membership.gymId, managedGymId)) {
      throw new Error('Access denied');
    }

    // Verify trainer belongs to the same gym
    const trainer = await prisma.trainerProfile.findUnique({
      where: { id: trainerId },
    });

    if (!trainer || trainer.gymId !== membership.gymId) {
      throw new Error('Trainer not found in this gym');
    }

    return prisma.gymMembership.update({
      where: { id: membershipId },
      data: { trainerId },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            fullName: true,
          },
        },
        trainer: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
              },
            },
          },
        },
      },
    });
  }

  /**
   * Update membership status
   */
  static async updateStatus(
    membershipId: string,
    status: SubscriptionStatus,
    userId: string,
    role: Role,
    managedGymId?: string | null
  ) {
    const membership = await prisma.gymMembership.findUnique({
      where: { id: membershipId },
      include: { gym: true },
    });

    if (!membership) {
      throw new Error('Membership not found');
    }

    if (!hasGymAccess(role, membership.gym.ownerId, userId, membership.gymId, managedGymId)) {
      throw new Error('Access denied');
    }

    const updated = await prisma.gymMembership.update({
      where: { id: membershipId },
      data: { status },
      include: {
        gym: { select: { name: true } },
        user: { select: { id: true } },
      },
    });

    // Send notification to member
    try {
      let title = 'Membership Update';
      let body = `Your membership status at ${updated.gym.name} is now ${status.toLowerCase()}.`;
      
      if (status === SubscriptionStatus.ACTIVE) {
        title = 'Membership Approved! 🎉';
        body = `Welcome! Your membership at ${updated.gym.name} is now active.`;
      } else if (status === SubscriptionStatus.CANCELLED) {
        title = 'Membership Cancelled';
        body = `Your membership at ${updated.gym.name} has been cancelled.`;
      }

      await NotificationService.send({
        userId: updated.userId,
        type: NotificationType.SYSTEM,
        title,
        body,
        data: {
          type: 'MEMBERSHIP_UPDATE',
          status: status,
          membershipId: updated.id,
          gymId: updated.gymId,
        },
      });
    } catch (err) {
      logger.warn('[MembershipService] Failed to send status update notification', { err });
    }

    return updated;
  }

  /**
   * Create subscription plan for a gym
   */
  static async createPlan(
    gymId: string,
    userId: string,
    role: Role,
    data: {
      name: string;
      description?: string;
      price: number;
      durationValue?: number;
      durationUnit?: string;
      features?: string[];
    },
    managedGymId?: string | null
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) {
      throw new Error('Gym not found');
    }

    if (!hasGymAccess(role, gym.ownerId, userId, gym.id, managedGymId)) {
      throw new Error('Access denied');
    }

    return prisma.subscriptionPlan.create({
      data: {
        gymId,
        name: data.name,
        description: data.description,
        price: data.price,
        durationValue: data.durationValue || 30,
        durationUnit: data.durationUnit || 'days',
        features: data.features || [],
      },
    });
  }

  /**
   * Manual membership creation (for Branch Managers)
   */
  static async createMembership(
    gymId: string,
    userId: string,
    requesterId: string,
    role: Role,
    data: {
      planId: string;
      startDate?: Date;
      endDate?: Date;
    },
    managedGymId?: string | null
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw new Error('Gym not found');

    if (!hasGymAccess(role, gym.ownerId, requesterId, gym.id, managedGymId)) {
      throw new Error('Access denied');
    }

    // Calculate end date if not provided
    let endDate = data.endDate;
    if (!endDate) {
      const plan = await prisma.subscriptionPlan.findUnique({ where: { id: data.planId } });
      if (!plan) throw new Error('Plan not found');
      
      const start = data.startDate ? new Date(data.startDate) : new Date();
      endDate = calcMembershipEndDate(start, plan.durationValue, plan.durationUnit);
    }

    return prisma.gymMembership.create({
      data: {
        gymId,
        userId,
        planId: data.planId,
        startDate: data.startDate || new Date(),
        endDate,
        status: 'ACTIVE',
      },
    });
  }

  /**
   * Get subscription plans for a gym
   */
  static async getGymPlans(gymId: string) {
    return prisma.subscriptionPlan.findMany({
      where: { gymId, isActive: true },
      orderBy: { price: 'asc' },
    });
  }

  /**
   * Update subscription plan
   */
  static async updatePlan(
    planId: string,
    userId: string,
    role: Role,
    data: {
      name?: string;
      description?: string;
      price?: number;
      durationValue?: number;
      durationUnit?: string;
      features?: string[];
      isActive?: boolean;
    },
    managedGymId?: string | null
  ) {
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: planId },
      include: { gym: true },
    });

    if (!plan) {
      throw new Error('Plan not found');
    }

    if (!hasGymAccess(role, plan.gym.ownerId, userId, plan.gym.id, managedGymId)) {
      throw new MembershipAccessDeniedError();
    }

    return prisma.subscriptionPlan.update({
      where: { id: planId },
      data,
    });
  }

  /**
   * Manual member registration by Branch Admin
   *
   * Creates a new user and assigns them a membership in a single transaction.
   * Auto-assigns branch_id from authenticated admin's managed gym.
   *
   * @param gymId - The gym/branch ID
   * @param adminId - The admin performing the action
   * @param role - Admin's role
   * @param data - Registration data
   */
  static async manualCreateMember(
    gymId: string,
    adminId: string,
    role: Role,
    data: ManualRegistrationRequest,
    managedGymId?: string | null
  ): Promise<ManualRegistrationResponse> {
    // Validate gym access
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new MembershipNotFoundError('Gym');
    }

    if (!hasGymAccess(role, gym.ownerId, adminId, gym.id, managedGymId)) {
      throw new MembershipAccessDeniedError();
    }

    // Validate required fields
    const errors: { field: string; message: string }[] = [];
    if (!data.fullName || data.fullName.trim().length < 2) {
      errors.push({ field: 'fullName', message: 'Full name is required (min 2 characters)' });
    }
    if (!data.email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) {
      errors.push({ field: 'email', message: 'Valid email is required' });
    }
    if (!data.subscriptionPlanId) {
      errors.push({ field: 'subscriptionPlanId', message: 'Subscription plan is required' });
    }
    if (errors.length > 0) {
      throw new MembershipValidationError('Validation failed', errors);
    }

    // Validate subscription plan exists and belongs to this gym
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: data.subscriptionPlanId },
    });
    if (!plan || plan.gymId !== gymId) {
      throw new MembershipValidationError('Invalid subscription plan', [
        { field: 'subscriptionPlanId', message: 'Subscription plan not found for this gym' }
      ]);
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: data.email.toLowerCase().trim() },
    });

    if (existingUser) {
      // Check if already a member of this gym (ignore expired/cancelled — allow re-enrollment)
      const existingMembership = await prisma.gymMembership.findFirst({
        where: {
          userId: existingUser.id,
          gymId,
          status: { not: { in: ['EXPIRED', 'CANCELLED'] } },
        },
      });

      if (existingMembership) {
        throw new MembershipValidationError('Member already exists', [
          { field: 'email', message: 'This user is already a member of this gym' }
        ]);
      }
    }

    // Calculate dates
    const startDate = data.startDate ? new Date(data.startDate) : new Date();
    const endDate = calcMembershipEndDate(startDate, plan.durationValue, plan.durationUnit);

    // Execute in transaction
    let tempPasswordPlain: string | null = null; // Set inside tx when a new user is created
    const result = await prisma.$transaction(async (tx) => {
      let user = existingUser;

      // Create user if doesn't exist
      if (!user) {
        // Generate a human-readable temporary password so the Branch Admin
        // can hand it to the member verbally or on paper.
        // Format: 3 uppercase letters + 3 digits + 3 uppercase letters (9 chars, no ambiguous chars)
        const charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        const rawTemp = Array.from({ length: 9 }, () =>
          charset[Math.floor(Math.random() * charset.length)]
        ).join('');
        tempPasswordPlain = rawTemp;
        const hashedTemp = await bcrypt.hash(rawTemp, 10);

        user = await tx.user.create({
          data: {
            email: data.email.toLowerCase().trim(),
            fullName: data.fullName.trim(),
            phoneNumber: data.phoneNumber?.trim() || null,
            password: hashedTemp,
            role: Role.GYM_MEMBER,
            isVerified: false,
            isActive: true,
            createdById: adminId,
            avatarUrl: data.selfiePhoto || null,
            idPhotoUrl: data.idPhoto || null,
            dob: data.dateOfBirth || null,
            address: data.address || null,
            medicalConditions: data.healthInfo || null,
            personalNumber: data.personalNumber || null,
          },
        });
      } else {
        // If user exists, update fields if they are provided but missing in the profile
        await tx.user.update({
          where: { id: user.id },
          data: {
            fullName: user.fullName || data.fullName.trim(),
            phoneNumber: user.phoneNumber || data.phoneNumber?.trim() || undefined,
            avatarUrl: user.avatarUrl || data.selfiePhoto || undefined,
            idPhotoUrl: user.idPhotoUrl || data.idPhoto || undefined,
            dob: user.dob || data.dateOfBirth || undefined,
            address: user.address || data.address || undefined,
            medicalConditions: user.medicalConditions || data.healthInfo || undefined,
            personalNumber: user.personalNumber || data.personalNumber || undefined,
          },
        });
      }

      // Create membership
      const membership = await tx.gymMembership.create({
        data: {
          userId: user.id,
          gymId,
          planId: data.subscriptionPlanId,
          startDate,
          endDate,
          status: SubscriptionStatus.ACTIVE,
          autoRenew: false,
        },
        include: {
          plan: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      return { user, membership };
    });

    AuditLogService.log(
      gymId, adminId, AuditAction.MEMBER_ADDED, 'GymMembership',
      `Manually registered member: ${data.fullName} (${data.email})`,
      result.membership.id,
      { targetUserId: result.user.id, planId: data.subscriptionPlanId, startDate: startDate.toISOString(), endDate: endDate.toISOString() }
    );

    // Fire welcome notification with temporary credentials (non-blocking).
    // The plaintext temp password is included so the member can log in on
    // first launch. isVerified=false prompts them to change it.
    // Falls back silently if email is not configured.
    if (tempPasswordPlain) {
      NotificationService.send({
        userId: result.user.id,
        type: 'SYSTEM_ALERT' as any,
        title: 'Welcome to the gym!',
        body: `Your account has been created. Temporary password: ${tempPasswordPlain} — please change it after your first login.`,
        channels: ['EMAIL'],
        data: { gymId, temporaryPassword: tempPasswordPlain },
      }).catch(() => { /* non-critical — email may not be configured */ });
    }

    return {
      user: {
        id: result.user.id,
        email: result.user.email,
        fullName: result.user.fullName,
        phoneNumber: result.user.phoneNumber,
        avatarUrl: result.user.avatarUrl,
      },
      // temporaryPassword is only present on first account creation.
      // Branch Admin should show this to the member so they can log in.
      // It is never stored in plaintext — only the bcrypt hash is persisted.
      ...(tempPasswordPlain ? { temporaryPassword: tempPasswordPlain } : {}),
      membership: {
        id: result.membership.id,
        status: result.membership.status,
        startDate: result.membership.startDate,
        endDate: result.membership.endDate,
        plan: result.membership.plan,
      },
    };
  }

  /**
   * Manual membership activation/renewal by Branch Admin
   *
   * Activates or renews an existing member's subscription.
   * Updates expiration date safely.
   *
   * @param gymId - The gym/branch ID
   * @param adminId - The admin performing the action
   * @param role - Admin's role
   * @param data - Activation data
   */
  static async manualActivateMember(
    gymId: string,
    adminId: string,
    role: Role,
    data: ManualActivationRequest,
    managedGymId?: string | null
  ): Promise<ManualActivationResponse> {
    // Validate gym access
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new MembershipNotFoundError('Gym');
    }

    if (!hasGymAccess(role, gym.ownerId, adminId, gym.id, managedGymId)) {
      throw new MembershipAccessDeniedError();
    }

    // Validate member exists
    const member = await prisma.user.findUnique({
      where: { id: data.memberId },
    });
    if (!member) {
      throw new MembershipNotFoundError('Member');
    }

    // Validate plan exists and belongs to this gym
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: data.planId },
    });
    if (!plan || plan.gymId !== gymId) {
      throw new MembershipValidationError('Invalid subscription plan', [
        { field: 'planId', message: 'Subscription plan not found for this gym' }
      ]);
    }

    // Check for existing membership — prefer non-terminal record for renewal/reactivation
    const existingMembership = await prisma.gymMembership.findFirst({
      where: {
        userId: data.memberId,
        gymId,
        status: { not: 'CANCELLED' },
      },
      orderBy: { createdAt: 'desc' },
    });

    // Calculate dates
    const startDate = data.startDate ? new Date(data.startDate) : new Date();
    const durationValue = data.durationValue || plan.durationValue;
    const durationUnit = data.durationUnit || plan.durationUnit;
    let endDate: Date;

    // If renewing an active membership, extend from current end date
    const baseDate = (existingMembership &&
        existingMembership.status === SubscriptionStatus.ACTIVE &&
        existingMembership.endDate > new Date()) 
        ? existingMembership.endDate 
        : startDate;

    endDate = calcMembershipEndDate(baseDate, durationValue, durationUnit);

    const previousEndDate = existingMembership?.endDate;

    // Execute in transaction
    const membership = await prisma.$transaction(async (tx) => {
      if (existingMembership) {
        // Update existing membership
        return tx.gymMembership.update({
          where: { id: existingMembership.id },
          data: {
            planId: data.planId,
            startDate: existingMembership.status === SubscriptionStatus.ACTIVE
              ? existingMembership.startDate
              : startDate,
            endDate,
            status: SubscriptionStatus.ACTIVE,
          },
          include: {
            plan: {
              select: {
                id: true,
                name: true,
              },
            },
            user: {
              select: {
                id: true,
                fullName: true,
                email: true,
              },
            },
          },
        });
      } else {
        // Create new membership
        return tx.gymMembership.create({
          data: {
            userId: data.memberId,
            gymId,
            planId: data.planId,
            startDate,
            endDate,
            status: SubscriptionStatus.ACTIVE,
            autoRenew: false,
          },
          include: {
            plan: {
              select: {
                id: true,
                name: true,
              },
            },
            user: {
              select: {
                id: true,
                fullName: true,
                email: true,
              },
            },
          },
        });
      }
    });

    AuditLogService.log(
      gymId, adminId, AuditAction.MEMBER_ACTIVATED, 'GymMembership',
      `${existingMembership ? 'Renewed' : 'Activated'} membership for member`,
      membership.id,
      { targetUserId: data.memberId, planId: data.planId, previousEndDate: previousEndDate?.toISOString(), newEndDate: endDate.toISOString(), durationAmount: durationValue, durationUnit },
    );

    // Send notification to member
    try {
      await NotificationService.send({
        userId: membership.userId,
        type: NotificationType.SYSTEM,
        title: 'Membership Activated! 🎉',
        body: `Your membership at ${gym.name} is now active until ${endDate.toLocaleDateString()}.`,
        data: {
          type: 'MEMBERSHIP_UPDATE',
          status: SubscriptionStatus.ACTIVE,
          membershipId: membership.id,
          gymId: gymId,
        },
      });
    } catch (err) {
      logger.warn('[MembershipService] Failed to send activation notification', { err });
    }

    return {
      membership: {
        id: membership.id,
        status: membership.status,
        startDate: membership.startDate,
        endDate: membership.endDate,
        previousEndDate,
        plan: membership.plan,
      },
      user: membership.user,
    };
  }

  /**
   * Search members by name or email (for activation modal dropdown)
   */
  static async searchMembers(
    gymId: string,
    adminId: string,
    role: Role,
    query: string,
    limit: number = 10,
    managedGymId?: string | null
  ) {
    // Validate gym access
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new MembershipNotFoundError('Gym');
    }

    if (!hasGymAccess(role, gym.ownerId, adminId, gym.id, managedGymId)) {
      throw new MembershipAccessDeniedError();
    }

    // Search users who are members of THIS specific gym only.
    // Previously filtered by gym.ownerId which leaked members from sibling
    // gyms owned by the same owner — a Branch Admin of Gym A could see
    // members of Gym B. Now scoped strictly to gymId.
    const searchTerm = query.trim().toLowerCase();

    return prisma.user.findMany({
      where: {
        OR: [
          { email: { contains: searchTerm, mode: 'insensitive' } },
          { fullName: { contains: searchTerm, mode: 'insensitive' } },
        ],
        role: { in: [Role.GYM_MEMBER, Role.HOME_USER, Role.TRAINER] },
        isActive: true,
        memberships: {
          some: {
            gymId,
          },
        },
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
        memberships: {
          where: { gymId },
          select: {
            id: true,
            status: true,
            endDate: true,
            plan: {
              select: {
                id: true,
                name: true,
              },
            },
          },
        },
      },
      take: limit,
      orderBy: { fullName: 'asc' },
    });
  }
  /**
   * Update member profile information by Branch Admin
   */
  static async updateMemberProfile(
    gymId: string,
    memberId: string,
    adminId: string,
    role: Role,
    data: {
      fullName?: string;
      phoneNumber?: string;
      personalNumber?: string;
      address?: string;
      dob?: string;
      gender?: string;
      height?: string;
      weight?: string;
      email?: string;
      idPhoto?: string;
      idPhotoUrl?: string;
      selfiePhoto?: string;
      avatarUrl?: string;
      medicalConditions?: string;
      noMedicalConditions?: boolean;
    },
    managedGymId?: string | null
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw new MembershipNotFoundError('Gym');

    if (!hasGymAccess(role, gym.ownerId, adminId, gym.id, managedGymId)) {
      throw new MembershipAccessDeniedError();
    }

    const membership = await prisma.gymMembership.findFirst({
      where: { gymId, userId: memberId },
    });
    if (!membership) {
      throw new MembershipNotFoundError('Member not found in this gym');
    }

    // Snapshot current photo URLs before the update so the audit log captures
    // exactly what changed — required for GDPR-compliant consent tracking.
    const currentUser = await prisma.user.findUnique({
      where: { id: memberId },
      select: { avatarUrl: true, idPhotoUrl: true },
    });

    const updateData: any = { ...data };

    // Map legacy/convenience keys to model fields
    if (data.idPhoto && !data.idPhotoUrl) {
      updateData.idPhotoUrl = data.idPhoto;
    }
    if (data.selfiePhoto && !data.avatarUrl) {
      updateData.avatarUrl = data.selfiePhoto;
    }

    // Remove non-model keys after mapping
    delete updateData.idPhoto;
    delete updateData.selfiePhoto;

    const updated = await prisma.user.update({
      where: { id: memberId },
      data: updateData,
    });

    // Log photo changes explicitly so there is a traceable audit trail
    // for any Branch Admin who updates a member's identity or avatar photo.
    const photoChanges: Record<string, { from: string | null; to: string | null }> = {};
    if (updateData.avatarUrl !== undefined && updateData.avatarUrl !== currentUser?.avatarUrl) {
      photoChanges.avatarUrl = { from: currentUser?.avatarUrl ?? null, to: updateData.avatarUrl };
    }
    if (updateData.idPhotoUrl !== undefined && updateData.idPhotoUrl !== currentUser?.idPhotoUrl) {
      photoChanges.idPhotoUrl = { from: currentUser?.idPhotoUrl ?? null, to: updateData.idPhotoUrl };
    }
    if (Object.keys(photoChanges).length > 0) {
      AuditLogService.log(
        gymId, adminId, AuditAction.MEMBER_UPDATED, 'User',
        `Admin updated member photo(s): ${Object.keys(photoChanges).join(', ')}`,
        memberId,
        { targetUserId: memberId, photoChanges },
      );
    } else if (Object.keys(updateData).length > 0) {
      AuditLogService.log(
        gymId, adminId, AuditAction.MEMBER_UPDATED, 'User',
        'Admin updated member profile',
        memberId,
        { targetUserId: memberId, fields: Object.keys(updateData) },
      );
    }

    return updated;
  }

  /**
   * Remove/Delete member from a gym by Branch Admin
   * Note: This usually just cancels their membership rather than deleting the User object,
   * since the User might belong to other gyms.
   */
  static async removeMemberFromGym(
    gymId: string,
    memberId: string,
    adminId: string,
    role: Role,
    managedGymId?: string | null
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw new MembershipNotFoundError('Gym');

    if (!hasGymAccess(role, gym.ownerId, adminId, gym.id, managedGymId)) {
      throw new MembershipAccessDeniedError();
    }

    const membership = await prisma.gymMembership.findFirst({
      where: { gymId, userId: memberId },
    });

    if (!membership) {
      throw new MembershipNotFoundError('Membership not found for this user in this gym');
    }

    // Actually delete the membership record to remove from the branch's CRM
    await prisma.gymMembership.deleteMany({
      where: { gymId, userId: memberId },
    });

    AuditLogService.log(
      gymId, adminId, AuditAction.MEMBER_REMOVED, 'GymMembership',
      'Member removed from gym by admin',
      undefined,
      { targetUserId: memberId }
    );

    return { success: true, message: 'Member removed from gym successfully' };
  }
}


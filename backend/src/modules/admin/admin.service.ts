import bcrypt from 'bcryptjs';
import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';
import { PlatformConfigService } from '../platform/platform-config.service';
import {
  validateEmail,
  validatePassword,
  validateRequired,
  combineValidations,
  sanitize,
} from '../../utils/validation';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class AdminValidationError extends Error {
  constructor(
    message: string,
    public details: { field: string; message: string }[]
  ) {
    super(message);
    this.name = 'AdminValidationError';
  }
}

export class AdminConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AdminConflictError';
  }
}

export class AdminNotFoundError extends Error {
  constructor(public resource: string) {
    super(`${resource} not found`);
    this.name = 'AdminNotFoundError';
  }
}

export class AdminAccessDeniedError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'AdminAccessDeniedError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class AdminService {
  /**
   * Create a Gym Owner account (Super Admin only)
   */
  static async createGymOwner(
    creatorId: string,
    data: {
      email: string;
      password: string;
      fullName: string;
      phoneNumber?: string;
    }
  ) {
    // Validate input
    const validation = combineValidations(
      validateEmail(data.email),
      validatePassword(data.password),
      validateRequired(data.fullName, 'fullName', { minLength: 2, maxLength: 100 })
    );

    if (!validation.valid) {
      throw new AdminValidationError('Validation failed', validation.errors);
    }

    const email = sanitize(data.email).toLowerCase();
    const fullName = sanitize(data.fullName);

    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      throw new AdminConflictError('Email already registered');
    }

    const hashedPassword = await bcrypt.hash(data.password, 12);

    // Read trial duration from PlatformConfig so Super Admin can adjust it
    // without a code deployment. Falls back to 14 days if config is missing.
    const platformConfig = await PlatformConfigService.getPlatformConfig();
    const trialDays = platformConfig.defaultTrialDays ?? 14;

    return prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        fullName,
        phoneNumber: data.phoneNumber,
        role: Role.GYM_OWNER,
        createdById: creatorId,
        isVerified: true, // Admin-created accounts are pre-verified
        saasSubscriptionStatus: 'TRIAL',
        saasTrialEndsAt: new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000),
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        role: true,
        phoneNumber: true,
        isVerified: true,
        saasSubscriptionStatus: true,
        saasTrialEndsAt: true,
        createdAt: true,
      },
    });
  }

  /**
   * Extend a Gym Owner's SaaS trial (Super Admin only)
   */
  static async extendSaaSTrial(targetId: string, days: number) {
    const user = await prisma.user.findUnique({
      where: { id: targetId },
    });

    if (!user || user.role !== Role.GYM_OWNER) {
      throw new AdminNotFoundError('Gym Owner');
    }

    const currentExpiry = user.saasTrialEndsAt || new Date();
    const newExpiry = new Date(currentExpiry);
    newExpiry.setDate(newExpiry.getDate() + days);

    return prisma.user.update({
      where: { id: targetId },
      data: {
        saasTrialEndsAt: newExpiry,
        saasSubscriptionStatus: 'TRIAL',
      },
      select: {
        id: true,
        fullName: true,
        saasSubscriptionStatus: true,
        saasTrialEndsAt: true,
      },
    });
  }

  /**
   * Create a Branch Administrator account (Gym Owner or Super Admin)
   */
  static async createBranchAdmin(
    creatorId: string,
    creatorRole: Role,
    data: {
      email: string;
      password: string;
      fullName: string;
      phoneNumber?: string;
      gymId: string;
    },
    managedGymId?: string | null
  ) {
    const validation = combineValidations(
      validateEmail(data.email),
      validatePassword(data.password),
      validateRequired(data.fullName, 'fullName', { minLength: 2, maxLength: 100 }),
      validateRequired(data.gymId, 'gymId')
    );

    if (!validation.valid) {
      throw new AdminValidationError('Validation failed', validation.errors);
    }

    const email = sanitize(data.email).toLowerCase();
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) throw new AdminConflictError('Email already registered');

    const gym = await prisma.gym.findUnique({ where: { id: data.gymId } });
    if (!gym) throw new AdminNotFoundError('Gym');

    const isBranchAdmin = creatorRole === Role.BRANCH_ADMIN;

    // SECURITY: Branch Admins cannot create other Branch Admins. Only Super Admin or Gym Owner of the gym.
    if (creatorRole === Role.BRANCH_ADMIN || (creatorRole !== Role.SUPER_ADMIN && gym.ownerId !== creatorId)) {
      throw new AdminAccessDeniedError();
    }

    const hashedPassword = await bcrypt.hash(data.password, 12);

    return prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        fullName: sanitize(data.fullName),
        phoneNumber: data.phoneNumber,
        role: Role.BRANCH_ADMIN,
        managedGymId: data.gymId,
        createdById: creatorId,
        isVerified: true,
        mustChangePassword: true,  // Force password reset on first login
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        role: true,
        phoneNumber: true,
        managedGymId: true,
        isVerified: true,
        mustChangePassword: true,
        createdAt: true,
      },
    });
  }

  /**
   * Create a Trainer profile (Gym Owner or Super Admin)
   */
  static async createTrainer(
    creatorId: string,
    creatorRole: Role,
    data: {
      fullName: string;
      avatarUrl?: string;
      age?: number;
      phoneNumber?: string;
      gymId: string;
      specialization?: string;
      bio?: string;
      certifications?: string[];
    },
    managedGymId?: string | null
  ) {
    // Validate input
    const validation = combineValidations(
      validateRequired(data.fullName, 'fullName', { minLength: 2, maxLength: 100 }),
      validateRequired(data.gymId, 'gymId')
    );

    if (!validation.valid) {
      throw new AdminValidationError('Validation failed', validation.errors);
    }

    const fullName = sanitize(data.fullName);

    // Verify gym exists and creator has access
    const gym = await prisma.gym.findUnique({
      where: { id: data.gymId },
    });

    if (!gym) {
      throw new AdminNotFoundError('Gym');
    }

    const isBranchAdmin = creatorRole === Role.BRANCH_ADMIN && gym.id === managedGymId;

    if (creatorRole !== Role.SUPER_ADMIN && gym.ownerId !== creatorId && !isBranchAdmin) {
      throw new AdminAccessDeniedError();
    }

    // Create trainer profile directly without creating a User account
    return prisma.trainerProfile.create({
      data: {
        fullName,
        avatarUrl: data.avatarUrl,
        age: data.age,
        gymId: data.gymId,
        specialization: data.specialization,
        bio: data.bio,
        certifications: data.certifications || [],
      },
      include: {
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
   * Get all Gym Owners (Super Admin only)
   */
  static async getAllGymOwners() {
    return prisma.user.findMany({
      where: { role: Role.GYM_OWNER },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
        address: true,
        isActive: true,
        isVerified: true,
        createdAt: true,
        ownedGyms: {
          select: {
            id: true,
            name: true,
            city: true,
            isActive: true,
            _count: {
              select: { memberships: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Get all trainers for a gym
   */
  static async getGymTrainers(gymId: string, userId: string, role: Role, managedGymId?: string | null) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });

    if (!gym) {
      throw new AdminNotFoundError('Gym');
    }

    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new AdminAccessDeniedError();
    }

    const [trainers, admins] = await Promise.all([
      prisma.trainerProfile.findMany({
        where: { gymId },
        include: {
          user: {
            select: {
              id: true,
              fullName: true,
              avatarUrl: true,
            }
          },
          _count: {
            select: { assignedMembers: true },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.user.findMany({
        where: { managedGymId: gymId, role: Role.BRANCH_ADMIN },
        select: {
          id: true,
          email: true,
          fullName: true,
          role: true,
          isActive: true,
          avatarUrl: true,
          createdAt: true,
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    // Map admins to Trainer-like structures for UI compatibility
    const mappedAdmins = admins.map(admin => ({
      id: admin.id,
      fullName: admin.fullName,
      email: admin.email,
      role: admin.role,
      isAvailable: admin.isActive,
      avatarUrl: admin.avatarUrl,
      gymId: gymId,
      userId: admin.id,
      certifications: [],
      _count: { assignedMembers: 0 },
    }));

    // 3. Map trainers to include fallback logic
    const mappedTrainers = trainers.map((t: any) => ({
      ...t,
      fullName: t.user?.fullName || t.fullName,
      avatarUrl: t.user?.avatarUrl || t.avatarUrl,
    }));

    return [...mappedAdmins, ...mappedTrainers];
  }

  /**
   * Update trainer profile
   */
  static async updateTrainer(
    trainerId: string,
    userId: string,
    role: Role,
    data: {
      fullName?: string;
      avatarUrl?: string;
      age?: number;
      specialization?: string;
      bio?: string;
      certifications?: string[];
      isAvailable?: boolean;
    },
    managedGymId?: string | null
  ) {
    const trainer = await prisma.trainerProfile.findUnique({
      where: { id: trainerId },
      include: { gym: true },
    });

    if (trainer) {
      const isBranchAdmin = role === Role.BRANCH_ADMIN && trainer.gym.id === managedGymId;
      if (role !== Role.SUPER_ADMIN && trainer.gym.ownerId !== userId && !isBranchAdmin) {
        throw new AdminAccessDeniedError();
      }

      const updated = await prisma.trainerProfile.update({
        where: { id: trainerId },
        data,
      });

      // If linked to a user, sync identity fields back to User record
      if (trainer.userId && (data.fullName || data.avatarUrl)) {
        await prisma.user.update({
          where: { id: trainer.userId },
          data: {
            ...(data.fullName ? { fullName: data.fullName } : {}),
            ...(data.avatarUrl ? { avatarUrl: data.avatarUrl } : {}),
          }
        });
      }

      return updated;
    }

    // If not found in trainerProfile, check if it's a Branch Admin (User)
    const userAccount = await prisma.user.findUnique({
      where: { id: trainerId },
      include: { managedGym: true },
    });

    if (!userAccount || userAccount.role !== Role.BRANCH_ADMIN) {
      throw new AdminNotFoundError('Staff member');
    }

    // Security: Only owner of the gym or super admin can update branch admin
    if (role !== Role.SUPER_ADMIN && userAccount.managedGym?.ownerId !== userId) {
      throw new AdminAccessDeniedError();
    }

    // Update the User record instead
    const { isAvailable, ...userUpdates } = data;
    await prisma.user.update({
      where: { id: trainerId },
      data: {
        ...userUpdates,
        ...(isAvailable !== undefined && { isActive: isAvailable }),
      },
    });

    return {
      id: userAccount.id,
      fullName: data.fullName || userAccount.fullName,
      avatarUrl: data.avatarUrl || userAccount.avatarUrl,
      role: userAccount.role,
      isAvailable: isAvailable ?? userAccount.isActive,
      gymId: userAccount.managedGymId!,
      userId: userAccount.id,
      certifications: [],
      _count: { assignedMembers: 0 },
    };
  }

  /**
   * Update a Gym Owner (Super Admin only)
   */
  static async updateGymOwner(
    targetId: string,
    data: {
      fullName?: string;
      phoneNumber?: string;
      isActive?: boolean;
    }
  ) {
    const user = await prisma.user.findUnique({
      where: { id: targetId },
    });

    if (!user || user.role !== Role.GYM_OWNER) {
      throw new AdminNotFoundError('Gym Owner');
    }

    return prisma.user.update({
      where: { id: targetId },
      data: {
        ...(data.fullName && { fullName: sanitize(data.fullName) }),
        ...(data.phoneNumber !== undefined && { phoneNumber: data.phoneNumber }),
        ...(data.isActive !== undefined && { isActive: data.isActive }),
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phoneNumber: true,
        isActive: true,
        isVerified: true,
        createdAt: true,
      },
    });
  }

  /**
   * Delete a trainer profile
   */
  static async deleteTrainer(trainerId: string, userId: string, role: Role, managedGymId?: string | null) {
    const trainer = await prisma.trainerProfile.findUnique({
      where: { id: trainerId },
      include: { gym: true },
    });

    if (!trainer) {
      throw new AdminNotFoundError('Trainer');
    }

    const isBranchAdmin = role === Role.BRANCH_ADMIN && trainer.gym.id === managedGymId;

    if (role !== Role.SUPER_ADMIN && trainer.gym.ownerId !== userId && !isBranchAdmin) {
      throw new AdminAccessDeniedError();
    }

    await prisma.trainerProfile.delete({
      where: { id: trainerId },
    });

    return { success: true };
  }

  /**
   * Delete a branch administrator account
   */
  static async deleteBranchAdmin(adminId: string, requesterId: string, requesterRole: Role) {
    const adminUser = await prisma.user.findUnique({
      where: { id: adminId },
      include: { managedGym: true }
    });

    if (!adminUser || adminUser.role !== Role.BRANCH_ADMIN) {
      throw new AdminNotFoundError('Branch Administrator');
    }

    // Security check: Only Super Admin or the owner of the gym can delete
    if (requesterRole !== Role.SUPER_ADMIN) {
      if (!adminUser.managedGym || adminUser.managedGym.ownerId !== requesterId) {
        throw new AdminAccessDeniedError();
      }
    }

    await prisma.user.delete({
      where: { id: adminId },
    });

    return { success: true };
  }

  /**
   * Activate a user account
   */
  static async activateUser(targetUserId: string, requesterId: string, requesterRole: Role) {
    const targetUser = await prisma.user.findUnique({
      where: { id: targetUserId },
    });

    if (!targetUser) {
      throw new AdminNotFoundError('User');
    }

    // Only Super Admin can activate users
    if (requesterRole !== Role.SUPER_ADMIN) {
      throw new AdminAccessDeniedError();
    }

    return prisma.user.update({
      where: { id: targetUserId },
      data: { isActive: true },
      select: {
        id: true,
        email: true,
        fullName: true,
        isActive: true,
      },
    });
  }

  /**
   * Deactivate a user account
   */
  static async deactivateUser(targetUserId: string, requesterId: string, requesterRole: Role) {
    const targetUser = await prisma.user.findUnique({
      where: { id: targetUserId },
    });

    if (!targetUser) {
      throw new AdminNotFoundError('User');
    }

    // Super Admin can deactivate anyone except themselves
    if (requesterRole === Role.SUPER_ADMIN) {
      if (targetUserId === requesterId) {
        throw new AdminAccessDeniedError('Cannot deactivate your own account');
      }
    }
    // Gym Owner can only deactivate their trainers
    else if (requesterRole === Role.GYM_OWNER) {
      if (targetUser.role !== Role.TRAINER) {
        throw new AdminAccessDeniedError();
      }
      // Check if trainer belongs to owner's gym
      const trainer = await prisma.trainerProfile.findUnique({
        where: { userId: targetUserId },
        include: { gym: true },
      });
      if (!trainer || trainer.gym.ownerId !== requesterId) {
        throw new AdminAccessDeniedError();
      }
    } else {
      throw new AdminAccessDeniedError();
    }

    return prisma.user.update({
      where: { id: targetUserId },
      data: { isActive: false },
      select: {
        id: true,
        email: true,
        fullName: true,
        isActive: true,
      },
    });
  }

  // ─── Exercise Library ────────────────────────────────────────────────────────

  static async listExerciseLibrary({ q, muscle, diff }: { q: string; muscle: string; diff: string }) {
    return prisma.exerciseLibrary.findMany({
      where: {
        ...(q ? {
          OR: [
            { name:   { contains: q, mode: 'insensitive' } },
            { nameKa: { contains: q, mode: 'insensitive' } },
            { nameRu: { contains: q, mode: 'insensitive' } },
          ],
        } : {}),
        ...(muscle ? { primaryMuscle: muscle } : {}),
        ...(diff   ? { difficulty: diff as any } : {}),
      },
      orderBy: { name: 'asc' },
    });
  }

  static async getExerciseLibraryStats() {
    const [total, active, byDifficulty, byMuscle] = await Promise.all([
      prisma.exerciseLibrary.count(),
      prisma.exerciseLibrary.count({ where: { isActive: true } }),
      prisma.exerciseLibrary.groupBy({ by: ['difficulty'], _count: { _all: true } }),
      prisma.exerciseLibrary.groupBy({ by: ['primaryMuscle'], _count: { _all: true } }),
    ]);
    return {
      total,
      active,
      byDifficulty: byDifficulty.map(r => ({ difficulty: r.difficulty, count: r._count._all })),
      byMuscle:     byMuscle.map(r => ({ muscle: r.primaryMuscle, count: r._count._all })),
    };
  }

  static async createExercise(data: any) {
    return prisma.exerciseLibrary.create({
      data: {
        name:             data.name,
        nameKa:           data.nameKa           ?? null,
        nameRu:           data.nameRu           ?? null,
        primaryMuscle:    data.primaryMuscle,
        secondaryMuscles: Array.isArray(data.secondaryMuscles) ? data.secondaryMuscles : [],
        equipment:        Array.isArray(data.equipment)        ? data.equipment        : [],
        difficulty:       data.difficulty  ?? 'BEGINNER',
        mechanics:        data.mechanics   ?? 'COMPOUND',
        force:            data.force       ?? 'PUSH',
        videoUrl:         data.videoUrl    ?? null,
        cues:             Array.isArray(data.cues)           ? data.cues           : [],
        commonMistakes:   Array.isArray(data.commonMistakes) ? data.commonMistakes : [],
        metValue:         data.metValue    ?? 3.0,
        isActive:         data.isActive    ?? true,
      },
    });
  }

  static async updateExercise(id: string, data: any) {
    const exists = await prisma.exerciseLibrary.findUnique({ where: { id } });
    if (!exists) throw new AdminNotFoundError('exercise');
    return prisma.exerciseLibrary.update({
      where: { id },
      data: {
        ...(data.name             !== undefined && { name: data.name }),
        ...(data.nameKa           !== undefined && { nameKa: data.nameKa }),
        ...(data.nameRu           !== undefined && { nameRu: data.nameRu }),
        ...(data.primaryMuscle    !== undefined && { primaryMuscle: data.primaryMuscle }),
        ...(data.secondaryMuscles !== undefined && { secondaryMuscles: data.secondaryMuscles }),
        ...(data.equipment        !== undefined && { equipment: data.equipment }),
        ...(data.difficulty       !== undefined && { difficulty: data.difficulty }),
        ...(data.mechanics        !== undefined && { mechanics: data.mechanics }),
        ...(data.force            !== undefined && { force: data.force }),
        ...(data.videoUrl         !== undefined && { videoUrl: data.videoUrl }),
        ...(data.cues             !== undefined && { cues: data.cues }),
        ...(data.commonMistakes   !== undefined && { commonMistakes: data.commonMistakes }),
        ...(data.metValue         !== undefined && { metValue: data.metValue }),
        ...(data.isActive         !== undefined && { isActive: data.isActive }),
      },
    });
  }

  static async deleteExercise(id: string) {
    const exists = await prisma.exerciseLibrary.findUnique({ where: { id } });
    if (!exists) throw new AdminNotFoundError('exercise');
    // Soft-delete: exercises may be referenced by existing workout plans/history
    return prisma.exerciseLibrary.update({ where: { id }, data: { isActive: false } });
  }

  static async importExerciseLibrary(records: any[]) {
    let imported = 0; let skipped = 0;
    for (const r of records) {
      if (!r.name) { skipped++; continue; }
      const splitPipe = (v: any) => Array.isArray(v) ? v : (v ? String(v).split('|').filter(Boolean) : []);
      try {
        await prisma.exerciseLibrary.upsert({
          where:  { name: r.name },
          update: {},
          create: {
            name:             r.name,
            nameKa:           r.nameKa    ?? null,
            nameRu:           r.nameRu    ?? null,
            primaryMuscle:    r.primaryMuscle || 'CHEST',
            secondaryMuscles: splitPipe(r.secondaryMuscles),
            equipment:        splitPipe(r.equipment),
            difficulty:       r.difficulty || 'BEGINNER',
            mechanics:        r.mechanics  || 'COMPOUND',
            force:            r.force      || 'PUSH',
            videoUrl:         r.videoUrl   || null,
            cues:             splitPipe(r.cues),
            commonMistakes:   splitPipe(r.commonMistakes),
            metValue:         parseFloat(r.metValue) || 3.0,
            isActive:         r.isActive !== false,
          },
        });
        imported++;
      } catch { skipped++; }
    }
    return { imported, skipped };
  }

  // ─── Ingredient (Food Item) Library ──────────────────────────────────────────

  static async listIngredientLibrary({ q, category, verified }: { q: string; category: string; verified?: string }) {
    return prisma.foodItem.findMany({
      where: {
        source: 'ADMIN',
        ...(q ? {
          OR: [
            { name:   { contains: q, mode: 'insensitive' } },
            { nameKa: { contains: q, mode: 'insensitive' } },
            { nameRu: { contains: q, mode: 'insensitive' } },
          ],
        } : {}),
        ...(category ? { foodCategory: category as any } : {}),
        ...(verified === 'true'  ? { isVerified: true }  : {}),
        ...(verified === 'false' ? { isVerified: false } : {}),
      },
      orderBy: { name: 'asc' },
    });
  }

  static async getIngredientLibraryStats() {
    const [total, verified, byCategory] = await Promise.all([
      prisma.foodItem.count({ where: { source: 'ADMIN' } }),
      prisma.foodItem.count({ where: { source: 'ADMIN', isVerified: true } }),
      prisma.foodItem.groupBy({ by: ['foodCategory'], where: { source: 'ADMIN' }, _count: { _all: true } }),
    ]);
    return {
      total,
      verified,
      byCategory: byCategory.map(r => ({ category: r.foodCategory ?? 'OTHER', count: r._count._all })),
    };
  }

  static async createIngredient(data: any) {
    return prisma.foodItem.create({
      data: {
        name:         data.name,
        nameKa:       data.nameKa       ?? null,
        nameRu:       data.nameRu       ?? null,
        brand:        data.brand        ?? null,
        barcode:      data.barcode      || null,
        calories:     data.calories,
        protein:      data.protein,
        carbs:        data.carbs,
        fats:         data.fats,
        fiber:        data.fiber        ?? null,
        sugar:        data.sugar        ?? null,
        sodium:       data.sodium       ?? null,
        foodCategory: data.foodCategory ?? null,
        source:       'ADMIN',
        isVerified:   false,
      },
    });
  }

  static async updateIngredient(id: string, data: any) {
    const exists = await prisma.foodItem.findUnique({ where: { id } });
    if (!exists) throw new AdminNotFoundError('ingredient');
    return prisma.foodItem.update({
      where: { id },
      data: {
        ...(data.name         !== undefined && { name: data.name }),
        ...(data.nameKa       !== undefined && { nameKa: data.nameKa }),
        ...(data.nameRu       !== undefined && { nameRu: data.nameRu }),
        ...(data.brand        !== undefined && { brand: data.brand }),
        ...(data.barcode      !== undefined && { barcode: data.barcode }),
        ...(data.calories     !== undefined && { calories: data.calories }),
        ...(data.protein      !== undefined && { protein: data.protein }),
        ...(data.carbs        !== undefined && { carbs: data.carbs }),
        ...(data.fats         !== undefined && { fats: data.fats }),
        ...(data.fiber        !== undefined && { fiber: data.fiber }),
        ...(data.sugar        !== undefined && { sugar: data.sugar }),
        ...(data.sodium       !== undefined && { sodium: data.sodium }),
        ...(data.foodCategory !== undefined && { foodCategory: data.foodCategory }),
      },
    });
  }

  static async verifyIngredient(id: string) {
    const exists = await prisma.foodItem.findUnique({ where: { id } });
    if (!exists) throw new AdminNotFoundError('ingredient');
    return prisma.foodItem.update({ where: { id }, data: { isVerified: true } });
  }

  static async deleteIngredient(id: string) {
    const exists = await prisma.foodItem.findUnique({ where: { id } });
    if (!exists) throw new AdminNotFoundError('ingredient');
    return prisma.foodItem.delete({ where: { id } });
  }

  static async importIngredientLibrary(records: any[]) {
    let imported = 0; let skipped = 0;
    for (const r of records) {
      if (!r.name) { skipped++; continue; }
      try {
        await prisma.foodItem.create({
          data: {
            name:         r.name,
            nameKa:       r.nameKa       ?? null,
            nameRu:       r.nameRu       ?? null,
            brand:        r.brand        ?? null,
            barcode:      r.barcode      || null,
            calories:     parseFloat(r.calories)  || 0,
            protein:      parseFloat(r.protein)   || 0,
            carbs:        parseFloat(r.carbs)     || 0,
            fats:         parseFloat(r.fats)      || 0,
            fiber:        r.fiber  ? parseFloat(r.fiber)  : null,
            sugar:        r.sugar  ? parseFloat(r.sugar)  : null,
            sodium:       r.sodium ? parseFloat(r.sodium) : null,
            foodCategory: r.foodCategory ?? null,
            source:       'ADMIN',
            isVerified:   r.isVerified === true || r.isVerified === 'true',
          },
        });
        imported++;
      } catch { skipped++; }
    }
    return { imported, skipped };
  }

  // ─── External Food Cache Management ─────────────────────────────────────────

  static async listExternalFoodCache({ source, q }: { source?: string; q?: string }) {
    return prisma.foodItem.findMany({
      where: {
        source: source ? source as any : { in: ['NUTRITIONIX', 'OPEN_FOOD_FACTS'] },
        ...(q ? { name: { contains: q, mode: 'insensitive' } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  static async getExternalFoodCacheStats() {
    const [nutritionix, off, total] = await Promise.all([
      prisma.foodItem.count({ where: { source: 'NUTRITIONIX' } }),
      prisma.foodItem.count({ where: { source: 'OPEN_FOOD_FACTS' } }),
      prisma.foodItem.count({ where: { source: { in: ['NUTRITIONIX', 'OPEN_FOOD_FACTS'] } } }),
    ]);
    return { nutritionix, openFoodFacts: off, total };
  }

  static async pruneExternalFoodCache(olderThanDays: number) {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - olderThanDays);
    const result = await prisma.foodItem.deleteMany({
      where: {
        source: { in: ['NUTRITIONIX', 'OPEN_FOOD_FACTS'] },
        createdAt: { lt: cutoff },
      },
    });
    return { deleted: result.count };
  }
}

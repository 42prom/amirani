import prisma from '../../lib/prisma';
import { Role, DoorSystemType } from '@prisma/client';
import { DoorAdapterFactory, DoorSystemType as AdapterDoorType } from './adapters';
import { assertMembershipAccess } from '../memberships/membership-utils';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class DoorAccessNotFoundError extends Error {
  constructor(public resource: string = 'Door System') {
    super(`${resource} not found`);
    this.name = 'DoorAccessNotFoundError';
  }
}

export class DoorAccessDeniedError extends Error {
  constructor(message = 'Access denied') {
    super(message);
    this.name = 'DoorAccessDeniedError';
  }
}

export class DoorAccessValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DoorAccessValidationError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class DoorAccessService {
  /**
   * Get a door system by ID
   */
  static async getDoorSystem(doorSystemId: string) {
    return prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
    });
  }

  /**
   * Create a new door system for a gym
   */
  static async createDoorSystem(
    gymId: string,
    userId: string,
    role: Role,
    data: {
      name: string;
      type: DoorSystemType;
      location?: string;
      vendorConfig?: Record<string, any>;
    }
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new DoorAccessNotFoundError('Gym');
    }

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = role === Role.BRANCH_ADMIN &&
        gym.id === (await prisma.user.findUnique({ where: { id: userId }, select: { managedGymId: true } }))?.managedGymId;
      
      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    return prisma.doorSystem.create({
      data: {
        gymId,
        name: data.name,
        type: data.type,
        location: data.location,
        vendorConfig: data.vendorConfig || {},
      },
    });
  }

  /**
   * Get all door systems for a gym
   */
  static async getGymDoorSystems(gymId: string, userId: string, role: Role) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new DoorAccessNotFoundError('Gym');
    }

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = role === Role.BRANCH_ADMIN &&
        gym.id === (await prisma.user.findUnique({ where: { id: userId }, select: { managedGymId: true } }))?.managedGymId;

      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    return prisma.doorSystem.findMany({
      where: { gymId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Update a door system
   */
  static async updateDoorSystem(
    doorSystemId: string,
    userId: string,
    role: Role,
    data: {
      name?: string;
      location?: string;
      vendorConfig?: Record<string, any>;
      isActive?: boolean;
    }
  ) {
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
      include: { gym: true },
    });

    if (!doorSystem) {
      throw new DoorAccessNotFoundError();
    }

    if (role !== Role.SUPER_ADMIN && doorSystem.gym.ownerId !== userId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = role === Role.BRANCH_ADMIN &&
        doorSystem.gymId === (await prisma.user.findUnique({ where: { id: userId }, select: { managedGymId: true } }))?.managedGymId;

      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    return prisma.doorSystem.update({
      where: { id: doorSystemId },
      data,
    });
  }

  /**
   * Delete a door system
   */
  static async deleteDoorSystem(doorSystemId: string, userId: string, role: Role) {
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
      include: { gym: true },
    });

    if (!doorSystem) {
      throw new DoorAccessNotFoundError();
    }

    if (role !== Role.SUPER_ADMIN && doorSystem.gym.ownerId !== userId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = role === Role.BRANCH_ADMIN &&
        doorSystem.gymId === (await prisma.user.findUnique({ where: { id: userId }, select: { managedGymId: true } }))?.managedGymId;

      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    return prisma.doorSystem.delete({ where: { id: doorSystemId } });
  }

  /**
   * Request door unlock - generates unlock code for the user
   */
  static async requestUnlock(
    doorSystemId: string,
    userId: string
  ) {
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
      include: { gym: true },
    });

    if (!doorSystem) {
      throw new DoorAccessNotFoundError();
    }

    if (!doorSystem.isActive) {
      throw new DoorAccessValidationError('Door system is not active');
    }

    // Administrative bypass: Branch Admin, Gym Owner, and Super Admin can unlock without membership checks
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, managedGymId: true }
    });

    const isSuperAdmin = user?.role === Role.SUPER_ADMIN;
    const isGymOwner = user?.role === Role.GYM_OWNER && doorSystem.gym.ownerId === userId;
    const isBranchAdmin = user?.role === Role.BRANCH_ADMIN && user.managedGymId === doorSystem.gymId;

    if (!isSuperAdmin && !isGymOwner && !isBranchAdmin) {
      // Standard membership check for GYM_MEMBER or other roles
      const membership = await prisma.gymMembership.findFirst({
        where: { userId, gymId: doorSystem.gymId, status: 'ACTIVE' },
      });

      assertMembershipAccess(membership, DoorAccessDeniedError);
    }

    // Get the appropriate adapter
    const adapter = await DoorAdapterFactory.getAdapter(
      doorSystem.type as AdapterDoorType,
      (doorSystem.vendorConfig as Record<string, any>) || {}
    );

    // Generate unlock code
    const result = await adapter.generateUnlockCode(userId, doorSystemId);

    // Log the access attempt
    await prisma.doorAccessLog.create({
      data: {
        doorSystemId,
        userId,
        method: doorSystem.type,
        accessGranted: result.success,
        deviceInfo: 'Mobile App',
      },
    });

    return result;
  }

  /**
   * Validate an unlock code
   */
  static async validateUnlock(doorSystemId: string, code: string) {
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
    });

    if (!doorSystem) {
      throw new DoorAccessNotFoundError();
    }

    const adapter = await DoorAdapterFactory.getAdapter(
      doorSystem.type as AdapterDoorType,
      (doorSystem.vendorConfig as Record<string, any>) || {}
    );

    const isValid = await adapter.validateUnlock(code, doorSystemId);

    return { valid: isValid };
  }

  /**
   * Revoke access for a user at a door
   */
  static async revokeAccess(
    doorSystemId: string,
    targetUserId: string,
    requesterId: string,
    requesterRole: Role
  ) {
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
      include: { gym: true },
    });

    if (!doorSystem) {
      throw new DoorAccessNotFoundError();
    }

    if (requesterRole !== Role.SUPER_ADMIN && doorSystem.gym.ownerId !== requesterId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = requesterRole === Role.BRANCH_ADMIN &&
        doorSystem.gymId === (await prisma.user.findUnique({ where: { id: requesterId }, select: { managedGymId: true } }))?.managedGymId;

      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    const adapter = await DoorAdapterFactory.getAdapter(
      doorSystem.type as AdapterDoorType,
      (doorSystem.vendorConfig as Record<string, any>) || {}
    );

    const revoked = await adapter.revokeAccess(targetUserId, doorSystemId);

    return { revoked };
  }

  /**
   * Get access logs for a door system
   */
  static async getAccessLogs(
    doorSystemId: string,
    userId: string,
    role: Role,
    options?: {
      startDate?: Date;
      endDate?: Date;
      limit?: number;
    }
  ) {
    const doorSystem = await prisma.doorSystem.findUnique({
      where: { id: doorSystemId },
      include: { gym: true },
    });

    if (!doorSystem) {
      throw new DoorAccessNotFoundError();
    }

    if (role !== Role.SUPER_ADMIN && doorSystem.gym.ownerId !== userId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = role === Role.BRANCH_ADMIN &&
        doorSystem.gymId === (await prisma.user.findUnique({ where: { id: userId }, select: { managedGymId: true } }))?.managedGymId;

      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    const where: any = { doorSystemId };
    if (options?.startDate || options?.endDate) {
      where.accessTime = {};
      if (options.startDate) where.accessTime.gte = options.startDate;
      if (options.endDate) where.accessTime.lte = options.endDate;
    }

    return prisma.doorAccessLog.findMany({
      where,
      orderBy: { accessTime: 'desc' },
      take: options?.limit || 100,
    });
  }

  /**
   * Get gym access logs (all doors)
   */
  static async getGymAccessLogs(
    gymId: string,
    userId: string,
    role: Role,
    options?: {
      limit?: number;
      startDate?: Date;
      endDate?: Date;
    }
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new DoorAccessNotFoundError('Gym');
    }

    // Allow Branch Admin access for their managed gym
    const isBranchAdmin = role === Role.BRANCH_ADMIN &&
      gym.id === (await prisma.user.findUnique({ where: { id: userId } }))?.managedGymId;

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new DoorAccessDeniedError();
    }

    const doorSystems = await prisma.doorSystem.findMany({
      where: { gymId },
      select: { id: true },
    });

    const doorSystemIds = doorSystems.map((d) => d.id);

    // Build where clause with date filters
    const where: {
      doorSystemId: { in: string[] };
      accessTime?: { gte?: Date; lte?: Date };
    } = { doorSystemId: { in: doorSystemIds } };

    if (options?.startDate || options?.endDate) {
      where.accessTime = {};
      if (options.startDate) where.accessTime.gte = options.startDate;
      if (options.endDate) where.accessTime.lte = options.endDate;
    }

    const logs = await prisma.doorAccessLog.findMany({
      where,
      include: {
        doorSystem: {
          select: {
            id: true,
            name: true,
            type: true,
            location: true,
          },
        },
      },
      orderBy: { accessTime: 'desc' },
      take: options?.limit || 100,
    });

    // Manual fetch user information to avoid Prisma relation issues
    const userIds = [...new Set(logs.map((l) => l.userId))];
    const users = await prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, fullName: true, email: true, avatarUrl: true },
    });
    const userMap = new Map(users.map((u) => [u.id, u]));

    return logs.map((log) => ({
      ...log,
      user: userMap.get(log.userId),
    }));
  }

  /**
   * Check health of all door systems for a gym
   */
  static async checkDoorSystemsHealth(gymId: string, userId: string, role: Role) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) {
      throw new DoorAccessNotFoundError('Gym');
    }

    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
      // Check if user is the assigned branch admin
      const isBranchAdmin = role === Role.BRANCH_ADMIN &&
        gym.id === (await prisma.user.findUnique({ where: { id: userId }, select: { managedGymId: true } }))?.managedGymId;

      if (!isBranchAdmin) {
        throw new DoorAccessDeniedError();
      }
    }

    const doorSystems = await prisma.doorSystem.findMany({
      where: { gymId, isActive: true },
    });

    const healthStatus = await Promise.all(
      doorSystems.map(async (door) => {
        const adapter = await DoorAdapterFactory.getAdapter(
          door.type as AdapterDoorType,
          (door.vendorConfig as Record<string, any>) || {}
        );

        const isHealthy = await adapter.healthCheck();

        return {
          id: door.id,
          name: door.name,
          type: door.type,
          location: door.location,
          isHealthy,
        };
      })
    );

    return healthStatus;
  }
}

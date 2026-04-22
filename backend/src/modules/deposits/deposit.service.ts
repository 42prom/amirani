import prisma from '../../utils/prisma';
import { DepositStatus, DepositType, Role } from '@prisma/client';

export class DepositService {
  /**
   * Submit a new deposit (Cash on Hand or Bank Deposit)
   */
  static async submitDeposit(
    gymId: string,
    userId: string,
    role: Role,
    data: {
      amount: number;
      type: DepositType;
      reference?: string;
      notes?: string;
      currency?: string;
    },
    managedGymId?: string | null
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw new Error('Gym not found');

    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new Error('Access denied');
    }

    return prisma.deposit.create({
      data: {
        amount: data.amount,
        type: data.type,
        reference: data.reference,
        notes: data.notes,
        currency: data.currency || 'usd',
        gymId,
        submittedById: userId,
        status: DepositStatus.PENDING,
      },
    });
  }

  /**
   * Get deposits for a specific gym
   */
  static async getGymDeposits(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId?: string | null
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw new Error('Gym not found');

    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new Error('Access denied');
    }

    return prisma.deposit.findMany({
      where: { gymId },
      include: {
        submittedBy: { select: { id: true, fullName: true, email: true } },
        approvedBy: { select: { id: true, fullName: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Super Admin: Get all deposits across all gyms
   */
  static async getAllDeposits(
    userId: string,
    role: Role,
    status?: DepositStatus
  ) {
    if (role !== Role.SUPER_ADMIN) {
      throw new Error('Access denied. Super Admin only.');
    }

    const where = status ? { status } : {};

    return prisma.deposit.findMany({
      where,
      include: {
        gym: { select: { id: true, name: true } },
        submittedBy: { select: { id: true, fullName: true, email: true } },
        approvedBy: { select: { id: true, fullName: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Super Admin: Update deposit status (Approve/Reject)
   */
  static async updateDepositStatus(
    depositId: string,
    userId: string,
    role: Role,
    status: DepositStatus
  ) {
    if (role !== Role.SUPER_ADMIN) {
      throw new Error('Access denied. Super Admin only.');
    }

    const deposit = await prisma.deposit.findUnique({ where: { id: depositId } });
    if (!deposit) throw new Error('Deposit not found');

    return prisma.deposit.update({
      where: { id: depositId },
      data: {
        status,
        approvedById: userId,
      },
      include: {
        gym: { select: { id: true, name: true } },
        submittedBy: { select: { id: true, fullName: true, email: true } },
        approvedBy: { select: { id: true, fullName: true, email: true } },
      },
    });
  }
}

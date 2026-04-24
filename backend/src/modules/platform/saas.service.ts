import prisma from "../../lib/prisma";
import { SaaSSubscriptionStatus } from '@prisma/client';

export interface SaaSStatusResponse {
  status: SaaSSubscriptionStatus;
  daysLeft: number;
  pricePerBranch: number;
  totalCostPerMonth: number;
  branchCount: number;
  nextBillingDate: Date | null;
}

export class SaaSService {
  /**
   * Get the SaaS subscription status and cost breakdown for a gym owner
   */
  static async getOwnerSaaSStatus(userId: string): Promise<SaaSStatusResponse> {
    const [user, config, branchCount] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: {
          saasSubscriptionStatus: true,
          saasTrialEndsAt: true,
          saasNextBillingDate: true,
          isLifetimeFree: true,
          customPricePerBranch: true,
          customPlatformFeePercent: true,
        },
      }),
      prisma.platformConfig.findUnique({
        where: { id: 'singleton' },
        select: { pricePerBranch: true },
      }),
      prisma.gym.count({
        where: { ownerId: userId },
      }),
    ]);

    if (!user) throw new Error('User not found');

    // Use flexible pricing fields if present
    const pricePerBranch = user.isLifetimeFree 
      ? 0 
      : (user.customPricePerBranch !== null ? user.customPricePerBranch : Number(config?.pricePerBranch || 0));
    
    const totalCostPerMonth = branchCount * pricePerBranch;

    let daysLeft = 0;
    if (user.saasSubscriptionStatus === 'TRIAL' && user.saasTrialEndsAt) {
      const diffTime = user.saasTrialEndsAt.getTime() - Date.now();
      daysLeft = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    } else if (user.saasNextBillingDate) {
      const diffTime = user.saasNextBillingDate.getTime() - Date.now();
      daysLeft = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    }

    return {
      status: user.saasSubscriptionStatus,
      daysLeft: Math.max(0, daysLeft),
      pricePerBranch,
      totalCostPerMonth,
      branchCount,
      nextBillingDate: user.saasNextBillingDate,
    };
  }

  /**
   * Get billing history (invoices) for a gym owner
   */
  static async getOwnerInvoices(userId: string) {
    return prisma.payment.findMany({
      where: {
        userId,
        description: { contains: 'SaaS' },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Get all SaaS subscriptions (Super Admin only)
   */
  static async getAllSubscriptions() {
    const [owners, config] = await Promise.all([
      prisma.user.findMany({
        where: { role: 'GYM_OWNER' },
        select: {
          id: true,
          email: true,
          fullName: true,
          saasSubscriptionStatus: true,
          saasTrialEndsAt: true,
          saasNextBillingDate: true,
          isLifetimeFree: true,
          customPricePerBranch: true,
          customPlatformFeePercent: true,
          _count: {
            select: { ownedGyms: true },
          },
        },
      }),
      prisma.platformConfig.findUnique({
        where: { id: 'singleton' },
        select: { pricePerBranch: true },
      }),
    ]);

    const defaultPricePerBranch = Number(config?.pricePerBranch || 0);

    return owners.map(owner => {
      const pricePerBranch = owner.isLifetimeFree 
        ? 0 
        : (owner.customPricePerBranch !== null ? owner.customPricePerBranch : defaultPricePerBranch);
        
      return {
        ownerId: owner.id,
        email: owner.email,
        fullName: owner.fullName,
        status: owner.saasSubscriptionStatus,
        trialEndsAt: owner.saasTrialEndsAt,
        nextBillingDate: owner.saasNextBillingDate,
        branchCount: owner._count.ownedGyms,
        monthlyCost: owner._count.ownedGyms * pricePerBranch,
        isLifetimeFree: owner.isLifetimeFree,
        customPricePerBranch: owner.customPricePerBranch,
        customPlatformFeePercent: owner.customPlatformFeePercent,
      };
    });
  }
  /**
   * Manually extend a Gym Owner's SaaS subscription (Super Admin only)
   */
  static async extendSaaSSubscription(ownerId: string, data: { days: number, amount: number, paymentMethod: string, notes?: string }) {
    const user = await prisma.user.findUnique({
      where: { id: ownerId, role: 'GYM_OWNER' },
    });

    if (!user) {
      throw new Error('Gym Owner not found');
    }

    // Calculate new billing date
    let currentExpiry = user.saasNextBillingDate || user.saasTrialEndsAt || new Date();
    
    // If the subscription is already expired, start from today
    if (currentExpiry.getTime() < Date.now()) {
      currentExpiry = new Date();
    }

    const newExpiry = new Date(currentExpiry);
    newExpiry.setDate(newExpiry.getDate() + data.days);

    // Record the payment and update the user in a transaction
    return prisma.$transaction(async (tx) => {
      // 1. Record the manual payment as an invoice
      const payment = await tx.payment.create({
        data: {
          userId: ownerId,
          amount: data.amount,
          currency: 'USD',
          status: 'SUCCEEDED',
          method: 'TRANSFER',
          description: `Manual SaaS Extension (${data.days} days) - ${data.paymentMethod}`,
        },
      });

      // 2. Update the user's SaaS status
      const updatedUser = await tx.user.update({
        where: { id: ownerId },
        data: {
          saasSubscriptionStatus: 'ACTIVE',
          saasNextBillingDate: newExpiry,
        },
        select: {
          id: true,
          saasSubscriptionStatus: true,
          saasNextBillingDate: true,
        }
      });

      return {
        paymentId: payment.id,
        status: updatedUser.saasSubscriptionStatus,
        nextBillingDate: updatedUser.saasNextBillingDate,
      };
    });
  }

  /**
   * Transition gym owners whose SaaS trial has expired to PAST_DUE.
   * Called by the hourly cron. Skips isLifetimeFree owners.
   * Returns counts for monitoring.
   */
  static async processSaaSTrialExpiry(): Promise<{ transitioned: number }> {
    const now = new Date();

    const expiredOwners = await prisma.user.findMany({
      where: {
        role: 'GYM_OWNER',
        isLifetimeFree: false,
        saasSubscriptionStatus: 'TRIAL',
        saasTrialEndsAt: { lt: now },
      },
      select: { id: true, email: true, fullName: true },
    });

    if (expiredOwners.length === 0) return { transitioned: 0 };

    await prisma.user.updateMany({
      where: { id: { in: expiredOwners.map((o) => o.id) } },
      data: { saasSubscriptionStatus: 'PAST_DUE' },
    });

    return { transitioned: expiredOwners.length };
  }

  /**
   * Update a Gym Owner's custom SaaS pricing overrides (Super Admin only)
   */
  static async updateSaaSPricing(
    ownerId: string, 
    data: { 
      isLifetimeFree?: boolean; 
      customPricePerBranch?: number | null; 
      customPlatformFeePercent?: number | null;
    }
  ) {
    const user = await prisma.user.findUnique({
      where: { id: ownerId, role: 'GYM_OWNER' },
    });

    if (!user) {
      throw new Error('Gym Owner not found');
    }

    return prisma.user.update({
      where: { id: ownerId },
      data: {
        isLifetimeFree: data.isLifetimeFree !== undefined ? data.isLifetimeFree : user.isLifetimeFree,
        customPricePerBranch: data.customPricePerBranch !== undefined ? data.customPricePerBranch : user.customPricePerBranch,
        customPlatformFeePercent: data.customPlatformFeePercent !== undefined ? data.customPlatformFeePercent : user.customPlatformFeePercent,
      },
      select: {
        id: true,
        isLifetimeFree: true,
        customPricePerBranch: true,
        customPlatformFeePercent: true,
      }
    });
  }
}


import prisma from '../../utils/prisma';
import { Role } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import logger from '../../utils/logger';

// ─── Types ────────────────────────────────────────────────────────────────────

export type CampaignAudience =
  | 'ALL'
  | 'ACTIVE'
  | 'EXPIRED'
  | 'PENDING'
  | 'INACTIVE_30D'
  | 'INACTIVE_60D';

export interface CreateCampaignData {
  name: string;
  subject?: string;
  body: string;
  imageUrl?: string;
  channels: string[];
  targetAudience: CampaignAudience;
  targetPlanId?: string;
  scheduledAt?: string;
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class MarketingService {

  /**
   * Resolve target user IDs based on audience segment
   */
  static async resolveAudience(gymId: string, audience: CampaignAudience, targetPlanId?: string): Promise<string[]> {
    const now = new Date();
    const ago30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const ago60 = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);

    const planFilter = targetPlanId ? { planId: targetPlanId } : {};

    switch (audience) {
      case 'ACTIVE': {
        const memberships = await prisma.gymMembership.findMany({
          where: { gymId, status: 'ACTIVE', ...planFilter },
          select: { userId: true },
        });
        return memberships.map((m) => m.userId);
      }

      case 'EXPIRED': {
        const memberships = await prisma.gymMembership.findMany({
          where: { gymId, status: 'EXPIRED', ...planFilter },
          select: { userId: true },
        });
        return memberships.map((m) => m.userId);
      }

      case 'PENDING': {
        const memberships = await prisma.gymMembership.findMany({
          where: { gymId, status: 'PENDING', ...planFilter },
          select: { userId: true },
        });
        return memberships.map((m) => m.userId);
      }

      case 'INACTIVE_30D': {
        // Active members who haven't checked in for 30+ days
        const activeMemberships = await prisma.gymMembership.findMany({
          where: { gymId, status: 'ACTIVE', ...planFilter },
          select: { userId: true },
        });
        const activeIds = activeMemberships.map((m) => m.userId);

        // Find those who DID check in recently
        const recentCheckins = await prisma.attendance.findMany({
          where: { gymId, checkIn: { gte: ago30 }, userId: { in: activeIds } },
          select: { userId: true },
          distinct: ['userId'],
        });
        const recentIds = new Set(recentCheckins.map((a) => a.userId));

        return activeIds.filter((id) => !recentIds.has(id));
      }

      case 'INACTIVE_60D': {
        const activeMemberships = await prisma.gymMembership.findMany({
          where: { gymId, status: 'ACTIVE', ...planFilter },
          select: { userId: true },
        });
        const activeIds = activeMemberships.map((m) => m.userId);

        const recentCheckins = await prisma.attendance.findMany({
          where: { gymId, checkIn: { gte: ago60 }, userId: { in: activeIds } },
          select: { userId: true },
          distinct: ['userId'],
        });
        const recentIds = new Set(recentCheckins.map((a) => a.userId));

        return activeIds.filter((id) => !recentIds.has(id));
      }

      case 'ALL':
      default: {
        const memberships = await prisma.gymMembership.findMany({
          where: { gymId, ...planFilter },
          select: { userId: true },
          distinct: ['userId'],
        });
        return memberships.map((m) => m.userId);
      }
    }
  }

  /**
   * Create a new campaign (saved as DRAFT)
   */
  static async create(
    gymId: string,
    createdById: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: CreateCampaignData
  ) {
    await this.assertAccess(gymId, createdById, role, managedGymId);

    const prismaAny = prisma as any;
    return prismaAny.marketingCampaign.create({
      data: {
        gymId,
        createdById,
        name: data.name,
        subject: data.subject,
        body: data.body,
        imageUrl: data.imageUrl,
        channels: data.channels,
        targetAudience: data.targetAudience,
        targetPlanId: data.targetPlanId,
        scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : null,
        status: 'DRAFT',
      },
    });
  }

  /**
   * Preview audience count for a campaign target
   */
  static async previewAudience(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined,
    audience: CampaignAudience,
    targetPlanId?: string
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const ids = await this.resolveAudience(gymId, audience, targetPlanId);
    return { count: ids.length, audience, targetPlanId };
  }

  /**
   * Send (or schedule) a campaign immediately
   */
  static async send(
    campaignId: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);

    const prismaAny = prisma as any;
    const campaign = await prismaAny.marketingCampaign.findFirst({
      where: { id: campaignId, gymId },
    });

    if (!campaign) throw new Error('Campaign not found');
    if (campaign.status === 'SENT') throw new Error('Campaign already sent');

    // Resolve audience
    const userIds = await this.resolveAudience(
      gymId,
      campaign.targetAudience as CampaignAudience,
      campaign.targetPlanId
    );

    if (userIds.length === 0) {
      await prismaAny.marketingCampaign.update({
        where: { id: campaignId },
        data: { status: 'SENT', sentAt: new Date(), totalTargeted: 0, totalDelivered: 0 },
      });
      return { sent: 0, message: 'No recipients in selected audience' };
    }

    // Mark as sending
    await prismaAny.marketingCampaign.update({
      where: { id: campaignId },
      data: { status: 'SENDING', totalTargeted: userIds.length },
    });

    // Determine notification channels
    const channels: Array<'PUSH' | 'EMAIL' | 'IN_APP'> = (campaign.channels as string[]).filter(
      (c: string) => ['PUSH', 'EMAIL', 'IN_APP'].includes(c)
    ) as Array<'PUSH' | 'EMAIL' | 'IN_APP'>;

    let delivered = 0;
    const BATCH_SIZE = 50;

    for (let i = 0; i < userIds.length; i += BATCH_SIZE) {
      const batch = userIds.slice(i, i + BATCH_SIZE);
      try {
        await NotificationService.sendBulk({
          userIds: batch,
          type: 'SYSTEM' as any,
          title: campaign.subject || campaign.name,
          body: campaign.body,
          data: {
            campaignId,
            gymId,
            imageUrl: campaign.imageUrl,
          },
          channels,
        });
        delivered += batch.length;
      } catch (err) {
        logger.error({ batchStart: i, err }, '[Marketing] Batch failed');
      }
    }

    await prismaAny.marketingCampaign.update({
      where: { id: campaignId },
      data: { status: 'SENT', sentAt: new Date(), totalDelivered: delivered },
    });

    return { sent: delivered, total: userIds.length };
  }

  /**
   * List campaigns for a gym
   */
  static async list(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    return prismaAny.marketingCampaign.findMany({
      where: { gymId },
      orderBy: { createdAt: 'desc' },
      include: {
        createdBy: { select: { id: true, fullName: true } },
      },
    });
  }

  /**
   * Delete a draft campaign
   */
  static async delete(
    campaignId: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const campaign = await prismaAny.marketingCampaign.findFirst({ where: { id: campaignId, gymId } });
    if (!campaign) throw new Error('Campaign not found');
    if (campaign.status === 'SENDING') throw new Error('Cannot delete a campaign that is currently sending');
    await prismaAny.marketingCampaign.delete({ where: { id: campaignId } });
    return { deleted: true };
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  private static async assertAccess(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw new Error('Gym not found');

    const isBranchAdmin = role === Role.BRANCH_ADMIN && gym.id === managedGymId;
    if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId && !isBranchAdmin) {
      throw new Error('Access denied');
    }
  }
}


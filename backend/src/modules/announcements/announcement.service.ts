import prisma from '../../utils/prisma';
import { Role } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import { MarketingService, CampaignAudience } from '../marketing/marketing.service';
import logger from '../../utils/logger';

// ─── Service ──────────────────────────────────────────────────────────────────

export class AnnouncementService {

  /**
   * Publish a new announcement: save it, then immediately push to members.
   */
  static async publish(
    gymId: string,
    authorId: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: {
      title: string;
      body: string;
      imageUrl?: string;
      isPinned?: boolean;
      targetAudience: string;
      channels: string[];
    }
  ) {
    await this.assertAccess(gymId, authorId, role, managedGymId);

    const prismaAny = prisma as any;

    const announcement = await prismaAny.gymAnnouncement.create({
      data: {
        gymId,
        authorId,
        title: data.title,
        body: data.body,
        imageUrl: data.imageUrl || null,
        isPinned: data.isPinned ?? false,
        targetAudience: data.targetAudience,
        channels: data.channels,
        totalDelivered: 0,
      },
      include: {
        author: { select: { id: true, fullName: true } },
      },
    });

    // Resolve audience and send notifications (fire-and-forget, update delivered count after)
    setImmediate(async () => {
      try {
        const userIds = await MarketingService.resolveAudience(
          gymId,
          data.targetAudience as CampaignAudience
        );

        if (userIds.length === 0) return;

        const channels = (data.channels as string[]).filter((c) =>
          ['PUSH', 'EMAIL', 'IN_APP'].includes(c)
        ) as Array<'PUSH' | 'EMAIL' | 'IN_APP'>;

        let delivered = 0;
        const BATCH = 50;
        for (let i = 0; i < userIds.length; i += BATCH) {
          try {
            await NotificationService.sendBulk({
              userIds: userIds.slice(i, i + BATCH),
              type: 'SYSTEM' as any,
              title: data.title,
              body: data.body,
              data: { announcementId: announcement.id, gymId, imageUrl: data.imageUrl },
              channels,
            });
            delivered += Math.min(BATCH, userIds.length - i);
          } catch (err) {
            logger.error({ err }, '[Announcement] Batch send error');
          }
        }

        await prismaAny.gymAnnouncement.update({
          where: { id: announcement.id },
          data: { totalDelivered: delivered },
        });
      } catch (err) {
        logger.error({ err }, '[Announcement] Delivery error');
      }
    });

    return announcement;
  }

  /**
   * List announcements for a gym (newest first).
   */
  static async list(
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    return prismaAny.gymAnnouncement.findMany({
      where: { gymId },
      orderBy: [{ isPinned: 'desc' }, { publishedAt: 'desc' }],
      include: { author: { select: { id: true, fullName: true } } },
    });
  }

  /**
   * Toggle pin status on an announcement.
   */
  static async togglePin(
    id: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const announcement = await prismaAny.gymAnnouncement.findFirst({ where: { id, gymId } });
    if (!announcement) throw Object.assign(new Error('Announcement not found'), { status: 404 });
    return prismaAny.gymAnnouncement.update({
      where: { id },
      data: { isPinned: !announcement.isPinned },
    });
  }

  /**
   * Delete an announcement.
   */
  static async delete(
    id: string,
    gymId: string,
    userId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, userId, role, managedGymId);
    const prismaAny = prisma as any;
    const announcement = await prismaAny.gymAnnouncement.findFirst({ where: { id, gymId } });
    if (!announcement) throw Object.assign(new Error('Announcement not found'), { status: 404 });
    await prismaAny.gymAnnouncement.delete({ where: { id } });
    return { deleted: true };
  }

  // ─── Private ─────────────────────────────────────────────────────────────

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


import prisma from '../../utils/prisma';
import { Role } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import { AuditLogService } from '../audit/audit.service';
import { WebhookService } from '../webhooks/webhook.service';

const prismaAny = prisma as any;

// ─── Service ──────────────────────────────────────────────────────────────────

export class FreezeService {

  /**
   * Freeze an active membership for a number of days.
   * The endDate is extended by the freeze duration so the member doesn't lose time.
   */
  static async freeze(
    membershipId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    options: { days: number; reason?: string }
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);

    const membership = await prismaAny.gymMembership.findFirst({
      where: { id: membershipId, gymId },
      include: { user: { select: { id: true, fullName: true } } },
    });

    if (!membership) throw Object.assign(new Error('Membership not found'), { status: 404 });
    if (membership.status === 'FROZEN') throw Object.assign(new Error('Membership is already frozen'), { status: 400 });
    if (membership.status !== 'ACTIVE') throw Object.assign(new Error('Only active memberships can be frozen'), { status: 400 });

    const now = new Date();
    const frozenUntil = new Date(now.getTime() + options.days * 24 * 60 * 60 * 1000);

    // Extend endDate by freeze duration so member doesn't lose days
    const newEndDate = new Date(new Date(membership.endDate).getTime() + options.days * 24 * 60 * 60 * 1000);

    const updated = await prismaAny.gymMembership.update({
      where: { id: membershipId },
      data: {
        status: 'FROZEN',
        frozenAt: now,
        frozenUntil,
        freezeReason: options.reason || null,
        endDate: newEndDate,
      },
    });

    AuditLogService.log(gymId, adminId, 'MEMBERSHIP_FROZEN', 'membership', `Froze ${membership.user?.fullName ?? 'member'}'s membership for ${options.days} day${options.days !== 1 ? 's' : ''}${options.reason ? ` (${options.reason})` : ''}`, membershipId);
    WebhookService.dispatch(gymId, 'membership.frozen', { membershipId, userId: membership.userId, days: options.days, reason: options.reason ?? null });

    // Notify member
    await NotificationService.send({
      userId: membership.userId,
      type: 'SYSTEM' as any,
      title: 'Membership Frozen ❄️',
      body: `Your membership has been frozen for ${options.days} day${options.days !== 1 ? 's' : ''}${options.reason ? ` — ${options.reason}` : ''}. It will automatically resume on ${frozenUntil.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}.`,
      data: { membershipId, gymId, path: '/profile' },
      channels: ['PUSH', 'IN_APP'],
    });

    return updated;
  }

  /**
   * Unfreeze a frozen membership immediately.
   * Trims the remaining freeze days from endDate (member only gets credit for actual frozen time).
   */
  static async unfreeze(
    membershipId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);

    const membership = await prismaAny.gymMembership.findFirst({
      where: { id: membershipId, gymId },
    });

    if (!membership) throw Object.assign(new Error('Membership not found'), { status: 404 });
    if (membership.status !== 'FROZEN') throw Object.assign(new Error('Membership is not frozen'), { status: 400 });

    const now = new Date();

    // If frozenUntil is in the future, claw back the remaining frozen days from endDate
    let newEndDate = new Date(membership.endDate);
    if (membership.frozenUntil && new Date(membership.frozenUntil) > now) {
      const remainingFreezeMs = new Date(membership.frozenUntil).getTime() - now.getTime();
      newEndDate = new Date(new Date(membership.endDate).getTime() - remainingFreezeMs);
    }

    const updated = await prismaAny.gymMembership.update({
      where: { id: membershipId },
      data: {
        status: 'ACTIVE',
        frozenAt: null,
        frozenUntil: null,
        freezeReason: null,
        endDate: newEndDate,
      },
    });

    AuditLogService.log(gymId, adminId, 'MEMBERSHIP_UNFROZEN', 'membership', `Unfroze membership early`, membershipId);
    WebhookService.dispatch(gymId, 'membership.unfrozen', { membershipId, userId: membership.userId });

    await NotificationService.send({
      userId: membership.userId,
      type: 'SYSTEM' as any,
      title: 'Membership Resumed! ✨',
      body: 'Welcome back! Your membership is active again. Let\'s continue your fitness journey! 💪',
      data: { membershipId, gymId, path: '/profile' },
      channels: ['PUSH', 'IN_APP'],
    });

    return updated;
  }

  /**
   * Auto-unfreeze memberships whose frozenUntil has passed.
   * Called by the hourly automation interval.
   */
  static async processAutoUnfreeze(): Promise<number> {
    const now = new Date();
    const frozen = await prismaAny.gymMembership.findMany({
      where: { status: 'FROZEN', frozenUntil: { lte: now } },
    });

    for (const m of frozen) {
      await prismaAny.gymMembership.update({
        where: { id: m.id },
        data: {
          status: 'ACTIVE',
          frozenAt: null,
          frozenUntil: null,
          freezeReason: null,
        },
      });

      await NotificationService.send({
        userId: m.userId,
        type: 'SYSTEM' as any,
        title: 'Membership Resumed! ✨',
        body: 'Your freeze period has ended. Time to get back to work! 🏋️‍♂️',
        data: { membershipId: m.id, gymId: m.gymId, path: '/profile' },
        channels: ['PUSH', 'IN_APP'],
      });
    }

    return frozen.length;
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

import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';

const prismaAny = prisma as any;

// ─── Action constants ─────────────────────────────────────────────────────────

export const AuditAction = {
  // Membership
  MEMBERSHIP_FROZEN:   'MEMBERSHIP_FROZEN',
  MEMBERSHIP_UNFROZEN: 'MEMBERSHIP_UNFROZEN',
  MEMBERSHIP_CREATED:  'MEMBERSHIP_CREATED',
  MEMBERSHIP_CANCELLED:'MEMBERSHIP_CANCELLED',
  // Sessions
  SESSION_CREATED:     'SESSION_CREATED',
  SESSION_UPDATED:     'SESSION_UPDATED',
  SESSION_CANCELLED:   'SESSION_CANCELLED',
  SESSION_DELETED:     'SESSION_DELETED',
  ATTENDANCE_MARKED:   'ATTENDANCE_MARKED',
  // Support
  TICKET_CREATED:      'TICKET_CREATED',
  TICKET_RESOLVED:     'TICKET_RESOLVED',
  TICKET_CLOSED:       'TICKET_CLOSED',
  TICKET_REPLIED:      'TICKET_REPLIED',
  // Staff / Members
  TRAINER_ADDED:       'TRAINER_ADDED',
  TRAINER_REMOVED:     'TRAINER_REMOVED',
  MEMBER_ADDED:        'MEMBER_ADDED',
  MEMBER_ACTIVATED:    'MEMBER_ACTIVATED',
  MEMBER_UPDATED:      'MEMBER_UPDATED',
  MEMBER_REMOVED:      'MEMBER_REMOVED',
  // Plans
  PLAN_CREATED:        'PLAN_CREATED',
  PLAN_UPDATED:        'PLAN_UPDATED',
  PLAN_DELETED:        'PLAN_DELETED',
  // Automations
  AUTOMATION_FIRED:    'AUTOMATION_FIRED',
  // Announcements
  ANNOUNCEMENT_PUBLISHED: 'ANNOUNCEMENT_PUBLISHED',
} as const;

export type AuditActionKey = typeof AuditAction[keyof typeof AuditAction];

// ─── Service ──────────────────────────────────────────────────────────────────

export class AuditLogService {

  /**
   * Fire-and-forget — never awaited by callers, never throws.
   */
  static log(
    gymId: string,
    actorId: string,
    action: AuditActionKey,
    entity: string,
    label: string,
    entityId?: string,
    metadata?: Record<string, any>
  ): void {
    prismaAny.auditLog.create({
      data: { gymId, actorId, action, entity, label, entityId: entityId ?? null, metadata: metadata ?? null },
    }).catch(() => { /* never throw */ });
  }

  /**
   * List audit logs for a gym — paginated, optional action filter.
   */
  static async list(
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    options: { action?: string; from?: string; to?: string; page?: number } = {}
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);

    const page   = Math.max(1, options.page ?? 1);
    const take   = 50;
    const skip   = (page - 1) * take;

    const where: any = { gymId };
    if (options.action) where.action = options.action;
    if (options.from || options.to) {
      where.createdAt = {};
      if (options.from) where.createdAt.gte = new Date(options.from);
      if (options.to)   where.createdAt.lte = new Date(options.to);
    }

    const [total, logs] = await Promise.all([
      prismaAny.auditLog.count({ where }),
      prismaAny.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take,
        include: {
          actor: { select: { id: true, fullName: true, email: true, avatarUrl: true, role: true } },
        },
      }),
    ]);

    return { logs, total, page, pages: Math.ceil(total / take) };
  }

  // ─── Private ───────────────────────────────────────────────────────────────

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

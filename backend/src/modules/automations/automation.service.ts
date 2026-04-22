import prisma from '../../lib/prisma';
import { NotificationService } from '../notifications/notification.service';
import logger from '../../lib/logger';

// ─── Types ────────────────────────────────────────────────────────────────────

export type AutomationTrigger =
  | 'INACTIVE_14D'
  | 'INACTIVE_30D'
  | 'EXPIRY_5D'
  | 'EXPIRY_1D'
  | 'JUST_EXPIRED'
  | 'NEW_MEMBER_DAY1'
  | 'NEW_MEMBER_DAY3'
  | 'NEW_MEMBER_DAY7';

export const TRIGGER_LABELS: Record<AutomationTrigger, string> = {
  INACTIVE_14D: '14-Day Inactivity Win-Back',
  INACTIVE_30D: '30-Day Inactivity Win-Back',
  EXPIRY_5D: 'Membership Expiring in 5 Days',
  EXPIRY_1D: 'Membership Expiring Tomorrow',
  JUST_EXPIRED: 'Membership Just Expired',
  NEW_MEMBER_DAY1: 'Welcome – Day 1',
  NEW_MEMBER_DAY3: 'Onboarding – Day 3',
  NEW_MEMBER_DAY7: 'Onboarding – Day 7',
};

export const ALL_TRIGGERS = Object.keys(TRIGGER_LABELS) as AutomationTrigger[];

// ─── Service ──────────────────────────────────────────────────────────────────

export class AutomationService {

  /**
   * Process ALL active automation rules across all gyms.
   * Called by the hourly setInterval in index.ts.
   */
  static async processAll(): Promise<void> {
    const prismaAny = prisma as any;
    const rules = await prismaAny.automationRule.findMany({
      where: { isActive: true },
    });

    logger.info('[Automations] Processing rules', { count: rules.length });

    for (const rule of rules) {
      try {
        await this.processRule(rule, null);
      } catch (err) {
        logger.error('[Automations] Rule failed', { ruleId: rule.id, ruleName: rule.name, err });
      }
    }
  }

  /**
   * Process a single rule.
   * windowMs: override how far back to look (null = use time since lastRunAt, default 2h).
   */
  static async processRule(rule: any, windowMsOverride: number | null): Promise<number> {
    const now = new Date();
    const windowMs = windowMsOverride !== null
      ? windowMsOverride
      : rule.lastRunAt
        ? now.getTime() - new Date(rule.lastRunAt).getTime()
        : 2 * 60 * 60 * 1000; // 2h default for first run

    const userIds = await this.resolveTriggeredUsers(
      rule.gymId,
      rule.trigger as AutomationTrigger,
      now,
      windowMs
    );

    if (userIds.length > 0) {
      await NotificationService.sendBulk({
        userIds,
        type: 'SYSTEM' as any,
        title: rule.subject || rule.name,
        body: rule.body,
        data: { automationRuleId: rule.id, gymId: rule.gymId },
        channels: rule.channels as Array<'PUSH' | 'EMAIL' | 'IN_APP'>,
      });
    }

    const prismaAny = prisma as any;
    await prismaAny.automationRule.update({
      where: { id: rule.id },
      data: {
        lastRunAt: now,
        totalFired: rule.totalFired + userIds.length,
      },
    });

    return userIds.length;
  }

  // ─── Trigger resolvers ────────────────────────────────────────────────────

  private static async resolveTriggeredUsers(
    gymId: string,
    trigger: AutomationTrigger,
    now: Date,
    windowMs: number
  ): Promise<string[]> {
    switch (trigger) {
      case 'INACTIVE_14D':  return this.getInactiveMembers(gymId, 14, now, windowMs);
      case 'INACTIVE_30D':  return this.getInactiveMembers(gymId, 30, now, windowMs);
      case 'EXPIRY_5D':     return this.getExpiringMembers(gymId, 5, now, windowMs);
      case 'EXPIRY_1D':     return this.getExpiringMembers(gymId, 1, now, windowMs);
      case 'JUST_EXPIRED':  return this.getJustExpiredMembers(gymId, now, windowMs);
      case 'NEW_MEMBER_DAY1': return this.getNewMembers(gymId, 1, now, windowMs);
      case 'NEW_MEMBER_DAY3': return this.getNewMembers(gymId, 3, now, windowMs);
      case 'NEW_MEMBER_DAY7': return this.getNewMembers(gymId, 7, now, windowMs);
    }
  }

  /**
   * Active members whose LAST check-in crossed the `days`-day threshold within this window.
   * e.g. INACTIVE_14D: last check-in was between (now-14d-window) and (now-14d).
   */
  private static async getInactiveMembers(
    gymId: string,
    days: number,
    now: Date,
    windowMs: number
  ): Promise<string[]> {
    const thresholdEnd   = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    const thresholdStart = new Date(thresholdEnd.getTime() - windowMs);

    const activeMemberships = await prisma.gymMembership.findMany({
      where: { gymId, status: 'ACTIVE' },
      select: { userId: true },
    });
    const activeIds = activeMemberships.map((m) => m.userId);
    if (activeIds.length === 0) return [];

    const lastCheckIns = await prisma.attendance.findMany({
      where: { gymId, userId: { in: activeIds } },
      orderBy: { checkIn: 'desc' },
      distinct: ['userId'],
      select: { userId: true, checkIn: true },
    });

    return lastCheckIns
      .filter((a) => a.checkIn >= thresholdStart && a.checkIn <= thresholdEnd)
      .map((a) => a.userId);
  }

  /**
   * Active memberships whose endDate is exactly `days` days away (±window).
   */
  private static async getExpiringMembers(
    gymId: string,
    days: number,
    now: Date,
    windowMs: number
  ): Promise<string[]> {
    const expiryStart = new Date(now.getTime() + days * 24 * 60 * 60 * 1000 - windowMs);
    const expiryEnd   = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

    const memberships = await prisma.gymMembership.findMany({
      where: { gymId, status: 'ACTIVE', endDate: { gte: expiryStart, lte: expiryEnd } },
      select: { userId: true },
    });
    return memberships.map((m) => m.userId);
  }

  /**
   * Memberships that expired within the last `windowMs`.
   */
  private static async getJustExpiredMembers(
    gymId: string,
    now: Date,
    windowMs: number
  ): Promise<string[]> {
    const since = new Date(now.getTime() - windowMs);
    const memberships = await prisma.gymMembership.findMany({
      where: { gymId, status: 'EXPIRED', endDate: { gte: since, lte: now } },
      select: { userId: true },
    });
    return memberships.map((m) => m.userId);
  }

  /**
   * Members whose membership startDate was exactly `days` days ago (±window).
   */
  private static async getNewMembers(
    gymId: string,
    days: number,
    now: Date,
    windowMs: number
  ): Promise<string[]> {
    const joinedStart = new Date(now.getTime() - days * 24 * 60 * 60 * 1000 - windowMs);
    const joinedEnd   = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);

    const memberships = await prisma.gymMembership.findMany({
      where: { gymId, startDate: { gte: joinedStart, lte: joinedEnd } },
      select: { userId: true },
      distinct: ['userId'],
    });
    return memberships.map((m) => m.userId);
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  static async list(gymId: string): Promise<any[]> {
    const prismaAny = prisma as any;
    return prismaAny.automationRule.findMany({
      where: { gymId },
      orderBy: { createdAt: 'asc' },
    });
  }

  static async create(gymId: string, data: {
    name: string;
    trigger: string;
    subject?: string;
    body: string;
    channels: string[];
  }): Promise<any> {
    const prismaAny = prisma as any;
    return prismaAny.automationRule.create({
      data: {
        gymId,
        name: data.name,
        trigger: data.trigger,
        subject: data.subject || null,
        body: data.body,
        channels: data.channels,
        isActive: true,
      },
    });
  }

  static async update(id: string, gymId: string, data: {
    name?: string;
    subject?: string;
    body?: string;
    channels?: string[];
    isActive?: boolean;
  }): Promise<any> {
    const prismaAny = prisma as any;
    const rule = await prismaAny.automationRule.findFirst({ where: { id, gymId } });
    if (!rule) throw Object.assign(new Error('Rule not found'), { status: 404 });
    return prismaAny.automationRule.update({ where: { id }, data });
  }

  static async deleteRule(id: string, gymId: string): Promise<void> {
    const prismaAny = prisma as any;
    const rule = await prismaAny.automationRule.findFirst({ where: { id, gymId } });
    if (!rule) throw Object.assign(new Error('Rule not found'), { status: 404 });
    await prismaAny.automationRule.delete({ where: { id } });
  }

  /**
   * Manually trigger a rule using a 24h look-back window.
   */
  static async runNow(id: string, gymId: string): Promise<{ fired: number }> {
    const prismaAny = prisma as any;
    const rule = await prismaAny.automationRule.findFirst({ where: { id, gymId } });
    if (!rule) throw Object.assign(new Error('Rule not found'), { status: 404 });

    const fired = await this.processRule(rule, 24 * 60 * 60 * 1000);
    return { fired };
  }
}

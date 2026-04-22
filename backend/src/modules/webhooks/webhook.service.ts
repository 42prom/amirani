import crypto from 'crypto';
import axios from 'axios';
import prisma from '../../utils/prisma';
import { Role } from '@prisma/client';

const prismaAny = prisma as any;

// ─── Supported events ────────────────────────────────────────────────────────

export const WEBHOOK_EVENTS = [
  'member.created',
  'member.cancelled',
  'membership.frozen',
  'membership.unfrozen',
  'payment.received',
  'session.created',
  'session.cancelled',
  'checkin.recorded',
  'support.ticket_created',
] as const;

export type WebhookEvent = typeof WEBHOOK_EVENTS[number];

// ─── Service ──────────────────────────────────────────────────────────────────

export class WebhookService {

  /**
   * Fire-and-forget — dispatches event to all active matching endpoints.
   * Never throws. Logs delivery result for each endpoint.
   */
  static dispatch(gymId: string, event: WebhookEvent, payload: object): void {
    prismaAny.webhookEndpoint.findMany({
      where: { gymId, isActive: true, events: { has: event } },
    }).then(async (endpoints: any[]) => {
      for (const ep of endpoints) {
        const body = JSON.stringify({
          event,
          data: payload,
          timestamp: new Date().toISOString(),
          gymId,
        });
        const sig = crypto.createHmac('sha256', ep.secret).update(body).digest('hex');
        const start = Date.now();

        try {
          const res = await axios.post(ep.url, body, {
            headers: {
              'Content-Type': 'application/json',
              'X-Amirani-Signature': `sha256=${sig}`,
              'X-Amirani-Event': event,
            },
            timeout: 10000,
            validateStatus: () => true, // don't throw on non-2xx
          });

          await prismaAny.webhookDelivery.create({
            data: {
              endpointId: ep.id,
              event,
              payload,
              statusCode: res.status,
              responseBody: String(res.data ?? '').slice(0, 500),
              success: res.status >= 200 && res.status < 300,
              duration: Date.now() - start,
            },
          });
        } catch (err: any) {
          await prismaAny.webhookDelivery.create({
            data: {
              endpointId: ep.id,
              event,
              payload,
              statusCode: null,
              responseBody: (err.message ?? 'Unknown error').slice(0, 500),
              success: false,
              duration: Date.now() - start,
            },
          });
        }
      }
    }).catch(() => { /* never surface */ });
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  static async list(gymId: string, adminId: string, role: Role, managedGymId: string | null | undefined) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    return prismaAny.webhookEndpoint.findMany({
      where: { gymId },
      orderBy: { createdAt: 'asc' },
      include: {
        _count: { select: { deliveries: true } },
      },
    });
  }

  static async create(
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: { url: string; events: string[] }
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    if (!data.url || !data.url.startsWith('http')) {
      throw Object.assign(new Error('Invalid URL'), { status: 400 });
    }
    if (!data.events?.length) {
      throw Object.assign(new Error('At least one event is required'), { status: 400 });
    }
    return prismaAny.webhookEndpoint.create({
      data: {
        gymId,
        url: data.url,
        secret: crypto.randomBytes(24).toString('hex'),
        events: data.events,
        isActive: true,
      },
    });
  }

  static async update(
    endpointId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    data: { url?: string; events?: string[]; isActive?: boolean }
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const ep = await prismaAny.webhookEndpoint.findFirst({ where: { id: endpointId, gymId } });
    if (!ep) throw Object.assign(new Error('Endpoint not found'), { status: 404 });

    const updateData: any = {};
    if (data.url !== undefined)      updateData.url = data.url;
    if (data.events !== undefined)   updateData.events = data.events;
    if (data.isActive !== undefined) updateData.isActive = data.isActive;

    return prismaAny.webhookEndpoint.update({ where: { id: endpointId }, data: updateData });
  }

  static async delete(
    endpointId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const ep = await prismaAny.webhookEndpoint.findFirst({ where: { id: endpointId, gymId } });
    if (!ep) throw Object.assign(new Error('Endpoint not found'), { status: 404 });
    await prismaAny.webhookEndpoint.delete({ where: { id: endpointId } });
    return { deleted: true };
  }

  static async rotateSecret(
    endpointId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const ep = await prismaAny.webhookEndpoint.findFirst({ where: { id: endpointId, gymId } });
    if (!ep) throw Object.assign(new Error('Endpoint not found'), { status: 404 });
    return prismaAny.webhookEndpoint.update({
      where: { id: endpointId },
      data: { secret: crypto.randomBytes(24).toString('hex') },
    });
  }

  static async getDeliveries(
    endpointId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    page = 1
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const ep = await prismaAny.webhookEndpoint.findFirst({ where: { id: endpointId, gymId } });
    if (!ep) throw Object.assign(new Error('Endpoint not found'), { status: 404 });

    const take = 30;
    const skip = (page - 1) * take;
    const [total, deliveries] = await Promise.all([
      prismaAny.webhookDelivery.count({ where: { endpointId } }),
      prismaAny.webhookDelivery.findMany({
        where: { endpointId },
        orderBy: { attemptedAt: 'desc' },
        skip,
        take,
      }),
    ]);

    return { deliveries, total, page, pages: Math.ceil(total / take) };
  }

  // ─── Private ──────────────────────────────────────────────────────────────

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

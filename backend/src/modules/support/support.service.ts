import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import { AuditLogService } from '../audit/audit.service';

// ─── Types ────────────────────────────────────────────────────────────────────

export type TicketStatus   = 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'CLOSED';
export type TicketPriority = 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';

// ─── Service ──────────────────────────────────────────────────────────────────

export class SupportService {

  // ─── Member: create ticket ─────────────────────────────────────────────────

  static async createTicket(gymId: string, userId: string, subject: string, body: string, priority: TicketPriority = 'MEDIUM') {
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw Object.assign(new Error('Gym not found'), { status: 404 });

    const prismaAny = prisma as any;

    const ticket = await prismaAny.supportTicket.create({
      data: { gymId, userId, subject, status: 'OPEN', priority },
      include: {
        user: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
      },
    });

    // Create the first message
    await prismaAny.ticketMessage.create({
      data: { ticketId: ticket.id, senderId: userId, body, isStaff: false },
    });

    // Notify gym owner AND branch admins (find their userIds)
    const staff = await prisma.user.findMany({
      where: {
        OR: [
          { id: gym.ownerId },
          { role: Role.BRANCH_ADMIN, managedGymId: gymId }
        ],
        isActive: true
      },
      select: { id: true }
    });

    for (const person of staff) {
      await NotificationService.send({
        userId: person.id,
        type: 'SYSTEM' as any,
        title: `New Support Ticket`,
        body: `${ticket.user.fullName}: "${subject}"`,
        data: { ticketId: ticket.id, gymId },
        channels: ['PUSH', 'IN_APP'],
      });
    }

    return ticket;
  }

  // ─── Member: list own tickets ─────────────────────────────────────────────

  static async listForMember(userId: string, gymId: string) {
    const prismaAny = prisma as any;
    return prismaAny.supportTicket.findMany({
      where: { userId, gymId },
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { messages: true } } },
    });
  }

  // ─── Admin: list tickets ───────────────────────────────────────────────────

  static async listForGym(
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    filters: { status?: string; priority?: string } = {}
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const prismaAny = prisma as any;

    const where: any = { gymId };
    if (filters.status)   where.status   = filters.status;
    if (filters.priority) where.priority = filters.priority;

    const tickets = await prismaAny.supportTicket.findMany({
      where,
      orderBy: [
        { updatedAt: 'desc' },
      ],
      include: {
        user: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
        _count: { select: { messages: true } },
      },
    });

    // Removed invalid audit log
    return tickets;
  }

  // ─── Get single ticket with full thread ───────────────────────────────────

  static async getTicket(
    ticketId: string,
    gymId: string,
    requesterId: string,
    role: Role,
    managedGymId: string | null | undefined
  ) {
    const prismaAny = prisma as any;
    const ticket = await prismaAny.supportTicket.findFirst({
      where: { id: ticketId, gymId },
      include: {
        user: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            sender: { select: { id: true, fullName: true, avatarUrl: true } },
          },
        },
      },
    });

    if (!ticket) throw Object.assign(new Error('Ticket not found'), { status: 404 });

    // Allow access: admin, member who owns the ticket, or assigned trainer for TRAINER_CONVERSATION
    const isAdmin = await this.canAccess(gymId, requesterId, role, managedGymId);
    const isAssignedTrainer = ticket.ticketType === 'TRAINER_CONVERSATION' && ticket.trainerId != null
      && await this.isTrainerForTicket(requesterId, ticket.trainerId);

    if (!isAdmin && !isAssignedTrainer && ticket.userId !== requesterId) {
      throw Object.assign(new Error('Access denied'), { status: 403 });
    }

    // Mark messages as read
    if (isAdmin || isAssignedTrainer) {
      await prismaAny.ticketMessage.updateMany({
        where: { ticketId, isStaff: false, readAt: null },
        data: { readAt: new Date() },
      });
    }

    return ticket;
  }

  // ─── Reply to ticket ───────────────────────────────────────────────────────

  static async reply(
    ticketId: string,
    gymId: string,
    senderId: string,
    role: Role,
    managedGymId: string | null | undefined,
    body: string
  ) {
    const prismaAny = prisma as any;
    const ticket = await prismaAny.supportTicket.findFirst({ 
      where: { id: ticketId, gymId },
      include: { gym: true }
    });
    if (!ticket) throw Object.assign(new Error('Ticket not found'), { status: 404 });
    if (ticket.status === 'CLOSED') throw Object.assign(new Error('Ticket is closed'), { status: 400 });

    const isAdmin = await this.canAccess(gymId, senderId, role, managedGymId);
    const isAssignedTrainer = ticket.ticketType === 'TRAINER_CONVERSATION' && ticket.trainerId != null
      && await this.isTrainerForTicket(senderId, ticket.trainerId);
    const isStaff = isAdmin || isAssignedTrainer;

    if (!isStaff && ticket.userId !== senderId) {
      throw Object.assign(new Error('Access denied'), { status: 403 });
    }

    const message = await prismaAny.ticketMessage.create({
      data: { ticketId, senderId, body, isStaff },
      include: { sender: { select: { id: true, fullName: true, avatarUrl: true } } },
    });

    // Auto-transition: if staff replies to OPEN ticket → IN_PROGRESS
    if (isStaff && ticket.status === 'OPEN') {
      await prismaAny.supportTicket.update({
        where: { id: ticketId },
        data: { status: 'IN_PROGRESS', updatedAt: new Date() },
      });
    }
    // If member replies to RESOLVED → re-open to IN_PROGRESS
    if (!isStaff && ticket.status === 'RESOLVED') {
      await prismaAny.supportTicket.update({
        where: { id: ticketId },
        data: { status: 'IN_PROGRESS', updatedAt: new Date() },
      });
    }

    // Notify the other party
    if (isStaff) {
      // Notify member
      await NotificationService.send({
        userId: ticket.userId,
        type: 'SYSTEM' as any,
        title: isAssignedTrainer ? `Message from Coach ${message.sender.fullName} 💬` : `Support Reply: ${message.sender.fullName} 💬`,
        body: body.length > 100 ? body.slice(0, 97) + '…' : body,
        data: { ticketId, gymId, path: '/gym' },
        channels: ['PUSH', 'IN_APP'],
      });
    } else {
      // Member replied
      if (ticket.ticketType === 'TRAINER_CONVERSATION' && ticket.trainerId) {
        // Notify the assigned trainer (via their user account)
        const prismaAny = prisma as any;
        const trainerProfile = await prismaAny.trainerProfile.findUnique({
          where: { id: ticket.trainerId },
          select: { userId: true },
        });
        if (trainerProfile?.userId) {
          await NotificationService.send({
            userId: trainerProfile.userId,
            type: 'SYSTEM' as any,
            title: `Member Message: ${message.sender.fullName} 💬`,
            body: body.length > 100 ? body.slice(0, 97) + '…' : body,
            data: { ticketId, gymId, path: '/gym' },
            channels: ['PUSH', 'IN_APP'],
          });
        }
      } else {
        // Standard support: notify gym owner AND branch admins
        const staff = await prisma.user.findMany({
          where: {
            OR: [
              { id: ticket.gym.ownerId },
              { role: Role.BRANCH_ADMIN, managedGymId: gymId }
            ],
            isActive: true
          },
          select: { id: true }
        });
        for (const person of staff) {
          await NotificationService.send({
            userId: person.id,
            type: 'SYSTEM' as any,
            title: `Member Replied: ${message.sender.fullName} 💬`,
            body: body.length > 100 ? body.slice(0, 97) + '…' : body,
            data: { ticketId, gymId, path: '/gym' },
            channels: ['PUSH', 'IN_APP'],
          });
        }
      }
    }

    return message;
  }

  // ─── Update status ─────────────────────────────────────────────────────────

  static async updateStatus(
    ticketId: string,
    gymId: string,
    adminId: string,
    role: Role,
    managedGymId: string | null | undefined,
    status: TicketStatus
  ) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const prismaAny = prisma as any;
    const ticket = await prismaAny.supportTicket.findFirst({ where: { id: ticketId, gymId } });
    if (!ticket) throw Object.assign(new Error('Ticket not found'), { status: 404 });

    const updated = await prismaAny.supportTicket.update({
      where: { id: ticketId },
      data: { status, updatedAt: new Date() },
    });

    AuditLogService.log(gymId, adminId, status === 'RESOLVED' ? 'TICKET_RESOLVED' : status === 'CLOSED' ? 'TICKET_CLOSED' : 'TICKET_REPLIED', 'ticket', `Marked ticket "${ticket.subject}" as ${status.toLowerCase()}`, ticketId);

    // Notify member when resolved/closed
    if (status === 'RESOLVED' || status === 'CLOSED') {
      await NotificationService.send({
        userId: ticket.userId,
        type: 'SYSTEM' as any,
        title: status === 'RESOLVED' ? 'Ticket Resolved ✅' : 'Ticket Closed 🔒',
        body: `Your support ticket "${ticket.subject}" has been ${status.toLowerCase()}.`,
        data: { ticketId, gymId, path: '/gym' },
        channels: ['PUSH', 'IN_APP'],
      });
    }

    return updated;
  }

  // ─── Trainer: create / get conversation with a member ─────────────────────

  /**
   * Opens or retrieves a TRAINER_CONVERSATION ticket between a member and their assigned trainer.
   * If one already exists (OPEN or IN_PROGRESS), returns it. Otherwise creates a new one.
   */
  static async openTrainerConversation(gymId: string, memberId: string, trainerId: string) {
    const prismaAny = prisma as any;

    // Verify the trainer is actually assigned to this member
    const membership = await prismaAny.gymMembership.findFirst({
      where: { userId: memberId, gymId, trainerId },
    });
    if (!membership) throw Object.assign(new Error('Trainer not assigned to you'), { status: 403 });

    const trainer = await prismaAny.trainerProfile.findUnique({
      where: { id: trainerId },
      select: { id: true, fullName: true, userId: true },
    });
    if (!trainer) throw Object.assign(new Error('Trainer not found'), { status: 404 });

    // Return existing open conversation if one exists
    const existing = await prismaAny.supportTicket.findFirst({
      where: {
        gymId, userId: memberId, trainerId,
        ticketType: 'TRAINER_CONVERSATION',
        status: { notIn: ['CLOSED'] },
      },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' },
          include: { sender: { select: { id: true, fullName: true, avatarUrl: true } } },
        },
      },
    });
    if (existing) return existing;

    // Create new conversation ticket
    const ticket = await prismaAny.supportTicket.create({
      data: {
        gymId, userId: memberId, trainerId,
        subject: `Chat with ${trainer.fullName}`,
        status: 'OPEN', priority: 'MEDIUM',
        ticketType: 'TRAINER_CONVERSATION',
      },
      include: {
        messages: {
          orderBy: { createdAt: 'asc' },
          include: { sender: { select: { id: true, fullName: true, avatarUrl: true } } },
        },
      },
    });

    return ticket;
  }

  /**
   * Trainer: list all trainer-conversation tickets they are assigned to.
   */
  static async listTrainerConversations(trainerUserId: string) {
    const prismaAny = prisma as any;
    const trainerProfile = await prismaAny.trainerProfile.findFirst({ where: { userId: trainerUserId } });
    if (!trainerProfile) throw Object.assign(new Error('Trainer profile not found'), { status: 404 });

    return prismaAny.supportTicket.findMany({
      where: { trainerId: trainerProfile.id, ticketType: 'TRAINER_CONVERSATION' },
      orderBy: { updatedAt: 'desc' },
      include: {
        user: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
        _count: { select: { messages: true } },
      },
    });
  }

  // ─── Gym stats ─────────────────────────────────────────────────────────────

  static async getStats(gymId: string, adminId: string, role: Role, managedGymId: string | null | undefined) {
    await this.assertAccess(gymId, adminId, role, managedGymId);
    const prismaAny = prisma as any;

    const [open, inProgress, resolved, closed, urgent] = await Promise.all([
      prismaAny.supportTicket.count({ where: { gymId, status: 'OPEN' } }),
      prismaAny.supportTicket.count({ where: { gymId, status: 'IN_PROGRESS' } }),
      prismaAny.supportTicket.count({ where: { gymId, status: 'RESOLVED' } }),
      prismaAny.supportTicket.count({ where: { gymId, status: 'CLOSED' } }),
      prismaAny.supportTicket.count({ where: { gymId, priority: 'URGENT', status: { notIn: ['RESOLVED', 'CLOSED'] } } }),
    ]);

    return { open, inProgress, resolved, closed, urgent, total: open + inProgress + resolved + closed };
  }

  // ─── Private ───────────────────────────────────────────────────────────────

  private static async isTrainerForTicket(userId: string, trainerId: string): Promise<boolean> {
    const prismaAny = prisma as any;
    const profile = await prismaAny.trainerProfile.findFirst({ where: { userId } });
    return profile?.id === trainerId;
  }

  private static async assertAccess(gymId: string, userId: string, role: Role, managedGymId: string | null | undefined) {
    if (!(await this.canAccess(gymId, userId, role, managedGymId))) {
      throw Object.assign(new Error('Access denied'), { status: 403 });
    }
  }

  private static async canAccess(gymId: string, userId: string, role: Role, managedGymId: string | null | undefined): Promise<boolean> {
    if (role === Role.SUPER_ADMIN) return true;
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) return false;
    return gym.ownerId === userId || (role === Role.BRANCH_ADMIN && gym.id === managedGymId);
  }
}

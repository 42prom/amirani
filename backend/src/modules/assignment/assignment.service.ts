import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';

const db = prisma as any;

// ─── Service ──────────────────────────────────────────────────────────────────

export class AssignmentService {

  // ─── Member: request a trainer ────────────────────────────────────────────

  static async requestTrainer(gymId: string, memberId: string, trainerId: string, message?: string) {
    // Verify trainer exists and belongs to this gym
    const trainer = await db.trainerProfile.findFirst({
      where: { id: trainerId, gymId },
    });
    if (!trainer) throw Object.assign(new Error('Trainer not found'), { status: 404 });

    // Member must have an active membership in this gym
    const membership = await db.gymMembership.findFirst({
      where: { userId: memberId, gymId, status: { in: ['ACTIVE', 'PENDING'] } },
    });
    if (!membership) throw Object.assign(new Error('No active membership found'), { status: 400 });

    // Prevent duplicate pending request
    const existing = await db.trainerAssignmentRequest.findFirst({
      where: { memberId, gymId, status: 'PENDING' },
    });
    if (existing) throw Object.assign(new Error('A pending request already exists'), { status: 409 });

    // Already has this trainer assigned
    if (membership.trainerId === trainerId) {
      throw Object.assign(new Error('You are already assigned to this trainer'), { status: 409 });
    }

    const request = await db.trainerAssignmentRequest.create({
      data: { gymId, memberId, trainerId, status: 'PENDING', message },
      include: {
        trainer: { select: { id: true, fullName: true, userId: true } },
        member: { select: { id: true, fullName: true } },
      },
    });

    // Notify trainer
    if (trainer.userId) {
      await NotificationService.send({
        userId: trainer.userId,
        type: 'SYSTEM' as any,
        title: 'New Assignment Request',
        body: `${request.member.fullName} wants to train with you`,
        data: { requestId: request.id, gymId },
        channels: ['PUSH', 'IN_APP'],
      });
    }

    return request;
  }

  // ─── Trainer: get pending requests ────────────────────────────────────────

  static async getPendingRequests(trainerUserId: string) {
    const trainerProfile = await db.trainerProfile.findFirst({
      where: { userId: trainerUserId },
    });
    if (!trainerProfile) throw Object.assign(new Error('Trainer profile not found'), { status: 404 });

    return db.trainerAssignmentRequest.findMany({
      where: { trainerId: trainerProfile.id, status: 'PENDING' },
      orderBy: { createdAt: 'desc' },
      include: {
        member: {
          select: {
            id: true, fullName: true, email: true, avatarUrl: true,
            weight: true, height: true, dob: true, gender: true,
          },
        },
        gym: { select: { id: true, name: true } },
      },
    });
  }

  // ─── Trainer: approve request ─────────────────────────────────────────────

  static async approveRequest(requestId: string, trainerUserId: string) {
    const trainerProfile = await db.trainerProfile.findFirst({ where: { userId: trainerUserId } });
    if (!trainerProfile) throw Object.assign(new Error('Trainer profile not found'), { status: 404 });

    const request = await db.trainerAssignmentRequest.findFirst({
      where: { id: requestId, trainerId: trainerProfile.id },
      include: { member: { select: { id: true, fullName: true } } },
    });
    if (!request) throw Object.assign(new Error('Request not found'), { status: 404 });
    if (request.status !== 'PENDING') throw Object.assign(new Error('Request is no longer pending'), { status: 400 });

    // Update request + assign trainer to membership in a transaction
    const [updatedRequest] = await db.$transaction([
      db.trainerAssignmentRequest.update({
        where: { id: requestId },
        data: { status: 'APPROVED', updatedAt: new Date() },
      }),
      db.gymMembership.updateMany({
        where: { userId: request.memberId, gymId: request.gymId },
        data: { trainerId: trainerProfile.id },
      }),
    ]);

    // Notify member
    await NotificationService.send({
      userId: request.memberId,
      type: 'SYSTEM' as any,
      title: 'Trainer Request Approved',
      body: `${trainerProfile.fullName} has accepted you as a member`,
      data: { requestId, gymId: request.gymId },
      channels: ['PUSH', 'IN_APP'],
    });

    return updatedRequest;
  }

  // ─── Trainer: reject request ──────────────────────────────────────────────

  static async rejectRequest(requestId: string, trainerUserId: string) {
    const trainerProfile = await db.trainerProfile.findFirst({ where: { userId: trainerUserId } });
    if (!trainerProfile) throw Object.assign(new Error('Trainer profile not found'), { status: 404 });

    const request = await db.trainerAssignmentRequest.findFirst({
      where: { id: requestId, trainerId: trainerProfile.id },
      include: { member: { select: { id: true, fullName: true } } },
    });
    if (!request) throw Object.assign(new Error('Request not found'), { status: 404 });
    if (request.status !== 'PENDING') throw Object.assign(new Error('Request is no longer pending'), { status: 400 });

    const updated = await db.trainerAssignmentRequest.update({
      where: { id: requestId },
      data: { status: 'REJECTED', updatedAt: new Date() },
    });

    // Notify member
    await NotificationService.send({
      userId: request.memberId,
      type: 'SYSTEM' as any,
      title: 'Trainer Request',
      body: `Your request to ${trainerProfile.fullName} was not accepted`,
      data: { requestId, gymId: request.gymId },
      channels: ['PUSH', 'IN_APP'],
    });

    return updated;
  }

  // ─── Either party: remove assignment ──────────────────────────────────────

  static async removeAssignment(gymId: string, memberId: string, requesterId: string, requesterRole: Role) {
    const membership = await db.gymMembership.findFirst({
      where: { userId: memberId, gymId },
    });
    if (!membership || !membership.trainerId) {
      throw Object.assign(new Error('No trainer assignment found'), { status: 404 });
    }

    // Authorization: member removes their own, or trainer removes assigned member
    if (requesterRole === Role.TRAINER) {
      const trainerProfile = await db.trainerProfile.findFirst({ where: { userId: requesterId } });
      if (!trainerProfile || trainerProfile.id !== membership.trainerId) {
        throw Object.assign(new Error('Access denied'), { status: 403 });
      }
    } else if (requesterId !== memberId) {
      throw Object.assign(new Error('Access denied'), { status: 403 });
    }

    // Clear trainer from membership and update most recent APPROVED request
    await db.$transaction([
      db.gymMembership.updateMany({
        where: { userId: memberId, gymId },
        data: { trainerId: null },
      }),
      db.trainerAssignmentRequest.updateMany({
        where: { memberId, gymId, status: 'APPROVED' },
        data: { status: 'REJECTED', updatedAt: new Date() },
      }),
    ]);

    return { success: true };
  }

  // ─── Member: get own request status ───────────────────────────────────────

  static async getMyRequest(gymId: string, memberId: string) {
    // Get current membership with trainer
    const membership = await db.gymMembership.findFirst({
      where: { userId: memberId, gymId },
      include: {
        trainer: {
          select: {
            id: true, fullName: true, specialization: true, avatarUrl: true,
            bio: true, isAvailable: true,
          },
        },
      },
    });

    const pendingRequest = await db.trainerAssignmentRequest.findFirst({
      where: { memberId, gymId, status: 'PENDING' },
      include: {
        trainer: { select: { id: true, fullName: true, specialization: true, avatarUrl: true } },
      },
    });

    return {
      assignedTrainer: membership?.trainer ?? null,
      pendingRequest: pendingRequest ?? null,
    };
  }

  // ─── Branch Manager: trainer assignment stats ─────────────────────────────

  static async getTrainerStats(gymId: string, adminId: string, role: Role, managedGymId: string | null | undefined) {
    // Verify access
    const gym = await prisma.gym.findUnique({ where: { id: gymId } });
    if (!gym) throw Object.assign(new Error('Gym not found'), { status: 404 });

    const hasAccess = role === Role.SUPER_ADMIN
      || gym.ownerId === adminId
      || (role === Role.BRANCH_ADMIN && gym.id === managedGymId);
    if (!hasAccess) throw Object.assign(new Error('Access denied'), { status: 403 });

    const trainers = await db.trainerProfile.findMany({
      where: { gymId },
      select: {
        id: true,
        fullName: true,
        specialization: true,
        avatarUrl: true,
        isAvailable: true,
        _count: { select: { assignedMembers: true } },
        assignmentRequests: {
          where: { status: 'PENDING' },
          select: { id: true },
        },
      },
    });

    return trainers.map((t: any) => ({
      id: t.id,
      fullName: t.fullName,
      specialization: t.specialization,
      avatarUrl: t.avatarUrl,
      isAvailable: t.isAvailable,
      assignedMemberCount: t._count.assignedMembers,
      pendingRequestCount: t.assignmentRequests.length,
    }));
  }
}

import prisma from '../../lib/prisma';
import { InvitationStatus } from '@prisma/client';
import crypto from 'crypto';
import logger from '../../lib/logger';
import { EmailNotificationProvider } from '../notifications/providers/email.provider';

const emailProvider = new EmailNotificationProvider();

async function sendInvitationEmail(email: string, token: string): Promise<void> {
  const frontendUrl = process.env.FRONTEND_URL || 'https://amirani.esme.ge';
  const registrationUrl = `${frontendUrl}/register-invite?token=${token}`;
  try {
    await emailProvider.send({
      userId: 'system',
      title: 'You\'ve been invited to Amirani',
      body: `You have been invited to join Amirani as a Gym Owner.\n\nClick the link below to complete your registration (expires in 7 days):\n\n${registrationUrl}`,
      data: { registrationUrl, token },
    }, email);
  } catch (err) {
    logger.warn('[Invitation] Failed to send invitation email — invitation created but email not delivered', { email, err });
  }
}

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class InvitationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'InvitationError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class InvitationService {
  private static EXPIRY_DAYS = 7; // Invitation expires in 7 days

  /**
   * Create a new invitation
   */
  static async createInvitation(email: string, invitedById: string) {
    // Check if email already has a pending invitation
    const existingInvitation = await prisma.invitation.findFirst({
      where: {
        email: email.toLowerCase(),
        status: InvitationStatus.PENDING,
        expiresAt: { gt: new Date() },
      },
    });

    if (existingInvitation) {
      throw new InvitationError('An active invitation already exists for this email');
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: email.toLowerCase() },
    });

    if (existingUser) {
      throw new InvitationError('A user with this email already exists');
    }

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + this.EXPIRY_DAYS);

    const invitation = await prisma.invitation.create({
      data: {
        email: email.toLowerCase(),
        inviteToken: crypto.randomUUID(),
        expiresAt,
        invitedById,
      },
    });

    await sendInvitationEmail(invitation.email, invitation.inviteToken);

    return invitation;
  }

  /**
   * Get all invitations
   */
  static async getAllInvitations() {
    // Update expired invitations
    await prisma.invitation.updateMany({
      where: {
        status: InvitationStatus.PENDING,
        expiresAt: { lt: new Date() },
      },
      data: {
        status: InvitationStatus.EXPIRED,
      },
    });

    return prisma.invitation.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Resend an invitation
   */
  static async resendInvitation(invitationId: string, invitedById: string) {
    const invitation = await prisma.invitation.findUnique({
      where: { id: invitationId },
    });

    if (!invitation) {
      throw new InvitationError('Invitation not found');
    }

    if (invitation.status === InvitationStatus.ACCEPTED) {
      throw new InvitationError('Invitation has already been accepted');
    }

    // Check if user already exists (might have registered elsewhere)
    const existingUser = await prisma.user.findUnique({
      where: { email: invitation.email },
    });

    if (existingUser) {
      throw new InvitationError('A user with this email already exists');
    }

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + this.EXPIRY_DAYS);

    const updated = await prisma.invitation.update({
      where: { id: invitationId },
      data: {
        inviteToken: crypto.randomUUID(),
        status: InvitationStatus.PENDING,
        expiresAt,
        invitedById,
      },
    });

    await sendInvitationEmail(invitation.email, updated.inviteToken);

    return updated;
  }

  /**
   * Validate an invitation token
   */
  static async validateInvitation(token: string) {
    const invitation = await prisma.invitation.findUnique({
      where: { inviteToken: token },
    });

    if (!invitation) {
      throw new InvitationError('Invalid invitation token');
    }

    if (invitation.status === InvitationStatus.ACCEPTED) {
      throw new InvitationError('Invitation has already been used');
    }

    if (invitation.status === InvitationStatus.EXPIRED || invitation.expiresAt < new Date()) {
      // Mark as expired if not already
      if (invitation.status !== InvitationStatus.EXPIRED) {
        await prisma.invitation.update({
          where: { id: invitation.id },
          data: { status: InvitationStatus.EXPIRED },
        });
      }
      throw new InvitationError('Invitation has expired');
    }

    return invitation;
  }

  /**
   * Accept an invitation (called during registration)
   */
  static async acceptInvitation(token: string, userId: string) {
    const invitation = await this.validateInvitation(token);

    return prisma.invitation.update({
      where: { id: invitation.id },
      data: {
        status: InvitationStatus.ACCEPTED,
        acceptedAt: new Date(),
        acceptedUserId: userId,
      },
    });
  }

  /**
   * Delete an invitation
   */
  static async deleteInvitation(invitationId: string) {
    const invitation = await prisma.invitation.findUnique({
      where: { id: invitationId },
    });

    if (!invitation) {
      throw new InvitationError('Invitation not found');
    }

    if (invitation.status === InvitationStatus.ACCEPTED) {
      throw new InvitationError('Cannot delete accepted invitation');
    }

    return prisma.invitation.delete({
      where: { id: invitationId },
    });
  }
}


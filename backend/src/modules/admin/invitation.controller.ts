import { Router, Response } from 'express';
import { InvitationService, InvitationError } from './invitation.service';
import { authenticate, superAdminOnly, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, created, badRequest, serverError } from '../../utils/response';
import logger from '../../utils/logger';

const router = Router();

/**
 * GET /admin/invitations/validate/:token
 * Validate an invitation token (public endpoint for registration page)
 * NOTE: This must be defined BEFORE the auth middleware
 */
router.get('/validate/:token', async (req, res: Response) => {
  try {
    const invitation = await InvitationService.validateInvitation(req.params.token);
    return success(res, {
      valid: true,
      email: invitation.email,
      expiresAt: invitation.expiresAt,
    });
  } catch (error: any) {
    if (error instanceof InvitationError) {
      return badRequest(res, error.message);
    }
    return serverError(res, 'Failed to validate invitation');
  }
});

// All remaining routes require Super Admin
router.use(authenticate, superAdminOnly);

/**
 * GET /admin/invitations
 * Get all invitations
 */
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const invitations = await InvitationService.getAllInvitations();
    return success(res, invitations);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /admin/invitations
 * Create a new invitation
 */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { email } = req.body;

    if (!email) {
      return badRequest(res, 'Email is required');
    }

    // Basic email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return badRequest(res, 'Invalid email format');
    }

    const invitation = await InvitationService.createInvitation(
      email,
      req.user!.userId
    );

    return created(res, invitation);
  } catch (error: any) {
    if (error instanceof InvitationError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * POST /admin/invitations/:id/resend
 * Resend an invitation
 */
router.post('/:id/resend', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const invitation = await InvitationService.resendInvitation(
      req.params.id,
      req.user!.userId
    );
    return success(res, invitation, 'Invitation resent');
  } catch (error: any) {
    if (error instanceof InvitationError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * DELETE /admin/invitations/:id
 * Delete an invitation
 */
router.delete('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await InvitationService.deleteInvitation(req.params.id);
    res.status(204).send();
  } catch (error: any) {
    if (error instanceof InvitationError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

export default router;

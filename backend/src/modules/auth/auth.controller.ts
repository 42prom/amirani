import { Router, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import {
  AuthService,
  ValidationError,
  ConflictError,
  AuthenticationError,
} from './auth.service';
import {
  created,
  success,
  validationError,
  conflict,
  unauthorized,
  internalError,
} from '../../utils/response';
import { OAuthService } from './oauth.service';
import { NotificationService } from '../notifications/notification.service';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { getFullUrl } from '../../utils/url';
import prisma from '../../lib/prisma';
import config from '../../config/env';
import logger from '../../lib/logger';
import { loginLimiter, registerLimiter, passwordLimiter } from '../../lib/rate-limiters';

const router = Router();

/**
 * GET /auth/me
 * Get current user profile from JWT
 */
router.get('/me', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AuthService.getUserProfile(req.user!.userId);
    if (!result) return unauthorized(res, 'User not found');
    success(res, {
      ...result,
      avatarUrl: getFullUrl(req, result.avatarUrl),
      idPhotoUrl: getFullUrl(req, result.idPhotoUrl),
    });
  } catch (err) {
    if (err instanceof AuthenticationError) {
      return unauthorized(res, err.message);
    }
    logger.error('Get profile error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/register
 * Register a new user (self-registration)
 * Only GYM_MEMBER and HOME_USER roles allowed
 */
router.post('/register', registerLimiter, async (req: Request, res: Response) => {
  try {
    const result = await AuthService.register(req.body);
    created(res, {
      ...result,
      user: {
        ...result.user,
        avatarUrl: getFullUrl(req, result.user.avatarUrl),
        idPhotoUrl: getFullUrl(req, result.user.idPhotoUrl),
      }
    });
  } catch (err) {
    if (err instanceof ValidationError) {
      return validationError(res, err.details);
    }
    if (err instanceof ConflictError) {
      return conflict(res, err.message);
    }
    logger.error('Register error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/register-invite
 * Register a new Gym Owner using an invitation token
 */
router.post('/register-invite', registerLimiter, async (req: Request, res: Response) => {
  try {
    const result = await AuthService.registerWithInvitation(req.body);
    success(res, {
      ...result,
      user: {
        ...result.user,
        avatarUrl: getFullUrl(req, result.user.avatarUrl),
        idPhotoUrl: getFullUrl(req, result.user.idPhotoUrl),
      }
    });
  } catch (err) {
    if (err instanceof ValidationError) {
      return validationError(res, err.details);
    }
    if (err instanceof ConflictError) {
      return conflict(res, err.message);
    }
    logger.error('Register with invitation error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/login
 * Authenticate a user and return JWT token
 */
router.post('/login', loginLimiter, async (req: Request, res: Response) => {
  try {
    const result = await AuthService.login(req.body);
    success(res, {
      ...result,
      user: {
        ...result.user,
        avatarUrl: getFullUrl(req, result.user.avatarUrl),
        idPhotoUrl: getFullUrl(req, result.user.idPhotoUrl),
      }
    });
  } catch (err) {
    if (err instanceof ValidationError) {
      return validationError(res, err.details);
    }
    if (err instanceof AuthenticationError) {
      return unauthorized(res, err.message);
    }
    logger.error('Login error', { err });
    internalError(res);
  }
});

/**
 * GET /auth/config
 * Get public OAuth and Push notification configuration (no secrets)
 */
router.get('/config', async (req: Request, res: Response) => {
  try {
    const [oauthConfig, pushConfig, aiConfig] = await Promise.all([
      OAuthService.getPublicConfig(),
      NotificationService.getPublicConfig(),
      prisma.aIConfig.findUnique({ where: { id: 'singleton' }, select: { isEnabled: true } }).catch(() => null),
    ]);

    const combinedConfig = {
      ...oauthConfig,
      ...pushConfig,
      // aiEnabled lets mobile decide before attempting plan generation whether AI is available.
      // Prevents silent polling timeouts when AI is globally disabled by super admin.
      aiEnabled: aiConfig?.isEnabled ?? false,
    };

    success(res, combinedConfig);
  } catch (err) {
    logger.error('Get auth config error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/refresh
 * Exchange a valid refresh token for a new access token + rotated refresh token.
 * Body: { refreshToken: string }
 */
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return validationError(res, [{ field: 'refreshToken', message: 'refreshToken is required' }]);
    }
    const result = await AuthService.refreshAccessToken(refreshToken);
    success(res, result);
  } catch (err) {
    if (err instanceof AuthenticationError) {
      return unauthorized(res, err.message);
    }
    logger.error('Refresh token error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/logout
 * Revoke a refresh token (logout current device).
 * Body: { refreshToken: string }
 */
router.post('/logout', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await AuthService.revokeRefreshToken(refreshToken);
    }
    success(res, { message: 'Logged out successfully' });
  } catch (err) {
    logger.error('Logout error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/logout-all
 * Revoke all refresh tokens for the current user (logout all devices).
 */
router.post('/logout-all', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    await AuthService.revokeAllRefreshTokens(req.user!.userId);
    success(res, { message: 'Logged out from all devices' });
  } catch (err) {
    logger.error('Logout all error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/oauth
 * Sign in / sign up via Google or Apple ID token.
 * Body: { provider: 'google' | 'apple', idToken: string }
 */
router.post('/oauth', loginLimiter, async (req: Request, res: Response) => {
  try {
    const { provider, idToken } = req.body;
    if (!provider || !idToken) {
      return validationError(res, [{ field: 'provider', message: 'provider and idToken are required' }]);
    }
    logger.info('[Auth] OAuth Login attempt', { provider });
    const result = await OAuthService.authenticate(provider, idToken);
    logger.info('[Auth] OAuth Login success', { userId: result.user.id });
    success(res, {
      ...result,
      user: {
        ...result.user,
        avatarUrl: getFullUrl(req, (result.user as any).avatarUrl),
        idPhotoUrl: getFullUrl(req, (result.user as any).idPhotoUrl),
      }
    });
  } catch (err) {
    if (err instanceof ValidationError) return validationError(res, err.details);
    if (err instanceof AuthenticationError) return unauthorized(res, (err as AuthenticationError).message);
    logger.error('OAuth error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/change-password
 * Forced password change for accounts with mustChangePassword=true (e.g. new Branch Admins).
 * Also works as a regular password change for any authenticated user.
 * Body: { currentPassword, newPassword }
 */
router.post('/change-password', authenticate, passwordLimiter, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, error: { message: 'currentPassword and newPassword are required' } });
    }
    await AuthService.changePassword(req.user!.userId, currentPassword, newPassword);
    return success(res, { changed: true });
  } catch (err) {
    if (err instanceof ValidationError) return validationError(res, err.details);
    if (err instanceof AuthenticationError) return unauthorized(res, err.message);
    internalError(res);
  }
});

/**
 * POST /auth/2fa/setup
 * Generate 2FA secret and QR code.
 */
router.post('/2fa/setup', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AuthService.setup2FA(req.user!.userId);
    success(res, result);
  } catch (err) {
    logger.error('2FA setup error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/2fa/enable
 * Verify first token and enable 2FA on account.
 */
router.post('/2fa/enable', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { token } = req.body;
    if (!token) return validationError(res, [{ field: 'token', message: 'token is required' }]);
    
    const result = await AuthService.enable2FA(req.user!.userId, token);
    success(res, result);
  } catch (err) {
    if (err instanceof AuthenticationError) return unauthorized(res, err.message);
    logger.error('2FA enable error', { err });
    internalError(res);
  }
});

/**
 * POST /auth/2fa/verify
 * Final verification during login flow.
 */
router.post('/2fa/verify', loginLimiter, async (req: Request, res: Response) => {
  try {
    const { email, token } = req.body;
    if (!email || !token) {
      return validationError(res, [
        { field: 'email', message: 'email is required' },
        { field: 'token', message: 'token is required' }
      ]);
    }
    
    const result = await AuthService.verify2FA(email, token);
    success(res, {
      ...result,
      user: {
        ...result.user,
        avatarUrl: getFullUrl(req, result.user.avatarUrl),
        idPhotoUrl: getFullUrl(req, result.user.idPhotoUrl),
      }
    });
  } catch (err) {
    if (err instanceof AuthenticationError) return unauthorized(res, err.message);
    logger.error('2FA verify error', { err });
    internalError(res);
  }
});

// ─── Development Token Generator ─────────────────────────────────────────────
// Only available when NODE_ENV=development.
// Returns real JWTs signed with the actual JWT_SECRET — identical format to
// production tokens. Go through normal jwt.verify() in authenticate().
// Call once: GET /api/auth/dev/tokens  → copy tokens into Postman / .env
if (config.nodeEnv === 'development') {
  router.get('/dev/tokens', async (_req: Request, res: Response) => {
    try {
      const DEV_EMAILS = {
        SUPER_ADMIN:  'super@amirani.dev',
        GYM_OWNER:    'owner@amirani.dev',
        BRANCH_ADMIN: 'branch@amirani.dev',
        TRAINER:      'trainer@amirani.dev',
        GYM_MEMBER:   'member@amirani.dev',
      };

      const users = await Promise.all(
        Object.entries(DEV_EMAILS).map(async ([role, email]) => {
          const user = await prisma.user.findUnique({
            where: { email },
            select: { id: true, role: true, managedGymId: true, email: true },
          });
          return { role, email, user };
        })
      );

      const tokens: Record<string, string | null> = {};
      const missing: string[] = [];

      for (const { role, email, user } of users) {
        if (!user) {
          missing.push(email);
          tokens[role] = null;
          continue;
        }
        tokens[role] = jwt.sign(
          { userId: user.id, role: user.role, managedGymId: user.managedGymId ?? null },
          config.jwt.secret,
          { expiresIn: '30d' }
        );
      }

      return res.json({
        success: true,
        note: 'DEV ONLY — real JWTs signed with JWT_SECRET. Use as: Authorization: Bearer <token>',
        missing: missing.length > 0
          ? `Run npm run db:seed to create: ${missing.join(', ')}`
          : undefined,
        tokens,
      });
    } catch (err) {
      logger.error('[DEV] Token generation error', { err });
      internalError(res);
    }
  });
}

export default router;


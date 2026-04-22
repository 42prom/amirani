import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Role } from '@prisma/client';
import config from '../config/env';
import { unauthorized, forbidden, notFound } from '../utils/response';
import prisma from '../utils/prisma';
import logger from '../utils/logger';


export interface AuthenticatedRequest extends Request {
  user?: {
    userId: string;
    role: Role;
    managedGymId?: string | null;
  };
  branchId?: string;
}

/**
 * Audit log entry for security events
 */
interface AuditLogEntry {
  timestamp: string;
  userId?: string;
  role?: Role;
  action: string;
  resource: string;
  branchId?: string;
  ip?: string;
  userAgent?: string;
  success: boolean;
  reason?: string;
}

/**
 * Log security audit events
 */
const logAuditEvent = (entry: AuditLogEntry): void => {
  // Always write to structured logger (searchable in log aggregators / CloudWatch / Datadog)
  logger.warn({ ...entry, timestamp: entry.timestamp || new Date().toISOString() }, '[SECURITY]');

  // Persist to DB only when we have a real gym context (branchId present).
  // Pre-auth events (failed logins without gymId) remain in structured logs only —
  // this avoids the Gym FK constraint. Both paths are auditable.
  if (entry.userId && entry.branchId) {
    setImmediate(async () => {
      try {
        await prisma.auditLog.create({
          data: {
            gymId: entry.branchId!,
            actorId: entry.userId!,
            action: entry.action,
            entity: 'auth',
            label: entry.reason ?? entry.action,
            metadata: {
              resource: entry.resource,
              ip: entry.ip,
              userAgent: entry.userAgent,
              success: entry.success,
              role: entry.role,
            },
          },
        });
      } catch (dbErr) {
        // DB write failure must NEVER break auth. Log and continue.
        logger.error({ dbErr }, '[AUDIT] Failed to persist security event to DB');
      }
    });
  }
};

/**
 * Extract client info for audit logging
 */
const getClientInfo = (req: Request): { ip: string; userAgent: string } => ({
  ip: (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.ip || 'unknown',
  userAgent: req.headers['user-agent'] || 'unknown',
});


/**
 * Middleware to verify JWT token
 */
export const authenticate = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logAuditEvent({
      timestamp: new Date().toISOString(),
      action: 'AUTHENTICATE',
      resource: req.originalUrl,
      success: false,
      reason: 'No token provided',
      ...getClientInfo(req),
    });
    return unauthorized(res, 'No token provided');
  }

  const token = authHeader.split(' ')[1];

  // ─── JWT Token Verification ────────────────────────────────────────────────
  try {
    const decoded = jwt.verify(token, config.jwt.secret) as {
      userId: string;
      role: Role;
      managedGymId?: string | null;
    };
    req.user = {
      userId: decoded.userId,
      role: decoded.role,
      managedGymId: decoded.managedGymId || null,
    };
    next();
  } catch (error) {
    logAuditEvent({
      timestamp: new Date().toISOString(),
      action: 'AUTHENTICATE',
      resource: req.originalUrl,
      success: false,
      reason: 'Invalid or expired token',
      ...getClientInfo(req),
    });
    return unauthorized(res, 'Invalid or expired token');
  }
};

/**
 * Middleware to check if user has required role(s)
 */
export const authorize = (...allowedRoles: Role[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return unauthorized(res, 'Not authenticated');
    }

    if (!allowedRoles.includes(req.user.role)) {
      return forbidden(res, 'Access denied. Insufficient permissions.');
    }

    next();
  };
};

/**
 * Middleware for Super Admin only routes
 */
export const superAdminOnly = authorize(Role.SUPER_ADMIN);

/**
 * Middleware for Gym Owner and above
 */
export const gymOwnerOrAbove = authorize(Role.SUPER_ADMIN, Role.GYM_OWNER);

/**
 * Middleware for Branch Admin and above
 */
export const branchAdminOrAbove = authorize(Role.SUPER_ADMIN, Role.GYM_OWNER, Role.BRANCH_ADMIN);

/**
 * Middleware for Trainer and above
 */
export const trainerOrAbove = authorize(Role.SUPER_ADMIN, Role.GYM_OWNER, Role.BRANCH_ADMIN, Role.TRAINER);

/**
 * Middleware to validate branch ownership
 * - BRANCH_ADMIN can only access their assigned branch (managedGymId)
 * - GYM_OWNER can access any branch they own
 * - SUPER_ADMIN can access any branch
 *
 * @param branchIdParam - The route parameter name for branch ID (default: 'gymId' or 'id')
 */
export const validateBranchOwnership = (branchIdParam: string = 'gymId') => {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return unauthorized(res, 'Not authenticated');
    }

    const branchId = req.params[branchIdParam] || req.params.id;
    if (!branchId) {
      return forbidden(res, 'Branch ID is required');
    }

    // Store branchId on request for downstream use
    req.branchId = branchId;

    const { userId, role, managedGymId } = req.user;
    const clientInfo = getClientInfo(req);

    // SUPER_ADMIN can access any branch
    if (role === Role.SUPER_ADMIN) {
      return next();
    }

    // BRANCH_ADMIN can only access their managed branch
    if (role === Role.BRANCH_ADMIN) {
      if (managedGymId !== branchId) {
        logAuditEvent({
          timestamp: new Date().toISOString(),
          userId,
          role,
          action: 'CROSS_BRANCH_ACCESS_ATTEMPT',
          resource: req.originalUrl,
          branchId,
          success: false,
          reason: `Branch Admin attempted to access branch ${branchId} but manages ${managedGymId}`,
          ...clientInfo,
        });
        return forbidden(res, 'Access denied. You can only access your assigned branch.');
      }
      return next();
    }

    // GYM_OWNER must own the branch
    if (role === Role.GYM_OWNER) {
      try {
        const gym = await prisma.gym.findUnique({
          where: { id: branchId },
          select: { id: true, ownerId: true },
        });

        if (!gym) {
          return notFound(res, 'Branch');
        }

        if (gym.ownerId !== userId) {
          logAuditEvent({
            timestamp: new Date().toISOString(),
            userId,
            role,
            action: 'UNAUTHORIZED_BRANCH_ACCESS',
            resource: req.originalUrl,
            branchId,
            success: false,
            reason: `Gym Owner attempted to access branch they don't own`,
            ...clientInfo,
          });
          return forbidden(res, 'Access denied. You do not own this branch.');
        }
        return next();
      } catch (error) {
        logger.error({ error }, 'Error validating branch ownership');
        return forbidden(res, 'Unable to verify branch ownership');
      }
    }

    // All other roles are denied
    logAuditEvent({
      timestamp: new Date().toISOString(),
      userId,
      role,
      action: 'UNAUTHORIZED_ACCESS_ATTEMPT',
      resource: req.originalUrl,
      branchId,
      success: false,
      reason: `Role ${role} attempted to access branch resource`,
      ...clientInfo,
    });
    return forbidden(res, 'Access denied. Insufficient permissions.');
  };
};

/**
 * Middleware to block BRANCH_ADMIN from financial/analytics endpoints
 */
export const blockFinancialAccess = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  if (!req.user) {
    return unauthorized(res, 'Not authenticated');
  }

  if (req.user.role === Role.BRANCH_ADMIN) {
    logAuditEvent({
      timestamp: new Date().toISOString(),
      userId: req.user.userId,
      role: req.user.role,
      action: 'FINANCIAL_ACCESS_BLOCKED',
      resource: req.originalUrl,
      success: false,
      reason: 'Branch Admin attempted to access financial data',
      ...getClientInfo(req),
    });
    return forbidden(res, 'Access denied. Financial data is restricted.');
  }

  next();
};

/**
 * Middleware to ensure only GYM_OWNER can access certain resources
 * (not even BRANCH_ADMIN)
 */
export const gymOwnerOnly = (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  if (!req.user) {
    return unauthorized(res, 'Not authenticated');
  }

  if (req.user.role !== Role.SUPER_ADMIN && req.user.role !== Role.GYM_OWNER) {
    logAuditEvent({
      timestamp: new Date().toISOString(),
      userId: req.user.userId,
      role: req.user.role,
      action: 'GYM_OWNER_ONLY_ACCESS_DENIED',
      resource: req.originalUrl,
      success: false,
      reason: `Role ${req.user.role} attempted to access owner-only resource`,
      ...getClientInfo(req),
    });
    return forbidden(res, 'Access denied. This action requires Gym Owner privileges.');
  }

  next();
};

/**
 * Combined middleware for branch admin or above with ownership validation
 * Use this for branch-scoped operations
 */
export const branchAdminWithOwnership = (branchIdParam: string = 'gymId') => {
  return [
    branchAdminOrAbove,
    validateBranchOwnership(branchIdParam),
  ];
};

/**
 * Middleware to enforce Trainer Siloing
 * Ensures a Trainer can only access data of users explicitly assigned to them.
 * Higher roles (Branch Admin, Gym Owner, Super Admin) bypass this check.
 */
export const validateTrainerClientRelation = (userIdParam: string = 'id') => {
  return async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) {
      return unauthorized(res, 'Not authenticated');
    }

    const targetUserId = req.params[userIdParam];
    if (!targetUserId) {
      return forbidden(res, 'Target user ID is required');
    }

    const { userId, role } = req.user;
    const clientInfo = getClientInfo(req);

    // Higher roles can access
    if (role === Role.SUPER_ADMIN || role === Role.GYM_OWNER || role === Role.BRANCH_ADMIN) {
      return next();
    }

    if (role === Role.TRAINER) {
      try {
        const trainerProfile = await prisma.trainerProfile.findUnique({
          where: { userId: userId },
        });

        if (!trainerProfile) {
          return forbidden(res, 'Trainer profile not found');
        }

        const membership = await prisma.gymMembership.findFirst({
          where: {
            userId: targetUserId,
            trainerId: trainerProfile.id,
          },
        });

        if (!membership) {
          logAuditEvent({
            timestamp: new Date().toISOString(),
            userId,
            role,
            action: 'UNAUTHORIZED_CLIENT_ACCESS',
            resource: req.originalUrl,
            success: false,
            reason: `Trainer attempted to access unassigned client ${targetUserId}`,
            ...clientInfo,
          });
          return forbidden(res, 'Access denied. You can only access records of clients assigned to you.');
        }

        return next();
      } catch (error) {
        logger.error({ error }, 'Error validating trainer client relation');
        return forbidden(res, 'Unable to verify trainer-client relationship');
      }
    }

    // Default deny for other roles accessing another user's records
    if (userId !== targetUserId) {
      return forbidden(res, 'Access denied.');
    }

    return next();
  };
};



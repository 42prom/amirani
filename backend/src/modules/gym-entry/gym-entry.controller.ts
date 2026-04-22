import { Router, Response, Request } from 'express';
import { getFullUrl } from '../../utils/url';
import prisma from '../../utils/prisma';
import { AccessControlService } from '../door-access/access-control.service';
import {
  authenticate,
  branchAdminOrAbove,
  validateBranchOwnership,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import { success, forbidden, badRequest, notFound, internalError } from '../../utils/response';
import { GymQrService } from './gym-qr.service';
import { awardPoints, POINTS } from '../../utils/leaderboard.service';
import logger from '../../utils/logger';

const router = Router();


// ─── QR Code: Generate (gym staff) ───────────────────────────────────────────

/**
 * POST /gym/qr/generate
 * Gym owner / branch admin generates a signed QR payload.
 * Body: { gymId: string, type: "GYM_JOIN" | "DAILY_CHECKIN" }
 */
router.post('/qr/generate', authenticate, branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, type } = req.body as { gymId?: string; type?: string };

    if (!gymId) return badRequest(res, 'gymId is required');
    if (type !== 'GYM_JOIN' && type !== 'DAILY_CHECKIN') {
      return badRequest(res, 'type must be GYM_JOIN or DAILY_CHECKIN');
    }

    const { qrData, expiresAt } = await GymQrService.generate(gymId, type);
    return success(res, { qrData, expiresAt });
  } catch (err: any) {
    if (err.status) return res.status(err.status).json({ success: false, error: { message: err.message } });
    logger.error({ err }, '[GymEntry] qr/generate error');
    internalError(res);
  }
});

// ─── QR Code: Verify + Join Gym (member scans) ───────────────────────────────

/**
 * POST /gym/qr/verify
 * Member scans a GYM_JOIN QR → validates → creates GymMembership (PENDING or ACTIVE).
 * Body: { qrData: string, planId: string }
 *
 * Note: does NOT create a GymMembership automatically (payment may be needed).
 * Instead returns gym details + join requirements so the mobile app can proceed.
 */
router.post('/qr/verify', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { qrData, planId } = req.body as { qrData?: string; planId?: string };

    if (!qrData) return badRequest(res, 'qrData is required');

    const result = await GymQrService.verify(qrData, userId);

    if (!result.valid) {
      return res.status(400).json({ success: false, error: { code: 'INVALID_QR', message: result.reason } });
    }

    if (result.type !== 'GYM_JOIN') {
      return badRequest(res, 'This QR code is for check-in, not gym joining');
    }

    // Return gym info for the join flow
    const gym = await prisma.gym.findUnique({
      where: { id: result.gymId },
      select: {
        id: true,
        name: true,
        address: true,
        city: true,
        logoUrl: true,
        registrationRequirements: true,
        subscriptionPlans: {
          where: { isActive: true },
          select: { id: true, name: true, price: true, durationValue: true, durationUnit: true, features: true },
          orderBy: { displayOrder: 'asc' },
        },
      },
    });

    if (!gym) return notFound(res, 'Gym');

    // Check if already a member
    const existingMembership = await prisma.gymMembership.findFirst({
      where: { userId, gymId: gym.id, status: { in: ['ACTIVE', 'PENDING', 'FROZEN'] } },
    });

    return success(res, {
      gym,
      alreadyMember: !!existingMembership,
      existingMembership,
    });
  } catch (err) {
    logger.error({ err }, '[GymEntry] qr/verify error');
    internalError(res);
  }
});

// ─── Member QR Check-In ───────────────────────────────────────────────────────

/**
 * POST /gym/check-in/qr
 * Called by the mobile app when a member scans the gym entrance QR code.
 *
 * QR payload format: amirani://checkin?gymId=<gymId>&token=<doorSystemId>
 * Body: { gymId: string, token: string }
 *
 * Flow:
 *  1. Authenticate member (JWT)
 *  2. Resolve door system from token
 *  3. Validate membership + time/day restrictions (AccessControlService)
 *  4. Log access attempt (DoorAccessLog)
 *  5. Anti-passback: return existing open session if already checked in
 *  6. Create attendance record
 *  7. Award +5 leaderboard points across all active rooms
 *  8. Return rich check-in payload (name, plan, expiry, session ID)
 */
router.post('/check-in/qr', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { gymId, token } = req.body as { gymId?: string; token?: string };

    if (!gymId || !token) {
      return badRequest(res, 'gymId and token are required');
    }

    // Verify HMAC signature + expiry. singleUse=false because this is a venue
    // QR displayed at the entrance and scanned by many members — per-user replay
    // is prevented by the anti-passback Attendance check below.
    const { GymQrService } = await import('./gym-qr.service');
    const qrVerify = await GymQrService.verify(
      decodeURIComponent(token),
      userId,
      { singleUse: false },
    );

    if (!qrVerify.valid) {
      return badRequest(res, qrVerify.reason ?? 'Invalid QR code. Please ask staff for a new one.');
    }

    if (qrVerify.gymId !== gymId) {
      return badRequest(res, 'QR code does not match this gym.');
    }

    // Resolve the active QR door system for this gym (used for access logging)
    const doorSystem = await prisma.doorSystem.findFirst({
      where: { gymId, type: 'QR_CODE', isActive: true },
      include: { gym: { select: { id: true, name: true } } },
    });

    if (!doorSystem) {
      return badRequest(res, 'No active door system found for this gym.');
    }

    // Validate access: membership, time/day restrictions → also logs to DoorAccessLog
    const access = await AccessControlService.validateAndLogAccess(
      userId,
      gymId,
      doorSystem.id,
      req.headers['user-agent']
    );

    if (!access.allowed) {
      return forbidden(res, access.reason || 'Access denied');
    }

    const membership = access.membership!;

    // ── Anti-passback: check for existing open session ────────────────────────
    const existingSession = await prisma.attendance.findFirst({
      where: { userId, gymId, checkOut: null },
    });

    const now = new Date();
    // Sessions expire at midnight (end of gym day) or 12h from check-in
    const sessionExpiry = new Date(Math.min(
      new Date(now).setHours(23, 59, 59, 999), // end of today
      now.getTime() + 12 * 60 * 60 * 1000       // or 12 hours max
    ));

    if (existingSession) {
      // Already checked in — return existing session (idempotent re-entry)
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { fullName: true },
      });

      const plan = await prisma.subscriptionPlan.findUnique({
        where: { id: (await prisma.gymMembership.findFirst({ where: { userId, gymId, status: 'ACTIVE' } }))?.planId ?? '' },
        select: { name: true },
      });

      const daysRemaining = Math.max(0, Math.ceil(
        (new Date(membership.endDate).getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
      ));

      return success(res, {
        checkInId: existingSession.id,
        gymId,
        gymName: doorSystem.gym.name,
        memberName: user?.fullName ?? 'Member',
        planName: plan?.name ?? membership.planName,
        daysRemaining,
        membershipEndsAt: membership.endDate,
        admittedAt: existingSession.checkIn.toISOString(),
        expiresAt: sessionExpiry.toISOString(),
        alreadyCheckedIn: true,
      });
    }

    // ── New check-in: create attendance record ────────────────────────────────
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { fullName: true, avatarUrl: true },
    });

    const memberMembership = await prisma.gymMembership.findFirst({
      where: { userId, gymId, status: 'ACTIVE' },
      include: { plan: { select: { name: true } } },
    });

    const attendance = await prisma.attendance.create({
      data: { userId, gymId },
    });

    // Award check-in points across all active rooms (fire-and-forget)
    awardPoints({
      userId,
      sourceId: attendance.id,
      sourceType: 'CHECKIN',
      delta: POINTS.CHECKIN,
      reason: `Gym check-in at ${doorSystem.gym.name}`,
    }).catch((err) => logger.error({ err }, '[GymEntry] awardPoints error'));

    const daysRemaining = Math.max(0, Math.ceil(
      (new Date(membership.endDate).getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
    ));

    return success(res, {
      checkInId: attendance.id,
      gymId,
      gymName: doorSystem.gym.name,
      memberName: user?.fullName ?? 'Member',
      planName: memberMembership?.plan?.name ?? membership.planName,
      daysRemaining,
      membershipEndsAt: membership.endDate,
      admittedAt: attendance.checkIn.toISOString(),
      expiresAt: sessionExpiry.toISOString(),
      alreadyCheckedIn: false,
    });
  } catch (err) {
    logger.error({ err }, '[GymEntry] check-in/qr error');
    internalError(res);
  }
});

// ─── Member NFC Check-In ──────────────────────────────────────────────────────

/**
 * POST /gym/check-in/nfc
 * Called by mobile when a member taps their phone on the NFC reader at the entrance.
 * Body: { gymId: string }
 *
 * Follows the same access-control flow as QR check-in.
 */
router.post('/check-in/nfc', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { gymId } = req.body as { gymId?: string };

    if (!gymId) {
      return badRequest(res, 'gymId is required');
    }

    const doorSystem = await prisma.doorSystem.findFirst({
      where: { gymId, type: 'NFC', isActive: true },
    });

    if (!doorSystem) {
      return notFound(res, 'No active NFC door system for this gym');
    }

    const access = await AccessControlService.validateAndLogAccess(
      userId,
      gymId,
      doorSystem.id,
      req.headers['user-agent']
    );

    if (!access.allowed) {
      return forbidden(res, access.reason || 'Access denied');
    }

    // Anti-passback: return existing open session
    const existingSession = await prisma.attendance.findFirst({
      where: { userId, gymId, checkOut: null },
    });

    if (existingSession) {
      return success(res, {
        id: existingSession.id,
        gymId,
        timestamp: existingSession.checkIn.toISOString(),
        isSuccess: true,
        message: 'Access Granted: Already checked in',
      });
    }

    const attendance = await prisma.attendance.create({
      data: { userId, gymId },
    });

    // Award check-in points across all active rooms (fire-and-forget)
    awardPoints({
      userId,
      sourceId: attendance.id,
      sourceType: 'CHECKIN',
      delta: POINTS.CHECKIN,
      reason: `NFC check-in at gym ${gymId}`,
    }).catch((err) => logger.error({ err }, '[GymEntry] awardPoints error'));

    return success(res, {
      id: attendance.id,
      gymId,
      timestamp: attendance.checkIn.toISOString(),
      isSuccess: true,
      message: 'Access Granted: Welcome!',
    });
  } catch (err) {
    logger.error({ err }, '[GymEntry] check-in/nfc error');
    internalError(res);
  }
});

// ─── Member Gym Details ───────────────────────────────────────────────────────

/**
 * GET /gym/details/:gymId
 * Returns limited gym details accessible to any authenticated user.
 * GYM_MEMBER: must have an active membership in the gym.
 * Staff roles (BRANCH_ADMIN, GYM_OWNER, SUPER_ADMIN): unrestricted.
 */
router.get('/details/:gymId', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId } = req.params;
    const userId = req.user!.userId;
    const role = req.user!.role;

    const gym = await prisma.gym.findUnique({
      where: { id: gymId, isActive: true },
      include: {
        trainers: {
          include: {
            user: {
              select: {
                fullName: true,
                avatarUrl: true,
              }
            }
          }
        },
        equipment: true,
      },
    });

    if (!gym) {
      return notFound(res, 'Gym');
    }

    // Members must have an active membership in this gym
    if (role === 'GYM_MEMBER' || role === 'HOME_USER') {
      const membership = await prisma.gymMembership.findFirst({
        where: { userId, gymId, status: 'ACTIVE' },
      });
      if (!membership) {
        return forbidden(res, 'No active membership for this gym');
      }
    }

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const currentOccupancy = await prisma.attendance.count({
      where: { gymId, checkOut: null, checkIn: { gte: todayStart } },
    });

    return success(res, {
      id: gym.id,
      name: gym.name,
      address: gym.address,
      currentOccupancy,
      maxCapacity: 0,
      registrationRequirements: gym.registrationRequirements,
      trainers: gym.trainers.map(t => ({
        id: t.id,
        fullName: t.fullName || t.user?.fullName || 'Anonymous Trainer',
        specialization: t.specialization,
        bio: t.bio,
        avatarUrl: getFullUrl(req, t.avatarUrl || t.user?.avatarUrl),
        isAvailable: t.isAvailable,
      })),
      equipment: gym.equipment.map(e => e.name),
    });
  } catch (err) {
    logger.error({ err }, '[GymEntry] details error');
    internalError(res);
  }
});

// ─── Member Check-Out ─────────────────────────────────────────────────────────

/**
 * POST /gym/check-out
 * Called when a member exits the gym (manual exit from app session).
 * Body: { gymId: string }
 */
router.post('/check-out', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { gymId } = req.body as { gymId?: string };

    if (!gymId) {
      return badRequest(res, 'gymId is required');
    }

    const session = await prisma.attendance.findFirst({
      where: { userId, gymId, checkOut: null },
    });

    if (!session) {
      return badRequest(res, 'No active check-in found');
    }

    const checkOutTime = new Date();
    const duration = Math.round(
      (checkOutTime.getTime() - session.checkIn.getTime()) / (1000 * 60)
    );

    await prisma.attendance.update({
      where: { id: session.id },
      data: { checkOut: checkOutTime, duration },
    });

    return success(res, { checkedOut: true, duration, checkOut: checkOutTime.toISOString() });
  } catch (err) {
    logger.error({ err }, '[GymEntry] check-out error');
    internalError(res);
  }
});

// ─── Live Gym Status (Branch Manager Dashboard) ───────────────────────────────

/**
 * GET /gym/live/:gymId
 * Returns real-time occupancy and today's attendance for branch manager.
 * Shows who is currently in the gym.
 */
router.get(
  '/live/:gymId',
  authenticate,
  branchAdminOrAbove,
  validateBranchOwnership('gymId'),
  async (req: AuthenticatedRequest, res: Response) => {
    try {
      const { gymId } = req.params;

      const gym = await prisma.gym.findUnique({
        where: { id: gymId },
        select: { id: true, name: true },
      });

      if (!gym) {
        return notFound(res, 'Gym');
      }

      // Members currently inside (checked in, no checkout)
      const currentlyIn = await prisma.attendance.findMany({
        where: { gymId, checkOut: null },
        include: {
          user: {
            select: { id: true, fullName: true, avatarUrl: true },
          },
        },
        orderBy: { checkIn: 'desc' },
      });

      // Membership plan info for currently-in members
      const memberIds = currentlyIn.map((a) => a.userId);
      const memberships = await prisma.gymMembership.findMany({
        where: { userId: { in: memberIds }, gymId, status: 'ACTIVE' },
        include: { plan: { select: { name: true } } },
      });
      const planByUser = Object.fromEntries(memberships.map((m) => [m.userId, m.plan?.name ?? 'Member']));

      // Today's total check-in count
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayTotal = await prisma.attendance.count({
        where: { gymId, checkIn: { gte: todayStart } },
      });

      const currentOccupancy = currentlyIn.length;

      return success(res, {
        gymId,
        gymName: gym.name,
        currentOccupancy,
        maxCapacity: null,
        occupancyPercent: null,
        todayCheckIns: todayTotal,
        currentlyIn: currentlyIn.map((a) => ({
          attendanceId: a.id,
          userId: a.userId,
          fullName: a.user.fullName,
          avatarUrl: a.user.avatarUrl,
          planName: planByUser[a.userId] ?? 'Member',
          checkInTime: a.checkIn.toISOString(),
          minutesInGym: Math.round((Date.now() - a.checkIn.getTime()) / 60000),
        })),
      });
    } catch (err) {
      logger.error({ err }, '[GymEntry] live error');
      internalError(res);
    }
  }
);

export default router;



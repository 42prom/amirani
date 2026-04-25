import { Router, Response } from 'express';
import prisma from '../../lib/prisma';
import { StripeConnectService, StripeConnectError } from './stripe-connect.service';
import {
  authenticate,
  gymOwnerOrAbove,
  branchAdminOrAbove,
  validateBranchOwnership,
  AuthenticatedRequest,
} from '../../middleware/auth.middleware';
import { success, created, notFound, forbidden, badRequest, serverError } from '../../utils/response';
import { Role, DayOfWeek } from '@prisma/client';
import logger from '../../lib/logger';

const router = Router();

// All routes require branch admin or above
router.use(authenticate, branchAdminOrAbove);

// ─── Stripe Connect (Owner Only) ──────────────────────────────────────────────
router.use('/gyms/:gymId/stripe', gymOwnerOrAbove);
router.use('/gyms/:gymId/earnings', gymOwnerOrAbove);

/**
 * GET /gym-owner/gyms/:gymId/stripe/status
 * Get Stripe Connect status for a gym
 */
router.get('/gyms/:gymId/stripe/status', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const status = await StripeConnectService.getAccountStatus(req.params.gymId);
    return success(res, status);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /gym-owner/gyms/:gymId/stripe/onboard
 * Start Stripe Connect onboarding
 */
router.post('/gyms/:gymId/stripe/onboard', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const { returnUrl, refreshUrl } = req.body;

    if (!returnUrl || !refreshUrl) {
      return badRequest(res, 'returnUrl and refreshUrl are required');
    }

    const link = await StripeConnectService.createOnboardingLink(
      req.params.gymId,
      returnUrl,
      refreshUrl
    );

    return success(res, link);
  } catch (error: any) {
    if (error instanceof StripeConnectError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * GET /gym-owner/gyms/:gymId/stripe/dashboard
 * Get Stripe Express Dashboard link
 */
router.get('/gyms/:gymId/stripe/dashboard', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const link = await StripeConnectService.createDashboardLink(req.params.gymId);
    return success(res, link);
  } catch (error: any) {
    if (error instanceof StripeConnectError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * GET /gym-owner/gyms/:gymId/earnings
 * Get gym earnings/revenue
 */
router.get('/gyms/:gymId/earnings', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const { startDate, endDate } = req.query;

    const earnings = await StripeConnectService.getGymEarnings(req.params.gymId, {
      startDate: startDate ? new Date(startDate as string) : undefined,
      endDate: endDate ? new Date(endDate as string) : undefined,
    });

    return success(res, earnings);
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── Subscription Plans (Branch Admin and Above) ──────────────────────────────

/**
 * GET /gym-owner/gyms/:gymId/subscription-plans
 * Get all subscription plans for a gym
 */
router.get('/gyms/:gymId/subscription-plans', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }

    const plans = await prisma.subscriptionPlan.findMany({
      where: { gymId: req.params.gymId },
      orderBy: [{ displayOrder: 'asc' }, { price: 'asc' }],
      include: {
        _count: {
          select: { memberships: true },
        },
      },
    });

    return success(res, plans);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /gym-owner/gyms/:gymId/subscription-plans
 * Create a new subscription plan
 */
router.post('/gyms/:gymId/subscription-plans', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }

    const {
      name,
      description,
      price,
      durationValue,
      durationUnit,
      features,
      hasTimeRestriction,
      accessStartTime,
      accessEndTime,
      accessDays,
      planType,
      displayOrder,
    } = req.body;

    if (!name || price === undefined) {
      return badRequest(res, 'Name and price are required');
    }

    // Validate time restriction fields
    if (hasTimeRestriction) {
      if (!accessStartTime || !accessEndTime) {
        return badRequest(res, 'accessStartTime and accessEndTime are required for time-restricted plans');
      }
      // Validate time format (HH:MM)
      const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
      if (!timeRegex.test(accessStartTime) || !timeRegex.test(accessEndTime)) {
        return badRequest(res, 'Time must be in HH:MM format (24-hour)');
      }
    }

    const plan = await prisma.subscriptionPlan.create({
      data: {
        gymId: req.params.gymId,
        name,
        description,
        price,
        durationValue: durationValue || 30,
        durationUnit: durationUnit || 'days',
        features: features || [],
        hasTimeRestriction: hasTimeRestriction || false,
        accessStartTime,
        accessEndTime,
        accessDays: accessDays || ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'],
        planType: planType || 'full',
        displayOrder: displayOrder || 0,
      },
    });

    return created(res, plan);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /gym-owner/subscription-plans/:planId
 * Update a subscription plan
 */
router.patch('/subscription-plans/:planId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: req.params.planId },
      include: { gym: true },
    });

    if (!plan) {
      return notFound(res, 'Plan not found');
    }

    const isBranchAdmin = req.user!.role === Role.BRANCH_ADMIN && plan.gym.id === req.user!.managedGymId;
    if (req.user!.role !== Role.SUPER_ADMIN && plan.gym.ownerId !== req.user!.userId && !isBranchAdmin) {
      return forbidden(res, 'Access denied');
    }

    const {
      name,
      description,
      price,
      durationValue,
      durationUnit,
      features,
      hasTimeRestriction,
      accessStartTime,
      accessEndTime,
      accessDays,
      planType,
      displayOrder,
      isActive,
    } = req.body;

    // Validate time format if provided
    if (accessStartTime || accessEndTime) {
      const timeRegex = /^([01]\d|2[0-3]):([0-5]\d)$/;
      if (accessStartTime && !timeRegex.test(accessStartTime)) {
        return badRequest(res, 'accessStartTime must be in HH:MM format (24-hour)');
      }
      if (accessEndTime && !timeRegex.test(accessEndTime)) {
        return badRequest(res, 'accessEndTime must be in HH:MM format (24-hour)');
      }
    }

    const updatedPlan = await prisma.subscriptionPlan.update({
      where: { id: req.params.planId },
      data: {
        name,
        description,
        price,
        durationValue,
        durationUnit,
        features,
        hasTimeRestriction,
        accessStartTime,
        accessEndTime,
        accessDays,
        planType,
        displayOrder,
        isActive,
      },
    });

    return success(res, updatedPlan);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * DELETE /gym-owner/subscription-plans/:planId
 * Delete a subscription plan (soft delete - just deactivate)
 */
router.delete('/subscription-plans/:planId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: req.params.planId },
      include: {
        gym: true,
        _count: { select: { memberships: true } },
      },
    });

    if (!plan) {
      return notFound(res, 'Plan not found');
    }

    const isBranchAdmin = req.user!.role === Role.BRANCH_ADMIN && plan.gym.id === req.user!.managedGymId;
    if (req.user!.role !== Role.SUPER_ADMIN && plan.gym.ownerId !== req.user!.userId && !isBranchAdmin) {
      return forbidden(res, 'Access denied');
    }

    // If plan has active memberships, just deactivate
    if (plan._count.memberships > 0) {
      await prisma.subscriptionPlan.update({
        where: { id: req.params.planId },
        data: { isActive: false },
      });
      return success(res, { message: 'Plan deactivated (has active memberships)' });
    }

    // Otherwise, delete it
    await prisma.subscriptionPlan.delete({
      where: { id: req.params.planId },
    });

    res.status(204).send();
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /gym-owner/gyms/:gymId/subscription-plans/templates
 * Create plans from templates (morning, evening, full, etc.)
 */
router.post('/gyms/:gymId/subscription-plans/templates', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const { templates, basePrice } = req.body;

    if (!templates || !Array.isArray(templates) || !basePrice) {
      return badRequest(res, 'templates array and basePrice are required');
    }

    const allDays: DayOfWeek[] = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const weekdays: DayOfWeek[] = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY'];
    const weekend: DayOfWeek[] = ['SATURDAY', 'SUNDAY'];

    const templateConfigs: Record<string, any> = {
      full: {
        name: 'Full Access',
        description: 'Unlimited access anytime',
        planType: 'full',
        hasTimeRestriction: false,
        accessDays: allDays,
        priceMultiplier: 1,
        displayOrder: 1,
      },
      morning: {
        name: 'Morning Access',
        description: 'Access from 6:00 to 12:00',
        planType: 'morning',
        hasTimeRestriction: true,
        accessStartTime: '06:00',
        accessEndTime: '12:00',
        accessDays: allDays,
        priceMultiplier: 0.7,
        displayOrder: 2,
      },
      evening: {
        name: 'Evening Access',
        description: 'Access from 17:00 to 22:00',
        planType: 'evening',
        hasTimeRestriction: true,
        accessStartTime: '17:00',
        accessEndTime: '22:00',
        accessDays: allDays,
        priceMultiplier: 0.7,
        displayOrder: 3,
      },
      weekday: {
        name: 'Weekday Access',
        description: 'Monday to Friday access',
        planType: 'weekday',
        hasTimeRestriction: true,
        accessStartTime: '06:00',
        accessEndTime: '22:00',
        accessDays: weekdays,
        priceMultiplier: 0.8,
        displayOrder: 4,
      },
      weekend: {
        name: 'Weekend Access',
        description: 'Saturday and Sunday access',
        planType: 'weekend',
        hasTimeRestriction: true,
        accessStartTime: '08:00',
        accessEndTime: '20:00',
        accessDays: weekend,
        priceMultiplier: 0.5,
        displayOrder: 5,
      },
      student: {
        name: 'Student Plan',
        description: 'Discounted access for students (off-peak hours)',
        planType: 'custom',
        hasTimeRestriction: true,
        accessStartTime: '10:00',
        accessEndTime: '16:00',
        accessDays: weekdays,
        priceMultiplier: 0.5,
        displayOrder: 6,
      },
    };

    const createdPlans: any[] = [];

    for (const template of templates) {
      const config = templateConfigs[template];
      if (!config) continue;

      const plan = await prisma.subscriptionPlan.create({
        data: {
          gymId: req.params.gymId,
          name: config.name,
          description: config.description,
          price: Math.round(basePrice * config.priceMultiplier * 100) / 100,
          durationValue: 30,
          durationUnit: 'days',
          features: [],
          planType: config.planType,
          hasTimeRestriction: config.hasTimeRestriction,
          accessStartTime: config.accessStartTime,
          accessEndTime: config.accessEndTime,
          accessDays: config.accessDays,
          displayOrder: config.displayOrder,
        },
      });

      createdPlans.push(plan);
    }

    return created(res, createdPlans);
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── Equipment / Inventory (Branch Admin and Above) ──────────────────────────

/**
 * GET /gym-owner/gyms/:gymId/equipment
 * Get all equipment with enhanced details
 */
router.get('/gyms/:gymId/equipment', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }

    const { category, status, search } = req.query;

    const where: any = { gymId: req.params.gymId };
    if (category) where.category = category;
    if (status) where.status = status;
    if (search) {
      where.OR = [
        { name: { contains: search as string, mode: 'insensitive' } },
        { brand: { contains: search as string, mode: 'insensitive' } },
        { model: { contains: search as string, mode: 'insensitive' } },
        { notes: { contains: search as string, mode: 'insensitive' } },
      ];
    }

    const equipment = await prisma.equipment.findMany({
      where,
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });

    return success(res, equipment);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /gym-owner/gyms/:gymId/equipment
 * Add new equipment
 */
router.post('/gyms/:gymId/equipment', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const {
      name,
      category,
      brand,
      model,
      quantity,
      status,
      description,
      imageUrl,
      serialNumber,
      purchasePrice,
      purchaseDate,
      warrantyExpiry,
      location,
      notes,
    } = req.body;

    if (!name || !category) {
      return badRequest(res, 'Name and category are required');
    }

    const equipment = await prisma.equipment.create({
      data: {
        gymId: req.params.gymId,
        name,
        category,
        brand,
        model,
        quantity: quantity || 1,
        status: status || 'AVAILABLE',
        description,
        imageUrl,
        serialNumber,
        purchasePrice,
        purchaseDate: purchaseDate ? new Date(purchaseDate) : undefined,
        warrantyExpiry: warrantyExpiry ? new Date(warrantyExpiry) : undefined,
        location,
        notes,
      },
    });

    return created(res, equipment);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /gym-owner/equipment/:equipmentId
 * Update equipment
 */
router.patch('/equipment/:equipmentId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const equipment = await prisma.equipment.findUnique({
      where: { id: req.params.equipmentId },
      include: { gym: true },
    });

    if (!equipment) {
      return notFound(res, 'Equipment not found');
    }

    const isBranchAdmin = req.user!.role === Role.BRANCH_ADMIN && equipment.gymId === req.user!.managedGymId;
    if (req.user!.role !== Role.SUPER_ADMIN && equipment.gym.ownerId !== req.user!.userId && !isBranchAdmin) {
      return forbidden(res, 'Access denied');
    }

    const updated = await prisma.equipment.update({
      where: { id: req.params.equipmentId },
      data: req.body,
    });

    return success(res, updated);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * DELETE /gym-owner/equipment/:equipmentId
 * Delete equipment
 */
router.delete('/equipment/:equipmentId', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const equipment = await prisma.equipment.findUnique({
      where: { id: req.params.equipmentId },
      include: { gym: true },
    });

    if (!equipment) {
      return notFound(res, 'Equipment not found');
    }

    const isBranchAdmin = req.user!.role === Role.BRANCH_ADMIN && equipment.gymId === req.user!.managedGymId;
    if (req.user!.role !== Role.SUPER_ADMIN && equipment.gym.ownerId !== req.user!.userId && !isBranchAdmin) {
      return forbidden(res, 'Access denied');
    }

    await prisma.equipment.delete({
      where: { id: req.params.equipmentId },
    });

    res.status(204).send();
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /gym-owner/gyms/:gymId/equipment/categories
 * Get equipment categories with counts
 */
router.get('/gyms/:gymId/equipment/categories', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }

    const categories = await prisma.equipment.groupBy({
      by: ['category'],
      where: { gymId: req.params.gymId },
      _count: { id: true },
      _sum: { quantity: true },
    });

    return success(res, categories);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /gym-owner/gyms/:gymId/equipment/stats
 * Get equipment statistics (total, available, maintenance, out of order)
 */
router.get('/gyms/:gymId/equipment/stats', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }

    const stats = await prisma.equipment.groupBy({
      by: ['status'],
      where: { gymId: req.params.gymId },
      _count: { id: true },
      _sum: { quantity: true },
    });

    const result = {
      total: stats.reduce((acc: number, s: any) => acc + (s._sum.quantity || 0), 0),
      available: stats.find((s: any) => s.status === 'AVAILABLE')?._sum.quantity || 0,
      maintenance: stats.find((s: any) => s.status === 'MAINTENANCE')?._sum.quantity || 0,
      outOfOrder: stats.find((s: any) => s.status === 'OUT_OF_ORDER')?._sum.quantity || 0,
    };

    return success(res, result);
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── Equipment Catalog (Read-only Browse) ────────────────────────────────────

/**
 * GET /gym-owner/catalog
 * Browse the global equipment catalog (read-only for gym owners)
 */
router.get('/catalog', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { category, brand, search } = req.query;

    const where: any = { isActive: true };

    if (category) {
      where.category = category;
    }

    if (brand) {
      where.brand = brand;
    }

    if (search) {
      where.OR = [
        { name: { contains: search as string, mode: 'insensitive' } },
        { brand: { contains: search as string, mode: 'insensitive' } },
        { model: { contains: search as string, mode: 'insensitive' } },
        { description: { contains: search as string, mode: 'insensitive' } },
      ];
    }

    const catalogItems = await prisma.equipmentCatalog.findMany({
      where,
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });

    return success(res, catalogItems);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /gym-owner/gyms/:gymId/equipment/from-catalog/:catalogItemId
 * Add equipment to gym from catalog item
 */
router.post('/gyms/:gymId/equipment/from-catalog/:catalogItemId', validateBranchOwnership(), async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gym = await prisma.gym.findUnique({ where: { id: req.params.gymId } });

    if (!gym) {
      return notFound(res, 'Gym not found');
    }


    const catalogItem = await prisma.equipmentCatalog.findUnique({
      where: { id: req.params.catalogItemId },
    });

    if (!catalogItem) {
      return notFound(res, 'Catalog item not found');
    }

    if (!catalogItem.isActive) {
      return badRequest(res, 'This catalog item is no longer available');
    }

    const { quantity, location, serialNumber, purchasePrice, notes } = req.body;

    // Create equipment from catalog item
    const equipment = await prisma.equipment.create({
      data: {
        gymId: req.params.gymId,
        catalogItemId: catalogItem.id,
        name: catalogItem.name,
        category: catalogItem.category,
        brand: catalogItem.brand,
        model: catalogItem.model,
        description: catalogItem.description,
        imageUrl: catalogItem.imageUrl,
        quantity: quantity || 1,
        location,
        serialNumber,
        purchasePrice,
        notes,
        status: 'AVAILABLE',
      },
    });

    return created(res, equipment);
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── Branch Management (Gym Owner Only) ──────────────────────────────────────

async function assertGymOwnership(gymId: string, userId: string, role: Role) {
  const gym = await prisma.gym.findUnique({ where: { id: gymId } });
  if (!gym) throw Object.assign(new Error('Gym not found'), { status: 404 });
  if (role !== Role.SUPER_ADMIN && gym.ownerId !== userId) {
    throw Object.assign(new Error('Access denied'), { status: 403 });
  }
  return gym;
}

/**
 * GET /gym-owner/gyms/:gymId/branches
 * List all branches for a gym with live member/trainer/checkin counts.
 */
router.get('/gyms/:gymId/branches', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId } = req.params;
    await assertGymOwnership(gymId, req.user!.userId, req.user!.role);

    const branches = await prisma.branch.findMany({
      where: { gymId },
      orderBy: { createdAt: 'asc' },
      include: {
        admins: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
      },
    });

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const branchesWithStats = await Promise.all(
      branches.map(async (branch) => {
        const [activeMembers, trainerCount, todayCheckins] = await Promise.all([
          prisma.gymMembership.count({ where: { gymId, status: 'ACTIVE' } }),
          prisma.trainerProfile.count({ where: { gymId } }),
          prisma.attendance.count({ where: { gymId, checkIn: { gte: todayStart } } }),
        ]);
        return { ...branch, activeMembers, trainerCount, todayCheckins };
      }),
    );

    return success(res, branchesWithStats);
  } catch (err: any) {
    return res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /gym-owner/gyms/:gymId/branches
 * Create a new branch.
 */
router.post('/gyms/:gymId/branches', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId } = req.params;
    await assertGymOwnership(gymId, req.user!.userId, req.user!.role);

    const { name, address, city, phone, maxCapacity, openTime, closeTime } = req.body;
    if (!name) return badRequest(res, 'name is required');

    const branch = await prisma.branch.create({
      data: { gymId, name, address, city, phone, maxCapacity: maxCapacity ?? 50, openTime, closeTime },
    });
    return created(res, branch);
  } catch (err: any) {
    return res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * PATCH /gym-owner/gyms/:gymId/branches/:branchId
 * Update branch details.
 */
router.patch('/gyms/:gymId/branches/:branchId', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, branchId } = req.params;
    await assertGymOwnership(gymId, req.user!.userId, req.user!.role);

    const branch = await prisma.branch.findUnique({ where: { id: branchId } });
    if (!branch || branch.gymId !== gymId) return notFound(res, 'Branch not found');

    const { name, address, city, phone, maxCapacity, openTime, closeTime, isActive } = req.body;
    const updated = await prisma.branch.update({
      where: { id: branchId },
      data: {
        ...(name !== undefined && { name }),
        ...(address !== undefined && { address }),
        ...(city !== undefined && { city }),
        ...(phone !== undefined && { phone }),
        ...(maxCapacity !== undefined && { maxCapacity }),
        ...(openTime !== undefined && { openTime }),
        ...(closeTime !== undefined && { closeTime }),
        ...(isActive !== undefined && { isActive }),
      },
    });
    return success(res, updated);
  } catch (err: any) {
    return res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * DELETE /gym-owner/gyms/:gymId/branches/:branchId
 * Deactivate (soft-delete) a branch.
 */
router.delete('/gyms/:gymId/branches/:branchId', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, branchId } = req.params;
    await assertGymOwnership(gymId, req.user!.userId, req.user!.role);

    const branch = await prisma.branch.findUnique({ where: { id: branchId } });
    if (!branch || branch.gymId !== gymId) return notFound(res, 'Branch not found');

    await prisma.branch.update({ where: { id: branchId }, data: { isActive: false } });
    return success(res, { message: 'Branch deactivated' });
  } catch (err: any) {
    return res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * POST /gym-owner/gyms/:gymId/branches/:branchId/assign-admin
 * Assign a BRANCH_ADMIN user to this branch.
 * Body: { adminId: string }
 */
router.post('/gyms/:gymId/branches/:branchId/assign-admin', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, branchId } = req.params;
    const { adminId } = req.body;
    if (!adminId) return badRequest(res, 'adminId is required');

    await assertGymOwnership(gymId, req.user!.userId, req.user!.role);

    const [branch, admin] = await Promise.all([
      prisma.branch.findUnique({ where: { id: branchId } }),
      prisma.user.findUnique({ where: { id: adminId } }),
    ]);
    if (!branch || branch.gymId !== gymId) return notFound(res, 'Branch not found');
    if (!admin) return notFound(res, 'Admin user not found');

    // Connect user to branch + set managedGymId to the gym
    await prisma.$transaction([
      prisma.branch.update({
        where: { id: branchId },
        data: { admins: { connect: { id: adminId } } },
      }),
      prisma.user.update({
        where: { id: adminId },
        data: { managedGymId: gymId, role: 'BRANCH_ADMIN' },
      }),
    ]);

    return success(res, { message: 'Admin assigned to branch' });
  } catch (err: any) {
    return res.status(err.status ?? 500).json({ error: err.message });
  }
});

/**
 * GET /gym-owner/gyms/:gymId/branches/:branchId/stats
 * Detailed stats for a single branch.
 */
router.get('/gyms/:gymId/branches/:branchId/stats', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { gymId, branchId } = req.params;
    await assertGymOwnership(gymId, req.user!.userId, req.user!.role);

    const branch = await prisma.branch.findUnique({
      where: { id: branchId },
      include: { admins: { select: { id: true, fullName: true, email: true, avatarUrl: true } } },
    });
    if (!branch || branch.gymId !== gymId) return notFound(res, 'Branch not found');

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const [activeMembers, trainerCount, todayCheckins, monthCheckins, expiringSoon] = await Promise.all([
      prisma.gymMembership.count({ where: { gymId, status: 'ACTIVE' } }),
      prisma.trainerProfile.count({ where: { gymId } }),
      prisma.attendance.count({ where: { gymId, checkIn: { gte: todayStart } } }),
      prisma.attendance.count({ where: { gymId, checkIn: { gte: monthStart } } }),
      prisma.gymMembership.count({
        where: {
          gymId,
          status: 'ACTIVE',
          endDate: { lte: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000) },
        },
      }),
    ]);

    return success(res, {
      branch,
      stats: { activeMembers, trainerCount, todayCheckins, monthCheckins, expiringSoon },
    });
  } catch (err: any) {
    return res.status(err.status ?? 500).json({ error: err.message });
  }
});

export default router;

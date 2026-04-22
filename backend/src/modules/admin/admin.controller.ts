import { Router, Response } from 'express';
import {
  AdminService,
  AdminValidationError,
  AdminConflictError,
  AdminNotFoundError,
  AdminAccessDeniedError,
} from './admin.service';
import {
  authenticate,
  superAdminOnly,
  gymOwnerOrAbove,
  branchAdminOrAbove,
  AuthenticatedRequest
} from '../../middleware/auth.middleware';
import {
  created,
  success,
  validationError,
  conflict,
  notFound,
  forbidden,
  internalError,
} from '../../utils/response';
import logger from '../../lib/logger';

const router = Router();

// All admin routes require authentication
router.use(authenticate);

/**
 * POST /admin/gym-owners - Create a Gym Owner (Super Admin only)
 */
router.post('/gym-owners', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymOwner = await AdminService.createGymOwner(req.user!.userId, req.body);
    created(res, gymOwner);
  } catch (err) {
    if (err instanceof AdminValidationError) {
      return validationError(res, err.details);
    }
    if (err instanceof AdminConflictError) {
      return conflict(res, err.message);
    }
    logger.error('Create gym owner error', { err });
    internalError(res);
  }
});

/**
 * GET /admin/gym-owners - Get all Gym Owners (Super Admin only)
 */
router.get('/gym-owners', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymOwners = await AdminService.getAllGymOwners();
    success(res, gymOwners);
  } catch (err) {
    logger.error('Get gym owners error', { err });
    internalError(res);
  }
});

/**
 * POST /admin/branch-admins - Create a Branch Administrator (Gym Owner or above)
 */
router.post('/branch-admins', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const branchAdmin = await AdminService.createBranchAdmin(
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    created(res, branchAdmin);
  } catch (err) {
    if (err instanceof AdminValidationError) {
      return validationError(res, err.details);
    }
    if (err instanceof AdminConflictError) {
      return conflict(res, err.message);
    }
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Create branch admin error', { err });
    internalError(res);
  }
});

/**
 * POST /admin/trainers - Create a Trainer (Branch Admin or above)
 */
router.post('/trainers', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const trainer = await AdminService.createTrainer(
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    created(res, trainer);
  } catch (err) {
    if (err instanceof AdminValidationError) {
      return validationError(res, err.details);
    }
    if (err instanceof AdminConflictError) {
      return conflict(res, err.message);
    }
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Create trainer error', { err });
    internalError(res);
  }
});

/**
 * GET /admin/gyms/:gymId/trainers - Get trainers for a gym (Branch Admin or above)
 */
router.get('/gyms/:gymId/trainers', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const trainers = await AdminService.getGymTrainers(
      req.params.gymId,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    success(res, trainers);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Get gym trainers error', { err });
    internalError(res);
  }
});

/**
 * PATCH /admin/trainers/:id - Update trainer profile
 */
router.patch('/trainers/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const trainer = await AdminService.updateTrainer(
      req.params.id,
      req.user!.userId,
      req.user!.role,
      req.body,
      req.user!.managedGymId
    );
    success(res, trainer);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Update trainer error', { err });
    internalError(res);
  }
});

/**
 * PATCH /admin/gym-owners/:id - Update a Gym Owner (Super Admin only)
 */
router.patch('/gym-owners/:id', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const gymOwner = await AdminService.updateGymOwner(req.params.id, req.body);
    success(res, gymOwner);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error('Update gym owner error', { err });
    internalError(res);
  }
});

/**
 * POST /admin/gym-owners/:id/extend-saas-trial - Extend SaaS trial (Super Admin only)
 */
router.post('/gym-owners/:id/extend-saas-trial', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { days } = req.body;
    if (!days || typeof days !== 'number') {
      return validationError(res, [{ field: 'days', message: 'Valid number of days is required' }]);
    }
    const result = await AdminService.extendSaaSTrial(req.params.id, days);
    success(res, result, 'SaaS trial extended');
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    logger.error('Extend SaaS trial error', { err });
    internalError(res);
  }
});

/**
 * DELETE /admin/trainers/:id - Delete a trainer
 */
router.delete('/trainers/:id', branchAdminOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AdminService.deleteTrainer(
      req.params.id,
      req.user!.userId,
      req.user!.role,
      req.user!.managedGymId
    );
    success(res, result);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Delete trainer error', { err });
    internalError(res);
  }
});

/**
 * DELETE /admin/branch-admins/:id - Delete a branch administrator (Gym Owner or above)
 */
router.delete('/branch-admins/:id', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AdminService.deleteBranchAdmin(
      req.params.id,
      req.user!.userId,
      req.user!.role
    );
    success(res, result);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Delete branch admin error', { err });
    internalError(res);
  }
});

/**
 * POST /admin/users/:id/deactivate - Deactivate a user
 */
router.post('/users/:id/deactivate', gymOwnerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AdminService.deactivateUser(
      req.params.id,
      req.user!.userId,
      req.user!.role
    );
    success(res, result);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Deactivate user error', { err });
    internalError(res);
  }
});

/**
 * POST /admin/users/:id/activate - Activate a user (Super Admin only)
 */
router.post('/users/:id/activate', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const result = await AdminService.activateUser(
      req.params.id,
      req.user!.userId,
      req.user!.role
    );
    success(res, result);
  } catch (err) {
    if (err instanceof AdminNotFoundError) {
      return notFound(res, err.resource);
    }
    if (err instanceof AdminAccessDeniedError) {
      return forbidden(res, err.message);
    }
    logger.error('Activate user error', { err });
    internalError(res);
  }
});

// ─── Exercise Library CRUD ────────────────────────────────────────────────────

router.get('/exercise-library/stats', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await AdminService.getExerciseLibraryStats();
    return success(res, stats);
  } catch (err) {
    logger.error('Exercise library stats error', { err });
    internalError(res);
  }
});

router.get('/exercise-library', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const q      = (req.query.q as string || '').trim();
    const muscle = (req.query.muscle as string || '').trim();
    const diff   = (req.query.diff as string || '').trim();
    const exercises = await AdminService.listExerciseLibrary({ q, muscle, diff });
    return success(res, { exercises });
  } catch (err) {
    logger.error('Exercise library list error', { err });
    internalError(res);
  }
});

router.post('/exercise-library/import', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { records } = req.body;
    if (!Array.isArray(records) || records.length === 0) {
      return validationError(res, [{ field: 'records', message: 'records must be a non-empty array' }]);
    }
    const result = await AdminService.importExerciseLibrary(records);
    return success(res, result);
  } catch (err) {
    logger.error('Exercise library import error', { err });
    internalError(res);
  }
});

router.post('/exercise-library', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const exercise = await AdminService.createExercise(req.body);
    return created(res, exercise);
  } catch (err: any) {
    if (err?.code === 'P2002') return conflict(res, 'An exercise with this name already exists');
    logger.error('Exercise library create error', { err });
    internalError(res);
  }
});

router.patch('/exercise-library/:id', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const exercise = await AdminService.updateExercise(req.params.id, req.body);
    return success(res, exercise);
  } catch (err: any) {
    if (err instanceof AdminNotFoundError) return notFound(res, err.resource);
    logger.error('Exercise library update error', { err });
    internalError(res);
  }
});

router.delete('/exercise-library/:id', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    await AdminService.deleteExercise(req.params.id);
    return success(res, { deleted: true });
  } catch (err) {
    if (err instanceof AdminNotFoundError) return notFound(res, err.resource);
    logger.error('Exercise library delete error', { err });
    internalError(res);
  }
});

// ─── Ingredient (Food Item) Library CRUD ─────────────────────────────────────

router.get('/ingredient-library/stats', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await AdminService.getIngredientLibraryStats();
    return success(res, stats);
  } catch (err) {
    logger.error('Ingredient library stats error', { err });
    internalError(res);
  }
});

router.get('/ingredient-library', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const q        = (req.query.q as string || '').trim();
    const category = (req.query.category as string || '').trim();
    const verified = req.query.verified as string | undefined;
    const ingredients = await AdminService.listIngredientLibrary({ q, category, verified });
    return success(res, { ingredients });
  } catch (err) {
    logger.error('Ingredient library list error', { err });
    internalError(res);
  }
});

router.post('/ingredient-library/import', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { records } = req.body;
    if (!Array.isArray(records) || records.length === 0) {
      return validationError(res, [{ field: 'records', message: 'records must be a non-empty array' }]);
    }
    const result = await AdminService.importIngredientLibrary(records);
    return success(res, result);
  } catch (err) {
    logger.error('Ingredient library import error', { err });
    internalError(res);
  }
});

router.post('/ingredient-library', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const ingredient = await AdminService.createIngredient(req.body);
    return created(res, ingredient);
  } catch (err: any) {
    if (err?.code === 'P2002') return conflict(res, 'An ingredient with this barcode already exists');
    logger.error('Ingredient library create error', { err });
    internalError(res);
  }
});

router.patch('/ingredient-library/:id/verify', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const ingredient = await AdminService.verifyIngredient(req.params.id);
    return success(res, ingredient);
  } catch (err) {
    if (err instanceof AdminNotFoundError) return notFound(res, err.resource);
    logger.error('Ingredient verify error', { err });
    internalError(res);
  }
});

router.patch('/ingredient-library/:id', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const ingredient = await AdminService.updateIngredient(req.params.id, req.body);
    return success(res, ingredient);
  } catch (err) {
    if (err instanceof AdminNotFoundError) return notFound(res, err.resource);
    logger.error('Ingredient library update error', { err });
    internalError(res);
  }
});

router.delete('/ingredient-library/:id', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    await AdminService.deleteIngredient(req.params.id);
    return success(res, { deleted: true });
  } catch (err) {
    if (err instanceof AdminNotFoundError) return notFound(res, err.resource);
    logger.error('Ingredient library delete error', { err });
    internalError(res);
  }
});

// ─── External Food Cache Management ─────────────────────────────────────────

router.get('/food-cache/stats', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await AdminService.getExternalFoodCacheStats();
    return success(res, stats);
  } catch (err) {
    logger.error('Food cache stats error', { err });
    internalError(res);
  }
});

router.get('/food-cache', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const source = (req.query.source as string) || undefined;
    const q      = (req.query.q as string || '').trim();
    const items  = await AdminService.listExternalFoodCache({ source, q });
    return success(res, { items });
  } catch (err) {
    logger.error('Food cache list error', { err });
    internalError(res);
  }
});

router.delete('/food-cache', superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const days = parseInt(req.query.olderThanDays as string);
    if (!days || days < 1) {
      return validationError(res, [{ field: 'olderThanDays', message: 'Must be a positive integer (days)' }]);
    }
    const result = await AdminService.pruneExternalFoodCache(days);
    return success(res, result);
  } catch (err) {
    logger.error('Food cache prune error', { err });
    internalError(res);
  }
});

export default router;


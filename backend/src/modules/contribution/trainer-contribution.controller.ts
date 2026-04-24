import { Router, Response } from 'express';
import { authenticate, trainerOrAbove, superAdminOnly, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { TrainerContributionService } from './trainer-contribution.service';
import { success, created, validationError, internalError, notFound } from '../../utils/response';
import logger from '../../lib/logger';

const router = Router();

// ─── Trainer: submit food item ────────────────────────────────────────────────

/**
 * POST /api/contributions/food
 * Trainer submits a new food item (defaults to PENDING).
 */
router.post('/food', authenticate, trainerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { name, calories, protein, carbs, fats } = req.body;
    if (!name || calories == null || protein == null || carbs == null || fats == null) {
      return validationError(res, [{ field: 'body', message: 'name, calories, protein, carbs, fats are required' }]);
    }
    const item = await TrainerContributionService.createFoodItem(req.user!.userId, req.body);
    return created(res, item);
  } catch (err) {
    logger.error('[Contribution] Create food item error', { err });
    return internalError(res);
  }
});

// ─── Trainer: submit exercise ─────────────────────────────────────────────────

/**
 * POST /api/contributions/exercise
 * Trainer submits a new exercise (defaults to PENDING).
 */
router.post('/exercise', authenticate, trainerOrAbove, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { name, primaryMuscle } = req.body;
    if (!name || !primaryMuscle) {
      return validationError(res, [{ field: 'body', message: 'name and primaryMuscle are required' }]);
    }
    const item = await TrainerContributionService.createExercise(req.user!.userId, req.body);
    return created(res, item);
  } catch (err) {
    logger.error('[Contribution] Create exercise error', { err });
    return internalError(res);
  }
});

// ─── Super Admin: list pending food items ─────────────────────────────────────

/**
 * GET /api/contributions/food/pending
 */
router.get('/food/pending', authenticate, superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const data = await TrainerContributionService.listPendingFoodItems(page, limit);
    return success(res, data);
  } catch (err) {
    logger.error('[Contribution] List pending food error', { err });
    return internalError(res);
  }
});

// ─── Super Admin: list pending exercises ──────────────────────────────────────

/**
 * GET /api/contributions/exercise/pending
 */
router.get('/exercise/pending', authenticate, superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const data = await TrainerContributionService.listPendingExercises(page, limit);
    return success(res, data);
  } catch (err) {
    logger.error('[Contribution] List pending exercises error', { err });
    return internalError(res);
  }
});

// ─── Super Admin: review food item (approve/reject + media) ──────────────────

/**
 * PATCH /api/contributions/food/:id/review
 * Body: { status, imageUrl?, iconUrl?, countryCodes?, allergyTags?, availabilityScore? }
 */
router.patch('/food/:id/review', authenticate, superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!status || !['UNDER_REVIEW', 'APPROVED', 'REJECTED'].includes(status)) {
      return validationError(res, [{ field: 'status', message: 'status must be UNDER_REVIEW, APPROVED, or REJECTED' }]);
    }
    const item = await TrainerContributionService.reviewFoodItem(id, req.user!.userId, req.body);
    return success(res, item);
  } catch (err: any) {
    if (err?.code === 'P2025') return notFound(res, 'Food item');
    logger.error('[Contribution] Review food item error', { err });
    return internalError(res);
  }
});

// ─── Super Admin: review exercise (approve/reject + videoUrl) ────────────────

/**
 * PATCH /api/contributions/exercise/:id/review
 * Body: { status, videoUrl?, location?, fitnessGoals? }
 */
router.patch('/exercise/:id/review', authenticate, superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!status || !['UNDER_REVIEW', 'APPROVED', 'REJECTED'].includes(status)) {
      return validationError(res, [{ field: 'status', message: 'status must be UNDER_REVIEW, APPROVED, or REJECTED' }]);
    }
    const item = await TrainerContributionService.reviewExercise(id, req.user!.userId, req.body);
    return success(res, item);
  } catch (err: any) {
    if (err?.code === 'P2025') return notFound(res, 'Exercise');
    logger.error('[Contribution] Review exercise error', { err });
    return internalError(res);
  }
});

// ─── Super Admin: add substitution mapping ───────────────────────────────────

/**
 * POST /api/contributions/substitutions
 * Body: { foodItemId, substituteId, culturalScore?, nutritionalScore?, countryCodes? }
 */
router.post('/substitutions', authenticate, superAdminOnly, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { foodItemId, substituteId } = req.body;
    if (!foodItemId || !substituteId) {
      return validationError(res, [{ field: 'body', message: 'foodItemId and substituteId are required' }]);
    }
    const map = await TrainerContributionService.addSubstitution(req.body);
    return success(res, map);
  } catch (err) {
    logger.error('[Contribution] Add substitution error', { err });
    return internalError(res);
  }
});

export default router;

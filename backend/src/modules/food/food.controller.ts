import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, badRequest, notFound, internalError } from '../../utils/response';
import { FoodService } from './food.service';
import logger from '../../lib/logger';
import { z } from 'zod';

const router = Router();

// ─── Validation Schemas ───────────────────────────────────────────────────────

const LogFoodSchema = z.object({
  foodItemId: z.string().uuid().optional(),
  externalFood: z.object({
    name: z.string().min(1).max(200),
    brand: z.string().max(100).optional(),
    barcode: z.string().max(50).optional(),
    calories: z.number().min(0).max(9999),
    protein: z.number().min(0).max(999),
    carbs: z.number().min(0).max(9999),
    fats: z.number().min(0).max(999),
    fiber: z.number().min(0).max(999).optional(),
    source: z.enum(['NUTRITIONIX', 'OPEN_FOOD_FACTS', 'USER']),
  }).optional(),
  mealType: z.enum(['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'PRE_WORKOUT', 'POST_WORKOUT']),
  grams: z.number().min(0.1).max(5000),
  loggedAt: z.string().datetime().optional(),
}).refine(d => d.foodItemId || d.externalFood, {
  message: 'Either foodItemId or externalFood is required',
});

// ─── Routes ───────────────────────────────────────────────────────────────────

/**
 * GET /api/food/search?q=chicken&limit=20
 * Search food database + Nutritionix fallback
 */
router.get('/search', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const query = req.query.q as string;
    const limit = Math.min(parseInt(req.query.limit as string) || 20, 50);

    if (!query || query.trim().length < 2) {
      return badRequest(res, 'Query must be at least 2 characters');
    }

    const results = await FoodService.search(query.trim(), limit);
    return success(res, results);
  } catch (err) {
    logger.error('[Food] search error', { err });
    internalError(res);
  }
});

/**
 * GET /api/food/barcode/:code
 * Barcode lookup — checks DB first, then Nutritionix, then Open Food Facts
 */
router.get('/barcode/:code', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { code } = req.params;
    if (!code || code.length < 8) {
      return badRequest(res, 'Invalid barcode');
    }

    const result = await FoodService.lookupBarcode(code);
    if (!result) {
      return notFound(res, 'Food item');
    }

    return success(res, result);
  } catch (err) {
    logger.error('[Food] barcode lookup error', { err });
    internalError(res);
  }
});

/**
 * POST /api/food/log
 * Log a food entry — creates FoodLog + atomically updates DailyProgress macros
 */
router.post('/log', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const parsed = LogFoodSchema.safeParse(req.body);

    if (!parsed.success) {
      return badRequest(res, 'Validation failed', parsed.error.issues.map((e) => ({
        field: e.path.map(String).join('.'),
        message: e.message,
      })));
    }

    const log = await FoodService.logFood(userId, parsed.data as any);
    return success(res, log, undefined, 201);
  } catch (err: any) {
    if (err.status) {
      return res.status(err.status).json({ success: false, error: { message: err.message } });
    }
    logger.error('[Food] log error', { err });
    internalError(res);
  }
});

/**
 * GET /api/food/diary?date=2026-03-18
 * Get full food diary for a date with macro totals grouped by meal type
 */
router.get('/diary', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const date = (req.query.date as string) || new Date().toISOString().split('T')[0];

    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return badRequest(res, 'Date must be in YYYY-MM-DD format');
    }

    const diary = await FoodService.getDiary(userId, date);
    return success(res, diary);
  } catch (err) {
    logger.error('[Food] diary error', { err });
    internalError(res);
  }
});

/**
 * DELETE /api/food/log/:id
 * Remove a food log entry — reverses DailyProgress macro update atomically
 */
router.delete('/log/:id', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const userId = req.user!.userId;
    const { id } = req.params;

    const result = await FoodService.deleteLog(userId, id);
    return success(res, result);
  } catch (err: any) {
    if (err.status) {
      return res.status(err.status).json({ success: false, error: { message: err.message } });
    }
    logger.error('[Food] delete log error', { err });
    internalError(res);
  }
});

export default router;


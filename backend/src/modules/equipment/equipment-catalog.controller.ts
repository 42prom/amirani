import { Router, Response } from 'express';
import { EquipmentCatalogService, CatalogError } from './equipment-catalog.service';
import { authenticate, superAdminOnly, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, created, badRequest, serverError } from '../../utils/response';
import logger from '../../utils/logger';
import { EquipmentCategory } from '@prisma/client';

const router = Router();

// All routes require Super Admin
router.use(authenticate, superAdminOnly);

/**
 * GET /equipment-catalog
 * Get all catalog items
 */
router.get('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { category, brand, search, activeOnly } = req.query;

    const items = await EquipmentCatalogService.getAll({
      category: category as EquipmentCategory | undefined,
      brand: brand as string | undefined,
      search: search as string | undefined,
      activeOnly: activeOnly === 'false' ? false : true,
    });

    return success(res, items);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /equipment-catalog/stats
 * Get catalog usage statistics
 */
router.get('/stats', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const stats = await EquipmentCatalogService.getUsageStats();
    return success(res, stats);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /equipment-catalog/categories
 * Get all categories with counts
 */
router.get('/categories', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const categories = await EquipmentCatalogService.getCategoryCounts();
    return success(res, categories);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /equipment-catalog/brands
 * Get all unique brands
 */
router.get('/brands', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const brands = await EquipmentCatalogService.getBrands();
    return success(res, brands);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /equipment-catalog/:id
 * Get a single catalog item
 */
router.get('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const item = await EquipmentCatalogService.getById(req.params.id);
    return success(res, item);
  } catch (error: any) {
    if (error instanceof CatalogError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * POST /equipment-catalog
 * Create a new catalog item
 */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const item = await EquipmentCatalogService.create(req.body);
    return created(res, item);
  } catch (error: any) {
    if (error instanceof CatalogError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * PATCH /equipment-catalog/:id
 * Update a catalog item
 */
router.patch('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const item = await EquipmentCatalogService.update(req.params.id, req.body);
    return success(res, item);
  } catch (error: any) {
    if (error instanceof CatalogError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

/**
 * DELETE /equipment-catalog/:id
 * Delete a catalog item
 */
router.delete('/:id', async (req: AuthenticatedRequest, res: Response) => {
  try {
    await EquipmentCatalogService.delete(req.params.id);
    res.status(204).send();
  } catch (error: any) {
    if (error instanceof CatalogError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

export default router;

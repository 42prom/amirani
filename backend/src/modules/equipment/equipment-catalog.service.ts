import prisma from '../../lib/prisma';
import { EquipmentCategory } from '@prisma/client';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class CatalogError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CatalogError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class EquipmentCatalogService {
  /**
   * Get all catalog items (with optional filters)
   */
  static async getAll(options?: {
    category?: EquipmentCategory;
    brand?: string;
    search?: string;
    activeOnly?: boolean;
  }) {
    const where: any = {};

    if (options?.category) {
      where.category = options.category;
    }

    if (options?.brand) {
      where.brand = options.brand;
    }

    if (options?.activeOnly !== false) {
      where.isActive = true;
    }

    if (options?.search && options.search.trim()) {
      const searchTerm = options.search.trim();
      const searchLower = searchTerm.toLowerCase();
      
      const orConditions: any[] = [
        { name: { contains: searchTerm, mode: 'insensitive' } },
        { brand: { contains: searchTerm, mode: 'insensitive' } },
        { model: { contains: searchTerm, mode: 'insensitive' } },
        { description: { contains: searchTerm, mode: 'insensitive' } },
      ];

      // Try to match against categories
      const categories = ['CARDIO', 'STRENGTH', 'FREE_WEIGHTS', 'MACHINES', 'FUNCTIONAL', 'STRETCHING', 'OTHER'];
      const matchedCategory = categories.find(c => 
        c.toLowerCase().includes(searchLower) || 
        searchLower.includes(c.toLowerCase()) ||
        c.replace('_', ' ').toLowerCase().includes(searchLower)
      );

      if (matchedCategory) {
        orConditions.push({ category: matchedCategory as any });
      }

      where.OR = orConditions;
    }

    return prisma.equipmentCatalog.findMany({
      where,
      include: {
        _count: {
          select: { gymEquipment: true },
        },
      },
      orderBy: [{ category: 'asc' }, { name: 'asc' }],
    });
  }

  /**
   * Get a single catalog item by ID
   */
  static async getById(id: string) {
    const item = await prisma.equipmentCatalog.findUnique({
      where: { id },
      include: {
        _count: {
          select: { gymEquipment: true },
        },
      },
    });

    if (!item) {
      throw new CatalogError('Catalog item not found');
    }

    return item;
  }

  /**
   * Create a new catalog item
   */
  static async create(data: {
    name: string;
    category?: EquipmentCategory;
    brand?: string;
    model?: string;
    description?: string;
    imageUrl?: string;
  }) {
    if (!data.name || data.name.trim().length < 2) {
      throw new CatalogError('Name must be at least 2 characters');
    }

    return prisma.equipmentCatalog.create({
      data: {
        name: data.name.trim(),
        category: data.category || 'OTHER',
        brand: data.brand?.trim(),
        model: data.model?.trim(),
        description: data.description?.trim(),
        imageUrl: data.imageUrl,
      },
    });
  }

  /**
   * Update a catalog item
   */
  static async update(
    id: string,
    data: {
      name?: string;
      category?: EquipmentCategory;
      brand?: string;
      model?: string;
      description?: string;
      imageUrl?: string;
      isActive?: boolean;
    }
  ) {
    const item = await prisma.equipmentCatalog.findUnique({
      where: { id },
    });

    if (!item) {
      throw new CatalogError('Catalog item not found');
    }

    const updateData: any = {};

    if (data.name !== undefined) updateData.name = data.name.trim();
    if (data.category !== undefined) updateData.category = data.category;
    if (data.brand !== undefined) updateData.brand = data.brand?.trim() || null;
    if (data.model !== undefined) updateData.model = data.model?.trim() || null;
    if (data.description !== undefined) updateData.description = data.description?.trim() || null;
    if (data.imageUrl !== undefined) updateData.imageUrl = data.imageUrl || null;
    if (data.isActive !== undefined) updateData.isActive = data.isActive;

    return prisma.equipmentCatalog.update({
      where: { id },
      data: updateData,
    });
  }

  /**
   * Delete a catalog item
   */
  static async delete(id: string) {
    const item = await prisma.equipmentCatalog.findUnique({
      where: { id },
      include: {
        _count: {
          select: { gymEquipment: true },
        },
      },
    });

    if (!item) {
      throw new CatalogError('Catalog item not found');
    }

    if (item._count.gymEquipment > 0) {
      throw new CatalogError(
        `Cannot delete: ${item._count.gymEquipment} gym(s) are using this item. Deactivate it instead.`
      );
    }

    return prisma.equipmentCatalog.delete({
      where: { id },
    });
  }

  /**
   * Get all categories with counts
   */
  static async getCategoryCounts() {
    return prisma.equipmentCatalog.groupBy({
      by: ['category'],
      where: { isActive: true },
      _count: { id: true },
    });
  }

  /**
   * Get all brands
   */
  static async getBrands() {
    const brands = await prisma.equipmentCatalog.findMany({
      where: { isActive: true, brand: { not: null } },
      select: { brand: true },
      distinct: ['brand'],
      orderBy: { brand: 'asc' },
    });

    return brands.map((b) => b.brand).filter(Boolean);
  }

  /**
   * Get usage stats for catalog items
   */
  static async getUsageStats() {
    const [totalItems, activeItems, totalGymsUsing, byCategory] = await Promise.all([
      prisma.equipmentCatalog.count(),
      prisma.equipmentCatalog.count({ where: { isActive: true } }),
      prisma.equipment.count({ where: { catalogItemId: { not: null } } }),
      prisma.equipmentCatalog.groupBy({
        by: ['category'],
        _count: { id: true },
      }),
    ]);

    return {
      totalItems,
      activeItems,
      totalGymsUsing,
      byCategory,
    };
  }
}

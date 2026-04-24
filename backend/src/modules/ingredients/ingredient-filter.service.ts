import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

/**
 * Country priority: activeGym.country → user.country → global popular fallback.
 * Only APPROVED items pass through. Graceful fallback when the filtered set is empty.
 */

export interface IngredientFilterOptions {
  /** Resolved country code — caller must apply the priority chain before calling. */
  countryCode?: string;
  allergyTags?: string[];          // tags to EXCLUDE (user allergies)
  season?: string;                 // e.g. "winter" — filters by seasonality
  foodCategory?: string;           // optional FoodCategory value
  limit?: number;
  minAvailabilityScore?: number;   // 0-100, default 30
}

export interface FilteredIngredient {
  id: string;
  name: string;
  nameKa?: string | null;
  nameRu?: string | null;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  fiber?: number | null;
  foodCategory?: string | null;
  availabilityScore: number;
  allergyTags: string[];
  countryCodes: string[];
  seasonality: string[];
  substitutionGroup?: string | null;
  imageUrl?: string | null;
  iconUrl?: string | null;
}

export class IngredientFilterService {

  /**
   * Return APPROVED ingredients filtered by country, allergies, season, and availability.
   * Applies three-tier fallback: country-specific → global popular → any approved.
   */
  static async filter(opts: IngredientFilterOptions): Promise<FilteredIngredient[]> {
    const {
      countryCode,
      allergyTags = [],
      season,
      foodCategory,
      limit = 200,
      minAvailabilityScore = 30,
    } = opts;

    // Build allergy exclusion filter
    const allergyFilter = allergyTags.length > 0
      ? { NOT: { allergyTags: { hasSome: allergyTags } } }
      : {};

    // Build season filter
    const seasonFilter = season
      ? {
          OR: [
            { seasonality: { has: season } },
            { seasonality: { isEmpty: true } }, // items with no season = year-round
          ],
        }
      : {};

    const categoryFilter = foodCategory ? { foodCategory: foodCategory as any } : {};

    const baseWhere = {
      status: 'APPROVED' as const,
      isActive: true,
      availabilityScore: { gte: minAvailabilityScore },
      ...allergyFilter,
      ...seasonFilter,
      ...categoryFilter,
    };

    // ── Tier 1: country-specific results ──────────────────────────────────────
    if (countryCode) {
      const countryResults = await prisma.foodItem.findMany({
        where: {
          ...baseWhere,
          countryCodes: { has: countryCode },
        } as any,
        orderBy: { availabilityScore: 'desc' },
        take: limit,
        select: this.selectShape(),
      });

      if (countryResults.length >= 10) {
        logger.debug(`[IngredientFilter] ${countryResults.length} items for country ${countryCode}`);
        return countryResults as FilteredIngredient[];
      }

      // Tier 1 too thin — merge with Tier 2 (global popular)
      logger.debug(`[IngredientFilter] Only ${countryResults.length} country items, falling back to global`);
    }

    // ── Tier 2: global popular (empty countryCodes = universal) ───────────────
    const globalResults = await prisma.foodItem.findMany({
      where: {
        ...baseWhere,
        countryCodes: { isEmpty: true },
      } as any,
      orderBy: { availabilityScore: 'desc' },
      take: limit,
      select: this.selectShape(),
    });

    if (globalResults.length >= 5) {
      return globalResults as FilteredIngredient[];
    }

    // ── Tier 3: any APPROVED item — broadest fallback ─────────────────────────
    logger.warn('[IngredientFilter] Falling back to any approved item — check seed data');
    const anyResults = await prisma.foodItem.findMany({
      where: { status: 'APPROVED', isActive: true },
      orderBy: { availabilityScore: 'desc' },
      take: limit,
      select: this.selectShape(),
    });

    if (anyResults.length === 0) {
      logger.error('[IngredientFilter] No approved ingredients found — seed data missing');
    }

    return anyResults as FilteredIngredient[];
  }

  /**
   * Resolve country code using the mandated priority chain:
   * 1. user.activeGym.country
   * 2. user.country
   * 3. undefined (triggers global popular fallback)
   */
  static async resolveCountryCode(userId: string): Promise<string | undefined> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        country: true,
        activeGym: { select: { country: true } },
      },
    });

    if (!user) return undefined;
    return user.activeGym?.country ?? user.country ?? undefined;
  }

  private static selectShape() {
    return {
      id: true,
      name: true,
      nameKa: true,
      nameRu: true,
      calories: true,
      protein: true,
      carbs: true,
      fats: true,
      fiber: true,
      foodCategory: true,
      availabilityScore: true,
      allergyTags: true,
      countryCodes: true,
      seasonality: true,
      substitutionGroup: true,
      imageUrl: true,
      iconUrl: true,
    } as const;
  }
}

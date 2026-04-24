import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

/**
 * SubstitutionEngine — predefined alternatives with nutritional + cultural relevance.
 *
 * Lookup strategy:
 *   1. Explicit SubstitutionMap rows (highest precision)
 *   2. Same substitutionGroup items (soft match)
 *   3. Same foodCategory items with APPROVED status (broadest fallback)
 */

export interface SubstituteOption {
  id: string;
  name: string;
  nameKa?: string | null;
  nameRu?: string | null;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  culturalScore: number;
  nutritionalScore: number;
  imageUrl?: string | null;
  iconUrl?: string | null;
  source: 'EXPLICIT_MAP' | 'SAME_GROUP' | 'SAME_CATEGORY';
}

export class SubstitutionEngine {

  /**
   * Find substitutes for a given food item, prioritised by cultural + nutritional relevance.
   * Always returns APPROVED items only.
   *
   * @param foodItemId  - The original ingredient to substitute
   * @param countryCode - Optional; filters to culturally relevant options for the country
   * @param limit       - Max results to return (default 5)
   */
  static async getSubstitutes(
    foodItemId: string,
    countryCode?: string,
    limit = 5,
  ): Promise<SubstituteOption[]> {

    // ── 1. Explicit SubstitutionMap rows ──────────────────────────────────────
    const mapRows = await prisma.substitutionMap.findMany({
      where: {
        foodItemId,
        isActive: true,
        // Country-relevant or universal (empty countryCodes)
        OR: [
          { countryCodes: { isEmpty: true } },
          ...(countryCode ? [{ countryCodes: { has: countryCode } }] : []),
        ],
        substitute: { status: 'APPROVED', isActive: true },
      },
      orderBy: [{ culturalScore: 'desc' }, { nutritionalScore: 'desc' }],
      take: limit,
      include: {
        substitute: {
          select: {
            id: true,
            name: true,
            nameKa: true,
            nameRu: true,
            calories: true,
            protein: true,
            carbs: true,
            fats: true,
            imageUrl: true,
            iconUrl: true,
          },
        },
      },
    });

    if (mapRows.length >= limit) {
      return mapRows.map(r => ({
        ...r.substitute,
        culturalScore: r.culturalScore,
        nutritionalScore: r.nutritionalScore,
        source: 'EXPLICIT_MAP' as const,
      }));
    }

    const alreadyFound = new Set(mapRows.map(r => r.substituteId));

    // ── 2. Same substitutionGroup (soft match) ────────────────────────────────
    const original = await prisma.foodItem.findUnique({
      where: { id: foodItemId },
      select: { substitutionGroup: true, foodCategory: true },
    });

    let groupResults: SubstituteOption[] = [];

    if (original?.substitutionGroup) {
      const groupItems = await prisma.foodItem.findMany({
        where: {
          substitutionGroup: original.substitutionGroup,
          status: 'APPROVED',
          isActive: true,
          id: { notIn: [foodItemId, ...alreadyFound] },
        },
        orderBy: { availabilityScore: 'desc' },
        take: limit - mapRows.length,
        select: {
          id: true, name: true, nameKa: true, nameRu: true,
          calories: true, protein: true, carbs: true, fats: true,
          imageUrl: true, iconUrl: true,
        },
      });

      groupResults = groupItems.map(item => ({
        ...item,
        culturalScore: 50,
        nutritionalScore: 70,
        source: 'SAME_GROUP' as const,
      }));

      groupItems.forEach(i => alreadyFound.add(i.id));
    }

    const combined = [
      ...mapRows.map(r => ({
        ...r.substitute,
        culturalScore: r.culturalScore,
        nutritionalScore: r.nutritionalScore,
        source: 'EXPLICIT_MAP' as const,
      })),
      ...groupResults,
    ];

    if (combined.length >= limit) {
      return combined.slice(0, limit);
    }

    // ── 3. Same category fallback ─────────────────────────────────────────────
    if (original?.foodCategory) {
      const categoryItems = await prisma.foodItem.findMany({
        where: {
          foodCategory: original.foodCategory,
          status: 'APPROVED',
          isActive: true,
          id: { notIn: [foodItemId, ...alreadyFound] },
        },
        orderBy: { availabilityScore: 'desc' },
        take: limit - combined.length,
        select: {
          id: true, name: true, nameKa: true, nameRu: true,
          calories: true, protein: true, carbs: true, fats: true,
          imageUrl: true, iconUrl: true,
        },
      });

      combined.push(
        ...categoryItems.map(item => ({
          ...item,
          culturalScore: 30,
          nutritionalScore: 50,
          source: 'SAME_CATEGORY' as const,
        }))
      );
    }

    if (combined.length === 0) {
      logger.warn(`[SubstitutionEngine] No substitutes found for ${foodItemId}`);
    }

    return combined.slice(0, limit);
  }
}

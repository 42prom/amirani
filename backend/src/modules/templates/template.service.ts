import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

/**
 * TemplateService — Hybrid System (Idea 6).
 *
 * Selects the best-matching HybridTemplate for a user profile, then returns
 * the linked MasterDietTemplate and MasterWorkoutTemplate IDs for the AI
 * personalisation layer to use. The AI only adjusts what the template doesn't
 * already handle — minimising generation cost.
 *
 * Scoring is additive:
 *   +3  country match
 *   +2  fitnessGoal match
 *   +2  fitnessLevel match
 *   +1  dietType match
 * Highest total wins. Ties broken by creation order (oldest first = more stable).
 */

export interface UserProfile {
  countryCode?: string;
  fitnessGoal?: string;
  fitnessLevel?: string;
  dietType?: string;
}

export interface TemplateMatch {
  hybridTemplateId: string;
  name: string;
  score: number;
  dietTemplateId?: string | null;
  workoutTemplateId?: string | null;
}

export class TemplateService {

  /**
   * Find the closest-matching HybridTemplate for a user profile.
   * Returns null if no APPROVED templates exist (AI generates from scratch).
   */
  static async findBestMatch(profile: UserProfile): Promise<TemplateMatch | null> {
    const templates = await prisma.hybridTemplate.findMany({
      where: { status: 'APPROVED' },
      orderBy: { createdAt: 'asc' },
    });

    if (templates.length === 0) {
      logger.warn('[TemplateService] No approved HybridTemplates found — AI will generate from scratch');
      return null;
    }

    let best: TemplateMatch | null = null;
    let bestScore = -1;

    for (const t of templates) {
      let score = 0;

      if (profile.countryCode && t.countryCodes.includes(profile.countryCode)) {
        score += 3;
      } else if (t.countryCodes.length === 0) {
        score += 1; // universal template: partial credit
      }

      if (profile.fitnessGoal && t.fitnessGoals.includes(profile.fitnessGoal)) {
        score += 2;
      } else if (t.fitnessGoals.length === 0) {
        score += 1;
      }

      if (profile.fitnessLevel && t.fitnessLevels.includes(profile.fitnessLevel)) {
        score += 2;
      } else if (t.fitnessLevels.length === 0) {
        score += 1;
      }

      if (profile.dietType && t.dietTypes.includes(profile.dietType)) {
        score += 1;
      }

      if (score > bestScore) {
        bestScore = score;
        best = {
          hybridTemplateId: t.id,
          name: t.name,
          score,
          dietTemplateId: t.dietTemplateId,
          workoutTemplateId: t.workoutTemplateId,
        };
      }
    }

    logger.debug(`[TemplateService] Best match: ${best?.name ?? 'none'} (score=${bestScore})`);
    return best;
  }

  /**
   * Resolve a user's profile fields for template matching.
   * Country uses the same priority chain as IngredientFilterService.
   */
  static async resolveUserProfile(userId: string): Promise<UserProfile> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        country: true,
        fitnessGoal: true,
        fitnessLevel: true,
        activeGym: { select: { country: true } },
      },
    });

    if (!user) return {};

    return {
      countryCode: user.activeGym?.country ?? user.country ?? undefined,
      fitnessGoal: user.fitnessGoal ?? undefined,
      fitnessLevel: user.fitnessLevel ?? undefined,
    };
  }

  /** List all APPROVED HybridTemplates (for admin/trainer UI). */
  static async listApproved() {
    return prisma.hybridTemplate.findMany({
      where: { status: 'APPROVED' },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Create a HybridTemplate (super admin). */
  static async create(data: {
    name: string;
    description?: string;
    countryCodes?: string[];
    dietTypes?: string[];
    fitnessGoals?: string[];
    fitnessLevels?: string[];
    dietTemplateId?: string;
    workoutTemplateId?: string;
    creatorId?: string;
  }) {
    return prisma.hybridTemplate.create({
      data: {
        id: require('crypto').randomUUID(),
        name: data.name,
        description: data.description,
        countryCodes: data.countryCodes ?? [],
        dietTypes: data.dietTypes ?? [],
        fitnessGoals: data.fitnessGoals ?? [],
        fitnessLevels: data.fitnessLevels ?? [],
        dietTemplateId: data.dietTemplateId,
        workoutTemplateId: data.workoutTemplateId,
        status: 'APPROVED',
        creatorId: data.creatorId,
        updatedAt: new Date(),
      },
    });
  }
}

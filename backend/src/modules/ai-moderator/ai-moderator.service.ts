import prisma from '../../lib/prisma';
import logger from '../../lib/logger';
import { PlanMemoryService, PlanProfile } from '../plan-memory/plan-memory.service';
import { IngredientFilterService } from '../ingredients/ingredient-filter.service';
import { ExerciseFilterService } from '../exercise/exercise-filter.service';
import { TemplateService } from '../templates/template.service';
import type { AiJobPayload } from '../../jobs/processors/ai-job.processor';

/**
 * AIModeratorService — Idea 4: AI as Moderator, Not Generator.
 *
 * Decision chain (evaluated in order):
 *   1. Hard match  → return cached plan immediately (zero AI cost)
 *   2. Soft match  → inject prior plan context into payload (AI adjusts, not creates)
 *   3. Template    → inject best-matching HybridTemplate context (reduce generation scope)
 *   4. Filters     → inject pre-filtered ingredient / exercise lists (constrain AI choices)
 *   5. AI generate → full generation only when no reuse path found
 */

export type ModerationDecision = 'CACHE_HIT' | 'SOFT_ADJUST' | 'TEMPLATE_GUIDED' | 'FULL_GENERATE';

export interface ModerationResult {
  decision: ModerationDecision;
  /** Populated for CACHE_HIT — return this plan to the user immediately. */
  cachedPlan?: any;
  /** Enriched job payload to enqueue (undefined for CACHE_HIT). */
  enrichedPayload?: AiJobPayload;
}

export class AIModeratorService {

  /**
   * Evaluate a plan generation request and return a moderation decision.
   *
   * @param userId  - Authenticated user
   * @param payload - Raw job payload from the controller
   * @param type    - 'WORKOUT' | 'DIET'
   */
  static async moderate(
    userId: string,
    payload: AiJobPayload,
    type: 'WORKOUT' | 'DIET',
  ): Promise<ModerationResult> {

    // ── Resolve user profile for memory + filters ──────────────────────────────
    const profile = await this.buildProfile(userId, payload, type);

    // ── 1. Hard match: return cached plan immediately ──────────────────────────
    const hardMatch = await PlanMemoryService.checkHardMatch(profile);
    if (hardMatch) {
      logger.info('[AIModerator] Decision: CACHE_HIT', { userId, type });
      return { decision: 'CACHE_HIT', cachedPlan: hardMatch.planData };
    }

    // ── 2. Soft match: inject prior plan context ───────────────────────────────
    let enriched: AiJobPayload = { ...payload };
    let decision: ModerationDecision = 'FULL_GENERATE';

    const softMatch = await PlanMemoryService.checkSoftMatch(profile);
    if (softMatch) {
      enriched.priorPlanContext = softMatch.contextSnapshot;
      decision = 'SOFT_ADJUST';
      logger.info('[AIModerator] Decision: SOFT_ADJUST', { userId, type, matchedPlanId: softMatch.matchedPlanId });
    }

    // ── 3. HybridTemplate: narrow AI scope to a known-good structure ───────────
    const templateProfile = await TemplateService.resolveUserProfile(userId);
    const template = await TemplateService.findBestMatch(templateProfile);
    if (template && template.score >= 3) {
      enriched.hybridTemplateId = template.hybridTemplateId;
      if (decision === 'FULL_GENERATE') decision = 'TEMPLATE_GUIDED';
      logger.info('[AIModerator] Template applied', {
        userId,
        templateName: template.name,
        score: template.score,
      });
    }

    // ── 4. Ingredient filter: inject country-relevant approved ingredients ─────
    if (type === 'DIET') {
      try {
        const countryCode = profile.countryCode;
        const allergyTags = payload.allergies ?? [];
        const season = this.currentSeason();

        const ingredients = await IngredientFilterService.filter({
          countryCode,
          allergyTags,
          season,
          limit: 80,
        });

        if (ingredients.length > 0) {
          enriched.filteredIngredients = ingredients.map(i => i.name);
          logger.debug('[AIModerator] Injected filtered ingredients', {
            userId,
            count: ingredients.length,
            country: countryCode,
          });
        }
      } catch (err) {
        // Non-fatal: AI can still generate without the filtered list
        logger.warn('[AIModerator] Ingredient filter failed — continuing without', { err });
      }
    }

    // ── 5. Exercise filter: inject approved exercises matching location/level ──
    if (type === 'WORKOUT') {
      try {
        const location = this.resolveLocation(payload);
        const exercises = await ExerciseFilterService.filter({
          location,
          equipment: payload.availableEquipment,
          fitnessLevel: payload.fitnessLevel,
          fitnessGoal: payload.goals,
          limit: 80,
        });

        if (exercises.length > 0) {
          enriched.filteredExercises = exercises.map(e => e.name);
          logger.debug('[AIModerator] Injected filtered exercises', {
            userId,
            count: exercises.length,
            location,
          });
        }
      } catch (err) {
        logger.warn('[AIModerator] Exercise filter failed — continuing without', { err });
      }
    }

    return { decision, enrichedPayload: enriched };
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  private static async buildProfile(
    userId: string,
    payload: AiJobPayload,
    type: 'WORKOUT' | 'DIET',
  ): Promise<PlanProfile> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        country: true,
        fitnessGoal: true,
        activeGym: { select: { country: true } },
      },
    });

    const countryCode = user?.activeGym?.country ?? user?.country ?? undefined;
    const fitnessGoal = user?.fitnessGoal ?? undefined;

    return {
      userId,
      type,
      fitnessLevel: payload.fitnessLevel,
      fitnessGoal,
      countryCode,
      dietaryStyle: payload.dietaryStyle,
      restrictions: payload.restrictions,
    };
  }

  /** Returns the current meteorological season for the server's hemisphere (Northern). */
  private static currentSeason(): string {
    const month = new Date().getMonth() + 1; // 1-12
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'autumn';
    return 'winter';
  }

  /** Infer workout location from available equipment or goals text. */
  private static resolveLocation(payload: AiJobPayload): 'HOME' | 'GYM' | undefined {
    const eq = payload.availableEquipment ?? [];
    const gymKeywords = ['barbell', 'cable', 'machine', 'rack', 'bench'];
    const hasGymEquipment = eq.some(e => gymKeywords.some(k => e.toLowerCase().includes(k)));
    if (hasGymEquipment) return 'GYM';

    const goalsLower = (payload.goals ?? '').toLowerCase();
    if (goalsLower.includes('home')) return 'HOME';
    if (goalsLower.includes('gym')) return 'GYM';

    return undefined; // no constraint
  }
}

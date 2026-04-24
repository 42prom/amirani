import { createHash } from 'crypto';
import { getRedisClient } from '../../lib/redis';
import logger from '../../lib/logger';

/**
 * PlanMemoryService — Idea 3: Reuse-Based Diet & Workout System.
 *
 * Two-tier Redis memory:
 *
 *   HARD MATCH  key: plan:hard:{userId}:{profileHash}  TTL: 30d
 *     → stores compact plan JSON; returned as-is when the same profile re-requests a plan.
 *
 *   SOFT MATCH  key: plan:meta:{userId}  (Redis Hash, field = planId)  TTL: 90d
 *     → stores plan metadata; used to find a similar plan when the exact hash isn't found.
 *
 * Profile hash inputs (all sorted/lowercased for determinism):
 *   type, fitnessLevel, fitnessGoal, countryCode, dietaryStyle, restrictions[]
 */

// ─── TTLs ─────────────────────────────────────────────────────────────────────
const HARD_MATCH_TTL_S = 30 * 24 * 3600;  // 30 days
const SOFT_META_TTL_S  = 90 * 24 * 3600;  // 90 days
const MAX_PLAN_SIZE_BYTES = 1024 * 1024;   // 1 MB guard

// ─── Types ────────────────────────────────────────────────────────────────────

export interface PlanProfile {
  userId: string;
  type: 'WORKOUT' | 'DIET';
  fitnessLevel?: string;
  fitnessGoal?: string;
  countryCode?: string;
  dietaryStyle?: string;
  restrictions?: string[];
}

export interface PlanMeta {
  planId: string;
  planType: 'WORKOUT' | 'DIET';
  countryCode?: string;
  fitnessGoal?: string;
  fitnessLevel?: string;
  createdAt: number; // Unix ms
  /** Compact snapshot used for soft-match context (trimmed to first day only). */
  contextSnapshot: string;
}

export interface HardMatchResult {
  hit: true;
  planData: any;
  profileHash: string;
}

export interface SoftMatchResult {
  hit: true;
  contextSnapshot: string;
  matchedPlanId: string;
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class PlanMemoryService {

  /** Compute a deterministic SHA-256 profile hash for cache keying. */
  static computeProfileHash(profile: PlanProfile): string {
    const sorted = [
      profile.type,
      (profile.fitnessLevel ?? '').toUpperCase(),
      (profile.fitnessGoal ?? '').toUpperCase(),
      (profile.countryCode ?? '').toUpperCase(),
      (profile.dietaryStyle ?? '').toLowerCase(),
      ...(profile.restrictions ?? []).map(r => r.toLowerCase()).sort(),
    ].join('|');
    return createHash('sha256').update(sorted).digest('hex').slice(0, 24);
  }

  // ─── Hard match ─────────────────────────────────────────────────────────────

  /**
   * Check Redis for an exact-profile cached plan.
   * Returns null on cache miss OR when Redis is unavailable (fail-open).
   */
  static async checkHardMatch(profile: PlanProfile): Promise<HardMatchResult | null> {
    const hash = this.computeProfileHash(profile);
    try {
      const redis = getRedisClient();
      const raw = await redis.get(`plan:hard:${profile.userId}:${hash}`);
      if (!raw) return null;

      const planData = JSON.parse(raw);
      logger.info('[PlanMemory] Hard match hit', { userId: profile.userId, hash });
      return { hit: true, planData, profileHash: hash };
    } catch (err) {
      logger.warn('[PlanMemory] Hard match check failed (Redis issue) — fail-open', { err });
      return null;
    }
  }

  /**
   * Store a generated plan for future hard-match reuse.
   * Silently skips if the serialized plan exceeds MAX_PLAN_SIZE_BYTES.
   */
  static async storePlan(profile: PlanProfile, planData: any): Promise<void> {
    const hash = this.computeProfileHash(profile);
    try {
      const raw = JSON.stringify(planData);
      if (Buffer.byteLength(raw, 'utf8') > MAX_PLAN_SIZE_BYTES) {
        logger.warn('[PlanMemory] Plan too large to cache', { userId: profile.userId, type: profile.type });
        return;
      }
      const redis = getRedisClient();
      await redis.set(`plan:hard:${profile.userId}:${hash}`, raw, 'EX', HARD_MATCH_TTL_S);
      logger.debug('[PlanMemory] Hard plan stored', { userId: profile.userId, hash });
    } catch (err) {
      logger.warn('[PlanMemory] storePlan failed — continuing without cache', { err });
    }
  }

  // ─── Soft match ─────────────────────────────────────────────────────────────

  /**
   * Find a semantically similar past plan (same country + goal + level, any style).
   * Returns the contextSnapshot to inject into the AI prompt so the AI adjusts
   * instead of generating from scratch.
   */
  static async checkSoftMatch(profile: PlanProfile): Promise<SoftMatchResult | null> {
    try {
      const redis = getRedisClient();
      const metaKey = `plan:meta:${profile.userId}`;
      const raw = await redis.hgetall(metaKey);
      if (!raw || Object.keys(raw).length === 0) return null;

      const metas: PlanMeta[] = Object.values(raw)
        .map(v => { try { return JSON.parse(v) as PlanMeta; } catch { return null; } })
        .filter((m): m is PlanMeta => m !== null && m.planType === profile.type)
        .sort((a, b) => b.createdAt - a.createdAt); // newest first

      // Prioritise: same country + goal + level → then just same goal + level
      const hardMatch = metas.find(m =>
        m.countryCode === profile.countryCode &&
        m.fitnessGoal === profile.fitnessGoal &&
        m.fitnessLevel === profile.fitnessLevel
      );

      const softMatch = hardMatch ?? metas.find(m =>
        m.fitnessGoal === profile.fitnessGoal &&
        m.fitnessLevel === profile.fitnessLevel
      );

      if (!softMatch) return null;

      logger.info('[PlanMemory] Soft match found', {
        userId: profile.userId,
        matchedPlanId: softMatch.planId,
      });
      return {
        hit: true,
        contextSnapshot: softMatch.contextSnapshot,
        matchedPlanId: softMatch.planId,
      };
    } catch (err) {
      logger.warn('[PlanMemory] Soft match check failed — fail-open', { err });
      return null;
    }
  }

  /**
   * Archive a plan's metadata for soft-match lookup.
   * contextSnapshot contains a trimmed first-day summary — keeps Redis values small.
   *
   * @param planId   - DB plan ID (WorkoutPlan.id or DietPlan.id)
   * @param planData - Full AI-generated plan data
   */
  static async archivePlanMeta(profile: PlanProfile, planId: string, planData: any): Promise<void> {
    try {
      const redis = getRedisClient();
      const metaKey = `plan:meta:${profile.userId}`;

      // Compact snapshot: take first day only to limit size
      const firstDay = Array.isArray(planData?.days) ? planData.days.slice(0, 1) : [];
      const contextSnapshot = JSON.stringify({ planMeta: planData?.planMeta ?? {}, firstDay });

      const meta: PlanMeta = {
        planId,
        planType: profile.type,
        countryCode: profile.countryCode,
        fitnessGoal: profile.fitnessGoal,
        fitnessLevel: profile.fitnessLevel,
        createdAt: Date.now(),
        contextSnapshot,
      };

      await redis.hset(metaKey, planId, JSON.stringify(meta));
      await redis.expire(metaKey, SOFT_META_TTL_S);

      // Evict oldest entries if more than 10 plans stored per user
      const allKeys = await redis.hkeys(metaKey);
      if (allKeys.length > 10) {
        const all = await redis.hgetall(metaKey);
        const sorted = Object.entries(all ?? {})
          .map(([k, v]) => {
            try { return { key: k, createdAt: (JSON.parse(v) as PlanMeta).createdAt }; }
            catch { return { key: k, createdAt: 0 }; }
          })
          .sort((a, b) => a.createdAt - b.createdAt);
        const toDelete = sorted.slice(0, sorted.length - 10).map(e => e.key);
        if (toDelete.length > 0) await redis.hdel(metaKey, ...toDelete);
      }

      logger.debug('[PlanMemory] Plan meta archived', { userId: profile.userId, planId });
    } catch (err) {
      logger.warn('[PlanMemory] archivePlanMeta failed — continuing', { err });
    }
  }

  /** Invalidate a user's hard match cache (e.g., after profile change). */
  static async invalidateUser(userId: string): Promise<void> {
    try {
      const redis = getRedisClient();
      const keys = await redis.keys(`plan:hard:${userId}:*`);
      if (keys.length > 0) await redis.del(...keys);
      logger.debug('[PlanMemory] Hard cache invalidated', { userId, count: keys.length });
    } catch {
      // non-fatal
    }
  }
}

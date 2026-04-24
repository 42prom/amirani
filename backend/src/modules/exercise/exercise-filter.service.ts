import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

/** Strict filter by location, equipment, user level, and goals. Only APPROVED items. */

export type ExerciseLocation = 'HOME' | 'GYM' | 'OUTDOOR';

export interface ExerciseFilterOptions {
  location?: ExerciseLocation;      // primary location constraint
  equipment?: string[];             // equipment the user owns/has access to
  fitnessLevel?: string;            // BEGINNER | INTERMEDIATE | ADVANCED | ELITE
  fitnessGoal?: string;             // maps to FitnessGoal enum values
  primaryMuscle?: string;           // optional muscle group focus
  excludeIds?: string[];            // exercise IDs already in the plan (avoid repeats)
  limit?: number;
}

export interface FilteredExercise {
  id: string;
  name: string;
  nameKa?: string | null;
  nameRu?: string | null;
  primaryMuscle: string;
  secondaryMuscles: string[];
  equipment: string[];
  difficulty: string;
  mechanics: string;
  force: string;
  videoUrl?: string | null;
  cues: string[];
  metValue: number;
  location: string[];
  fitnessGoals: string[];
}

/** Maps ELITE → ADVANCED for difficulty matching (library only has 3 levels). */
const normaliseFitnessLevel = (level: string | undefined): string[] => {
  if (!level) return ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'];
  const map: Record<string, string[]> = {
    BEGINNER:     ['BEGINNER'],
    INTERMEDIATE: ['BEGINNER', 'INTERMEDIATE'],
    ADVANCED:     ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
    ELITE:        ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
  };
  return map[level] ?? ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'];
};

export class ExerciseFilterService {

  /**
   * Return APPROVED exercises filtered by location, equipment, level, and goal.
   * Falls back progressively when results are too thin:
   *   1. Full filter
   *   2. Drop fitnessGoal constraint
   *   3. Drop location + equipment constraints
   */
  static async filter(opts: ExerciseFilterOptions): Promise<FilteredExercise[]> {
    const {
      location,
      equipment = [],
      fitnessLevel,
      fitnessGoal,
      primaryMuscle,
      excludeIds = [],
      limit = 100,
    } = opts;

    const difficultyLevels = normaliseFitnessLevel(fitnessLevel) as any[];

    const baseWhere: any = {
      status: 'APPROVED',
      isActive: true,
      difficulty: { in: difficultyLevels },
    };

    if (excludeIds.length > 0) {
      baseWhere.id = { notIn: excludeIds };
    }

    if (primaryMuscle) {
      baseWhere.primaryMuscle = { contains: primaryMuscle, mode: 'insensitive' };
    }

    // ── Tier 1: Full filter (location + equipment + goal) ─────────────────────
    const tier1Where: any = { ...baseWhere };

    if (location) {
      tier1Where.location = { has: location };
    }

    if (equipment.length > 0) {
      // Exercise requires equipment that user has, OR no equipment ("bodyweight")
      tier1Where.OR = [
        { equipment: { hasSome: equipment } },
        { equipment: { isEmpty: true } },
        { equipment: { has: 'BODYWEIGHT' } },
      ];
    }

    if (fitnessGoal) {
      // Empty fitnessGoals array = exercise suits any goal → include via OR
      tier1Where.OR = [
        ...(tier1Where.OR ?? []),
        { fitnessGoals: { isEmpty: true } },
        { fitnessGoals: { has: fitnessGoal } },
      ];
    }

    const tier1 = await prisma.exerciseLibrary.findMany({
      where: tier1Where,
      orderBy: { metValue: 'desc' },
      take: limit,
      select: this.selectShape(),
    });

    if (tier1.length >= 5) {
      logger.debug(`[ExerciseFilter] Tier1: ${tier1.length} exercises`);
      return tier1 as FilteredExercise[];
    }

    // ── Tier 2: Drop fitnessGoal, keep location ───────────────────────────────
    const tier2Where: any = {
      ...baseWhere,
      ...(location ? { location: { has: location } } : {}),
    };
    const tier2 = await prisma.exerciseLibrary.findMany({
      where: tier2Where,
      orderBy: { metValue: 'desc' },
      take: limit,
      select: this.selectShape(),
    });

    if (tier2.length >= 3) {
      logger.debug(`[ExerciseFilter] Tier2: ${tier2.length} exercises`);
      return tier2 as FilteredExercise[];
    }

    // ── Tier 3: Any approved exercise for the difficulty level ────────────────
    logger.warn('[ExerciseFilter] Falling back to any approved exercise — check seed data');
    const tier3 = await prisma.exerciseLibrary.findMany({
      where: { status: 'APPROVED', isActive: true, difficulty: { in: difficultyLevels } },
      orderBy: { metValue: 'desc' },
      take: limit,
      select: this.selectShape(),
    });

    if (tier3.length === 0) {
      logger.error('[ExerciseFilter] No approved exercises found — seed data missing');
    }

    return tier3 as FilteredExercise[];
  }

  private static selectShape() {
    return {
      id: true,
      name: true,
      nameKa: true,
      nameRu: true,
      primaryMuscle: true,
      secondaryMuscles: true,
      equipment: true,
      difficulty: true,
      mechanics: true,
      force: true,
      videoUrl: true,
      cues: true,
      metValue: true,
      location: true,
      fitnessGoals: true,
    } as const;
  }
}

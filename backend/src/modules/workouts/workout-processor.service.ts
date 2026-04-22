import { PrismaClient } from '@prisma/client';

export class WorkoutProcessorService {
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
  }

  /**
   * Calculates the estimated calories burned for a single exercise set.
   * Formula: (MET * 3.5 * userWeightKg / 200) * durationMinutes
   *
   * Cardio exercises use targetDuration (seconds) directly.
   * Strength exercises estimate 3 s/rep per set + rest intervals.
   * Default MET raised to 5.0 (moderate effort) when library lookup fails;
   * 3.0 (walking) was systematically underestimating AI-generated exercises.
   */
  async calculateSetCalories(
    exerciseLibraryId: string | null,
    weightKg: number,
    reps: number,
    sets: number,
    restSeconds: number,
    userWeightKg: number = 75,
    exerciseType: string = 'STRENGTH',
    targetDuration?: number | null   // seconds, for CARDIO/FLEXIBILITY/MOBILITY
  ): Promise<number> {
    const library = exerciseLibraryId
      ? await this.prisma.exerciseLibrary.findUnique({ where: { id: exerciseLibraryId } })
      : null;

    // Use library MET when available; fall back to type-appropriate defaults
    let metValue: number = (library as any)?.metValue ?? 0;
    if (!metValue) {
      const type = exerciseType.toUpperCase();
      if (type === 'CARDIO')      metValue = 7.0;  // moderate cardio
      else if (type === 'FLEXIBILITY' || type === 'MOBILITY') metValue = 2.5;
      else                         metValue = 5.0;  // strength/default (was 3.0)
    }

    let workDurationMin: number;
    const type = exerciseType.toUpperCase();

    if ((type === 'CARDIO' || type === 'FLEXIBILITY' || type === 'MOBILITY') && targetDuration) {
      // Duration-based: use the actual planned duration
      workDurationMin = targetDuration / 60;
    } else {
      // Rep-based: average 3 seconds per rep across all sets
      workDurationMin = (sets * reps * 3) / 60;
    }

    const restDurationMin = Math.max(0, (sets - 1) * restSeconds) / 60;
    const totalDurationMin = workDurationMin + restDurationMin;

    const calories = (metValue * 3.5 * userWeightKg / 200) * totalDurationMin;
    return Math.max(0, Math.round(calories));
  }

  /**
   * Estimates the total duration of a routine in minutes.
   * Cardio/duration-based exercises use targetDuration directly.
   */
  estimateRoutineDuration(exercises: any[]): number {
    let totalMin = 0;
    for (const ex of exercises) {
      const sets = ex.targetSets || 3;
      const reps = ex.targetReps || 10;
      const rest = ex.restSeconds || 60;
      const type = (ex.exerciseType || 'STRENGTH').toUpperCase();

      let workDuration: number;
      if ((type === 'CARDIO' || type === 'FLEXIBILITY' || type === 'MOBILITY') && ex.targetDuration) {
        workDuration = ex.targetDuration / 60; // seconds → minutes
      } else {
        workDuration = (reps * 3) / 60; // 3 s/rep
      }

      const restDuration = Math.max(0, (sets - 1) * rest) / 60;
      totalMin += sets * workDuration + restDuration;
    }
    return Math.ceil(totalMin + 5); // +5 min for warmup/transitions
  }

  /**
   * Enriches a trainer or AI exercise with default professional metadata.
   */
  async enrichExercise(exercise: any) {
    if (exercise.exerciseLibraryId) {
      const library = await this.prisma.exerciseLibrary.findUnique({ 
        where: { id: exercise.exerciseLibraryId } 
      });
      
      if (library) {
        // Only apply defaults if trainer left them null
        return {
          ...exercise,
          tempoEccentric: exercise.tempoEccentric ?? (library.mechanics === 'COMPOUND' ? 3 : 2),
          tempoPause: exercise.tempoPause ?? 1,
          tempoConcentric: exercise.tempoConcentric ?? 1,
          rpe: exercise.rpe ?? (library.difficulty === 'ADVANCED' ? 8 : 7),
          restSeconds: exercise.restSeconds ?? (library.mechanics === 'COMPOUND' ? 90 : 60),
        };
      }
    }
    return exercise;
  }
}

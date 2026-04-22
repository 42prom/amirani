import { Queue, Worker, Job } from 'bullmq';
import config from '../config/env';
import logger from './logger';
import { decryptField } from './db-crypto';
import { NotificationType, NotificationChannel, DifficultyLevel, DayOfWeek } from '@prisma/client';

// ─── Provider Constants ───────────────────────────────────────────────────────
// Centralised so version bumps are a one-line change with a clear git blame trail.
const ANTHROPIC_API_VERSION = '2023-06-01';

// ─── Redis Connection ─────────────────────────────────────────────────────────
// BullMQ v5 bundles its own ioredis — pass a plain ConnectionOptions object,
// not an external IORedis instance, to avoid type conflicts.

function parseRedisUrl(url: string): { host: string; port: number; password?: string; username?: string } {
  try {
    const u = new URL(url);
    return {
      host: u.hostname || '127.0.0.1',
      port: parseInt(u.port || '6379', 10),
      ...(u.password ? { password: decodeURIComponent(u.password) } : {}),
      ...(u.username ? { username: decodeURIComponent(u.username) } : {}),
    };
  } catch {
    return { host: '127.0.0.1', port: 6379 };
  }
}

const connection = {
  ...parseRedisUrl(config.redis.url),
  maxRetriesPerRequest: null as null,
  enableReadyCheck: false,
};

// ─── Queue Definitions ────────────────────────────────────────────────────────

export const aiWorkoutQueue = new Queue('ai-workout-generation', {
  connection,
  defaultJobOptions: {
    attempts: 1, // Internal 3-tier fallback handles all AI failures — BullMQ retry never needed
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
  },
});

export const aiDietQueue = new Queue('ai-diet-generation', {
  connection,
  defaultJobOptions: {
    attempts: 1, // Internal 3-tier fallback handles all AI failures — BullMQ retry never needed
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 50 },
  },
});

export const pushNotificationQueue = new Queue('push-notifications', {
  connection,
  defaultJobOptions: {
    attempts: 2,
    backoff: { type: 'fixed', delay: 5000 },
    removeOnComplete: { count: 200 },
    removeOnFail: { count: 100 },
  },
});

// ─── Job Status Types ─────────────────────────────────────────────────────────

export type JobStatus = 'QUEUED' | 'PROCESSING' | 'COMPLETED' | 'FAILED';

export interface AiJobPayload {
  userId: string;
  type: 'WORKOUT' | 'DIET' | 'BOTH';
  goals: string;
  fitnessLevel: 'BEGINNER' | 'INTERMEDIATE' | 'ADVANCED';
  restrictions?: string[];
  availableEquipment?: string[];
  daysPerWeek?: number;
  preferred_days?: number[];
  target_muscles?: string[];
  userMetrics?: {
    weightKg?: number;
    heightCm?: number;
    age?: number;
    gender?: string;
    injuries?: string[];
    medicalConditions?: string;
    targetWeightKg?: number;
  };
  dietaryStyle?: string;
  allergies?: string[];
  allergiesStructured?: Array<{ type: string; severity: string; name?: string }>;
  likes?: string[];
  dislikedFoods?: string[];
  budgetPerDayUsd?: number;
  budget?: string;
  mealsPerDay?: number;
  mealTimes?: {
    breakfast?: string;
    morning_snack?: string;
    lunch?: string;
    afternoon_snack?: string;
    dinner?: string;
  };
  maxPrepMinutes?: number;
  tdee?: number;
  targetCalories?: number;
  targetProteinG?: number;
  numWeeks?: number;
  trainingSplit?: string;
}

export interface PushNotificationPayload {
  userIds: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
}

// ─── Enqueue Helpers ──────────────────────────────────────────────────────────

export async function enqueueAiPlanGeneration(
  type: 'WORKOUT' | 'DIET' | 'BOTH',
  payload: AiJobPayload
): Promise<{ jobId: string; dietJobId?: string }> {
  if (type === 'BOTH') {
    // Enqueue two independent jobs — one per queue — so each worker processes
    // only its own type. Both job IDs are returned so the caller can poll each independently.
    const wJobId = `ai-workout-${payload.userId}`;
    const dJobId = `ai-diet-${payload.userId}`;

    // Clean up — remove existing jobs that are not actively being processed
    const existingW = await aiWorkoutQueue.getJob(wJobId);
    if (existingW) {
      if ((await existingW.getState()) !== 'active') await existingW.remove().catch(() => {});
    }
    const existingD = await aiDietQueue.getJob(dJobId);
    if (existingD) {
      if ((await existingD.getState()) !== 'active') await existingD.remove().catch(() => {});
    }

    const workoutJob = await aiWorkoutQueue.add('generate-workout', { ...payload, type: 'WORKOUT' }, {
      priority: 1,
      jobId: wJobId
    });
    await aiDietQueue.add('generate-diet', { ...payload, type: 'DIET' }, {
      priority: 1,
      jobId: dJobId
    });
    return { jobId: workoutJob.id!, dietJobId: dJobId };
  }

  const queue = type === 'DIET' ? aiDietQueue : aiWorkoutQueue;
  const jobId = `ai-${type.toLowerCase()}-${payload.userId}`;
  
  // Clean up any stale job with this ID. We keep 'active' jobs (actually being processed by AI)
  // but remove 'waiting', 'delayed', 'failed', 'completed', and 'stalled' jobs.
  // Without this, a nodemon restart leaves a job in 'waiting' state; queuing a new job
  // with the same ID returns the stale reference, and the diet worker never picks it up.
  const existingJob = await queue.getJob(jobId);
  if (existingJob) {
    const state = await existingJob.getState();
    if (state !== 'active') {
      logger.info(`[AI_QUEUE] Removing stale ${type} job in state '${state}' before requeuuing`, { jobId });
      await existingJob.remove().catch(() => {/* ignore if already gone */});
    } else {
      // Already actively running — return its ID so mobile can track it
      logger.info(`[AI_QUEUE] ${type} job already active, returning existing ID`, { jobId });
      return { jobId: existingJob.id! };
    }
  }

  const job = await queue.add(`generate-${type.toLowerCase()}`, payload, {
    priority: 1,
    jobId
  });
  return { jobId: job.id! };
}

export async function enqueueAiJobStatus(jobId: string, type: 'WORKOUT' | 'DIET' | 'BOTH'): Promise<{
  status: JobStatus;
  progress?: number;
  message?: string;
  result?: any;
  error?: string;
}> {
  const queue = type === 'DIET' ? aiDietQueue : aiWorkoutQueue;
  const job = await queue.getJob(jobId);

  if (!job) return { status: 'FAILED', error: 'Job not found' };

  const state = await job.getState();

  const progress = job.progress;
  const progressNumber = typeof progress === 'number' ? progress : (typeof progress === 'object' && progress !== null ? (progress as any).progress : undefined);
  const progressMessage = typeof progress === 'object' && progress !== null ? (progress as any).message : undefined;

  return {
    status: stateToStatus(state),
    progress: progressNumber,
    message: progressMessage,
    result: state === 'completed' ? job.returnvalue : undefined,
    error: state === 'failed' ? (job.failedReason ?? 'Unknown error') : undefined,
  };
}

function stateToStatus(state: string): JobStatus {
  switch (state) {
    case 'completed': return 'COMPLETED';
    case 'failed':    return 'FAILED';
    case 'active':    return 'PROCESSING';
    default:          return 'QUEUED';
  }
}

// ─── Worker: AI Workout Generation ───────────────────────────────────────────

export function startAiWorkers() {
  const workoutWorker = new Worker(
    'ai-workout-generation',
    async (job: Job<AiJobPayload>) => {
      return processAiJob(job, 'WORKOUT');
    },
    // lockDuration: worst-case job ceiling (8s AI + 15s repair + 30s DB + network variance).
    // 120s is 4–5× the typical job duration — generous margin without a 10-min stall window.
    // stalledInterval: check every 30s so a crashed worker is reassigned quickly.
    { connection, concurrency: 1, lockDuration: 120_000, stalledInterval: 30_000 }
  );

  const dietWorker = new Worker(
    'ai-diet-generation',
    async (job: Job<AiJobPayload>) => {
      return processAiJob(job, 'DIET');
    },
    { connection, concurrency: 1, lockDuration: 120_000, stalledInterval: 30_000 }
  );

  const pushWorker = new Worker(
    'push-notifications',
    async (job: Job<PushNotificationPayload>) => {
      return processPushNotification(job);
    },
    { connection, concurrency: 5 }
  );

  workoutWorker.on('completed', (job) => {
    logger.info('Workout plan generated', { userId: job.data.userId });
  });

  workoutWorker.on('failed', (job, err) => {
    logger.error('Workout generation failed', { jobId: job?.id, err: err.message });
  });

  dietWorker.on('completed', (job) => {
    logger.info('Diet plan generated', { userId: job.data.userId });
  });

  dietWorker.on('failed', (job, err) => {
    logger.error('Diet generation failed', { jobId: job?.id, err: err.message });
  });

  logger.info('AI workers started', { concurrency: { workout: 1, diet: 1, push: 5 } });

  return { workoutWorker, dietWorker, pushWorker };
}

// ─── Deterministic Fallback Plans ────────────────────────────────────────────
// Used when the AI times out or fails. Guarantees the user always gets a plan.
// These are minimal but structurally valid — they pass all validators.

function buildFallbackPlan(type: 'WORKOUT' | 'DIET', payload: AiJobPayload): any {
  if (type === 'WORKOUT') {
    const days = ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'];
    const trainingDayList = (payload.preferred_days ?? [0,2,4])
      .map((d: number) => days[d])
      .filter(Boolean);
    const trainingDaySet = new Set(trainingDayList);

    // Each training day gets a DISTINCT exercise set (Push / Legs / Pull rotation).
    // Identical exercises across days would trigger the diversity validator (>60% overlap).
    const sessionRotation = [
      {
        sessionType: 'PUSH', dayName: 'Push Day',
        warmup: [{ exerciseName: 'Arm Circles', sets: 2, minReps: 15, maxReps: 15, restSeconds: 20 }],
        mainWork: [
          { exerciseName: 'Push-Up',       sets: 3, minReps: 10, maxReps: 15, rpe: 6, restSeconds: 60, progressionNote: 'Add reps each session.', muscleGroupPrimary: 'CHEST' },
          { exerciseName: 'Pike Push-Up',  sets: 3, minReps: 8,  maxReps: 12, rpe: 6, restSeconds: 60, progressionNote: 'Elevate feet to increase difficulty.', muscleGroupPrimary: 'SHOULDERS' },
          { exerciseName: 'Tricep Dip',    sets: 3, minReps: 10, maxReps: 15, rpe: 6, restSeconds: 60, progressionNote: 'Add a weighted vest when 15 reps feels easy.', muscleGroupPrimary: 'TRICEPS' },
        ],
      },
      {
        sessionType: 'LEGS', dayName: 'Legs Day',
        warmup: [{ exerciseName: 'Leg Swing', sets: 2, minReps: 15, maxReps: 15, restSeconds: 20 }],
        mainWork: [
          { exerciseName: 'Bodyweight Squat', sets: 3, minReps: 15, maxReps: 20, rpe: 6, restSeconds: 60, progressionNote: 'Focus on depth. Progress to pistol squat.', muscleGroupPrimary: 'QUADRICEPS' },
          { exerciseName: 'Reverse Lunge',    sets: 3, minReps: 10, maxReps: 14, rpe: 6, restSeconds: 60, progressionNote: 'Alternate legs. Add weight when stable.', muscleGroupPrimary: 'HAMSTRINGS' },
          { exerciseName: 'Glute Bridge',     sets: 3, minReps: 15, maxReps: 20, rpe: 5, restSeconds: 45, progressionNote: 'Progress to single-leg when 20 reps is easy.', muscleGroupPrimary: 'GLUTES' },
        ],
      },
      {
        sessionType: 'PULL', dayName: 'Pull & Core Day',
        warmup: [{ exerciseName: 'Cat-Cow Stretch', sets: 2, minReps: 10, maxReps: 10, restSeconds: 20 }],
        mainWork: [
          { exerciseName: 'Inverted Row',    sets: 3, minReps: 8,  maxReps: 12, rpe: 7, restSeconds: 60, progressionNote: 'Lower bar to increase difficulty.', muscleGroupPrimary: 'BACK' },
          { exerciseName: 'Superman Hold',   sets: 3, minReps: 10, maxReps: 15, rpe: 5, restSeconds: 45, progressionNote: 'Hold 2 seconds at top. Progress to renegade row.', muscleGroupPrimary: 'LOWER_BACK' },
          { exerciseName: 'Plank',           sets: 3, minReps: 1,  maxReps: 1,  targetSeconds: 45, rpe: 5, restSeconds: 45, progressionNote: 'Hold 30–60 seconds. Add 5s each session.', muscleGroupPrimary: 'CORE' },
        ],
      },
    ];

    let rotationIdx = 0;
    return {
      planMeta: { phase: 'Foundation', primaryGoal: payload.goals, coachNote: 'Baseline plan — regenerate when AI is available.' },
      days: days.map(dow => {
        if (!trainingDaySet.has(dow)) {
          return { dayOfWeek: dow, dayName: 'Rest Day', sessionType: 'REST', isRestDay: true, estimatedDurationMinutes: 0, warmup: [], mainWork: [] };
        }
        const session = sessionRotation[rotationIdx % sessionRotation.length];
        rotationIdx++;
        return { dayOfWeek: dow, dayName: session.dayName, sessionType: session.sessionType, isRestDay: false, estimatedDurationMinutes: 45, warmup: session.warmup, mainWork: session.mainWork };
      }),
    };
  }

  // DIET fallback — 3 foundational days, all macros accurate

  // Resolve calorie target — three-tier priority, no duplicate activity computation:
  //   1. payload.targetCalories  — mobile computed TDEE × goal correction; most accurate.
  //   2. payload.tdee            — mobile TDEE with user's real activity level selected;
  //                                apply a simple goal string correction here only.
  //   3. Raw metrics BMR × 1.55  — last resort when neither field was sent (old app versions).
  //                                Hardcoding 1.55 is acceptable ONLY here because the mobile
  //                                activity-level selector hasn't run yet.
  const estimateCaloriesFromMetrics = (): number => {
    // Tier 2: TDEE already accounts for the user's chosen activity level — just correct for goal
    if (payload.tdee) {
      const goals = (payload.goals ?? '').toLowerCase();
      let adjusted = payload.tdee;
      if (goals.includes('loss') || goals.includes('cut') || goals.includes('lean')) adjusted -= 400;
      else if (goals.includes('gain') || goals.includes('bulk') || goals.includes('muscle')) adjusted += 300;
      return Math.round(Math.max(1200, Math.min(adjusted, 4000)));
    }
    // Tier 3: neither targetCalories nor tdee — derive from raw metrics
    const m = payload.userMetrics;
    if (!m?.weightKg || !m?.heightCm || !m?.age) return 2000;
    const isFemale = /^f/i.test(m.gender ?? '');
    const bmr = isFemale
      ? 10 * m.weightKg + 6.25 * m.heightCm - 5 * m.age - 161
      : 10 * m.weightKg + 6.25 * m.heightCm - 5 * m.age + 5;
    const goals = (payload.goals ?? '').toLowerCase();
    let tdee = bmr * 1.55; // 1.55 only justified here — no activity level available
    if (goals.includes('loss') || goals.includes('cut') || goals.includes('lean')) tdee -= 400;
    else if (goals.includes('gain') || goals.includes('bulk') || goals.includes('muscle')) tdee += 300;
    return Math.round(Math.max(1200, Math.min(tdee, 4000)));
  };

  const cal = payload.targetCalories ?? estimateCaloriesFromMetrics();
  const pro = payload.targetProteinG ?? Math.round(cal * 0.30 / 4);
  const fat = Math.round(cal * 0.25 / 9);
  const carb = Math.round((cal - pro * 4 - fat * 9) / 4);
  const mealsPerDay = payload.mealsPerDay ?? 3;
  const mealNames = getMealNameSet(mealsPerDay);

  // Scale ingredient amounts/calories so they actually provide cal * calFrac kcal.
  // Previously the ingredient base calories (e.g. 465 for Oats+Chicken) were multiplied
  // by calFrac only — not by (cal / base) — so a 2000 kcal target still got 465-kcal
  // ingredients. The ghost-calories fix then corrected planMeta.dailyCalories DOWN to
  // match the tiny ingredient sum (~416 kcal), giving users a starvation plan.
  const scaleIngredients = (
    baseIngredients: Array<{ name: string; amount: number; unit: string; calories: number; protein: number; carbs: number; fats: number }>,
    baseTotalCal: number,
    calFrac: number,
  ) => {
    const scale = baseTotalCal > 0 ? (cal * calFrac) / baseTotalCal : calFrac;
    return baseIngredients.map(ing => ({
      ...ing,
      amount:   Math.round(ing.amount   * scale),
      calories: Math.round(ing.calories * scale),
      protein:  Math.round(ing.protein  * scale),
      carbs:    Math.round((ing.carbs   ?? 0) * scale),
      fats:     Math.round((ing.fats    ?? 0) * scale),
    }));
  };

  const makeMeal = (type: string, time: string, calFrac: number) => ({
    type,
    name: `Balanced ${type.charAt(0) + type.slice(1).toLowerCase()}`,
    time,
    calories: Math.round(cal * calFrac),
    protein: Math.round(pro * calFrac),
    carbs: Math.round(carb * calFrac),
    fats: Math.round(fat * calFrac),
    // dayA base: Oats 300 kcal + Chicken Breast 165 kcal = 465 kcal
    ingredients: scaleIngredients([
      { name: 'Oats',           amount: 80,  unit: 'g', calories: 300, protein: 10, carbs: 54, fats: 6 },
      { name: 'Chicken Breast', amount: 150, unit: 'g', calories: 165, protein: 31, carbs: 0,  fats: 4 },
    ], 465, calFrac),
    instructions: 'Cook and combine ingredients as preferred.',
  });

  // Distribute calories across meals using slightly uneven but nutritionally
  // sensible fractions. Derived from mealsPerDay so the fallback always stays
  // inside the same mealCalorieBounds the validator enforces.
  // Each fraction × dailyTarget must stay within avg×0.6 – avg×1.5.
  const fracsByCount: Record<number, number[]> = {
    2: [0.45, 0.55],
    3: [0.30, 0.40, 0.30],
    4: [0.25, 0.30, 0.20, 0.25],
    5: [0.20, 0.15, 0.30, 0.15, 0.20],
  };
  const fracs = fracsByCount[mealsPerDay] ??
    Array.from({ length: mealsPerDay }, () => 1 / mealsPerDay);
  // Map meal count to correct chronological times.
  // The old slice(5 - mealsPerDay) took the LAST N slots, so a 3-meal plan got
  // ['13:00','16:00','19:00'] — BREAKFAST stored at 13:00, which inferMealType()
  // re-typed as LUNCH (hour <= 14). BREAKFAST then disappeared from the UI entirely.
  const timesByCount: Record<number, string[]> = {
    2: ['08:00', '19:00'],
    3: ['08:00', '13:00', '19:00'],
    4: ['08:00', '13:00', '16:00', '19:00'],
    5: ['08:00', '10:30', '13:00', '16:00', '19:00'],
  };
  const times = timesByCount[mealsPerDay] ??
    Array.from({ length: mealsPerDay }, (_, i) =>
      `${String(8 + Math.round(i * 11 / Math.max(1, mealsPerDay - 1))).padStart(2, '0')}:00`);

  // Per-position ingredient sets indexed by [dayIndex][mealPosition].
  // Each position within a day uses DIFFERENT ingredients so no food repeats across
  // Breakfast, Lunch, Snack, and Dinner on the same day.
  // Up to 5 positions supported (covers 2-5 meal plans). Position index wraps if plan
  // has more meals than defined sets (unlikely beyond 5).
  type IngSet = { name: string; amount: number; unit: string; calories: number; protein: number; carbs: number; fats: number };
  type DayIngSets = Array<{ base: IngSet[]; total: number }>;

  const FALLBACK_DAY_MEALS: DayIngSets[] = [
    // Day A (MONDAY) — Oats · Chicken · Lentils · Salmon · Yogurt
    [
      { base: [{ name: 'Oats', amount: 80, unit: 'g', calories: 300, protein: 10, carbs: 54, fats: 6 }, { name: 'Banana', amount: 1, unit: 'pcs', calories: 89, protein: 1, carbs: 23, fats: 0 }], total: 389 },
      { base: [{ name: 'Chicken Breast', amount: 150, unit: 'g', calories: 165, protein: 31, carbs: 0, fats: 4 }, { name: 'Brown Rice', amount: 150, unit: 'g', calories: 195, protein: 4, carbs: 40, fats: 2 }], total: 360 },
      { base: [{ name: 'Greek Yogurt', amount: 150, unit: 'g', calories: 97, protein: 17, carbs: 6, fats: 1 }, { name: 'Mixed Berries', amount: 100, unit: 'g', calories: 57, protein: 1, carbs: 14, fats: 0 }], total: 154 },
      { base: [{ name: 'Salmon', amount: 140, unit: 'g', calories: 290, protein: 28, carbs: 0, fats: 18 }, { name: 'Sweet Potato', amount: 200, unit: 'g', calories: 175, protein: 3, carbs: 40, fats: 1 }], total: 465 },
      { base: [{ name: 'Lentils', amount: 120, unit: 'g', calories: 140, protein: 11, carbs: 24, fats: 1 }, { name: 'Whole Grain Bread', amount: 60, unit: 'g', calories: 158, protein: 6, carbs: 28, fats: 2 }], total: 298 },
    ],
    // Day B (TUESDAY) — Eggs · Tuna · Cottage Cheese · Turkey · Almonds
    [
      { base: [{ name: 'Eggs', amount: 2, unit: 'pcs', calories: 143, protein: 13, carbs: 1, fats: 10 }, { name: 'Avocado', amount: 80, unit: 'g', calories: 128, protein: 1, carbs: 7, fats: 12 }], total: 271 },
      { base: [{ name: 'Tuna', amount: 130, unit: 'g', calories: 145, protein: 32, carbs: 0, fats: 1 }, { name: 'Quinoa', amount: 100, unit: 'g', calories: 222, protein: 8, carbs: 39, fats: 4 }], total: 367 },
      { base: [{ name: 'Cottage Cheese', amount: 150, unit: 'g', calories: 122, protein: 21, carbs: 5, fats: 2 }, { name: 'Almonds', amount: 28, unit: 'g', calories: 164, protein: 6, carbs: 6, fats: 14 }], total: 286 },
      { base: [{ name: 'Ground Turkey', amount: 150, unit: 'g', calories: 175, protein: 28, carbs: 0, fats: 7 }, { name: 'Sweet Potato', amount: 200, unit: 'g', calories: 175, protein: 3, carbs: 40, fats: 1 }], total: 350 },
      { base: [{ name: 'Rice Cakes', amount: 2, unit: 'pcs', calories: 70, protein: 1, carbs: 15, fats: 1 }, { name: 'Peanut Butter', amount: 30, unit: 'g', calories: 188, protein: 8, carbs: 6, fats: 16 }], total: 258 },
    ],
    // Day C (WEDNESDAY) — Yogurt · Turkey · Protein Shake · Chicken Thighs · Walnuts
    [
      { base: [{ name: 'Greek Yogurt', amount: 200, unit: 'g', calories: 130, protein: 22, carbs: 8, fats: 1 }, { name: 'Granola', amount: 50, unit: 'g', calories: 220, protein: 5, carbs: 36, fats: 7 }], total: 350 },
      { base: [{ name: 'Turkey Breast', amount: 150, unit: 'g', calories: 165, protein: 31, carbs: 0, fats: 4 }, { name: 'Brown Rice', amount: 130, unit: 'g', calories: 169, protein: 3, carbs: 35, fats: 1 }], total: 334 },
      { base: [{ name: 'Whey Protein', amount: 35, unit: 'g', calories: 140, protein: 25, carbs: 8, fats: 2 }, { name: 'Oat Milk', amount: 250, unit: 'ml', calories: 110, protein: 3, carbs: 19, fats: 3 }], total: 250 },
      { base: [{ name: 'Chicken Thighs', amount: 200, unit: 'g', calories: 292, protein: 30, carbs: 0, fats: 18 }, { name: 'Broccoli', amount: 200, unit: 'g', calories: 68, protein: 6, carbs: 11, fats: 1 }], total: 360 },
      { base: [{ name: 'Walnuts', amount: 28, unit: 'g', calories: 185, protein: 4, carbs: 4, fats: 18 }, { name: 'Apple', amount: 1, unit: 'pcs', calories: 95, protein: 0, carbs: 25, fats: 0 }], total: 280 },
    ],
    // Day D (SUNDAY) — Oatmeal · Lean Beef · Hard-Boiled Eggs · Salmon · Milk
    [
      { base: [{ name: 'Oatmeal', amount: 70, unit: 'g', calories: 263, protein: 9, carbs: 47, fats: 5 }, { name: 'Blueberries', amount: 100, unit: 'g', calories: 57, protein: 1, carbs: 14, fats: 0 }], total: 320 },
      { base: [{ name: 'Lean Beef', amount: 150, unit: 'g', calories: 218, protein: 26, carbs: 0, fats: 13 }, { name: 'Pasta', amount: 80, unit: 'g', calories: 280, protein: 10, carbs: 55, fats: 2 }], total: 498 },
      { base: [{ name: 'Hard-Boiled Eggs', amount: 2, unit: 'pcs', calories: 143, protein: 13, carbs: 1, fats: 10 }, { name: 'Orange', amount: 1, unit: 'pcs', calories: 62, protein: 1, carbs: 15, fats: 0 }], total: 205 },
      { base: [{ name: 'Baked Salmon', amount: 180, unit: 'g', calories: 373, protein: 37, carbs: 0, fats: 22 }, { name: 'Quinoa', amount: 100, unit: 'g', calories: 222, protein: 8, carbs: 39, fats: 4 }], total: 595 },
      { base: [{ name: 'Low-Fat Milk', amount: 300, unit: 'ml', calories: 150, protein: 10, carbs: 14, fats: 5 }, { name: 'Mixed Nuts', amount: 30, unit: 'g', calories: 180, protein: 5, carbs: 6, fats: 16 }], total: 330 },
    ],
  ];

  // Build 4 DISTINCT foundational days. Each day's meals pick from their own per-position
  // ingredient set so no ingredient repeats within the same day's meals.
  const buildFallbackDay = (dayIdx: number) =>
    mealNames.map((name, i) => {
      const sets = FALLBACK_DAY_MEALS[dayIdx];
      const { base, total } = sets[i % sets.length];
      return {
        ...makeMeal(name, times[i] ?? '12:00', fracs[i] ?? 0.2),
        ingredients: scaleIngredients(base, total, fracs[i] ?? 0.2),
      };
    });

  const dayA = buildFallbackDay(0);
  const dayB = buildFallbackDay(1);
  const dayC = buildFallbackDay(2);
  const dayD = buildFallbackDay(3);

  return {
    planMeta: { dailyCalories: cal, macros: { protein: pro, carbs: carb, fats: fat }, hydrationTargetMl: 2500 },
    days: [
      { dayOfWeek: 'MONDAY',    isTrainingDay: true,  meals: dayA },
      { dayOfWeek: 'TUESDAY',   isTrainingDay: false, meals: dayB },
      { dayOfWeek: 'WEDNESDAY', isTrainingDay: true,  meals: dayC },
      { dayOfWeek: 'SUNDAY',    isTrainingDay: false, meals: dayD },
    ],
  };
}

// ─── Repair Loop Helper ───────────────────────────────────────────────────────
// Sends a targeted re-prompt to the AI with the exact list of validation errors
// and the original bad JSON. Returns the corrected plan object, or null on failure.
// Hard cap: 15 seconds. Only 1 attempt is made; the caller falls back if it fails.

async function attemptRepair(
  aiConfig: any,
  badPlan: any,
  errors: string[],
  type: 'WORKOUT' | 'DIET',
  payload: AiJobPayload
): Promise<any | null> {
  try {
    const axios = (await import('axios')).default;
    const REPAIR_TIMEOUT_MS = 15_000;

    const errorList = errors.map(e => `  • ${e}`).join('\n');

    // Build a repair context that sends full content for affected days and a structural
    // skeleton for unaffected days. This gives the AI exactly what it needs to fix the
    // specific errors without asking it to regenerate the entire plan from a summary.
    // Previously the summary contained no actual content — the AI was blind to the
    // exercises/meals it needed to change, so "repair" was effectively a full regeneration.
    const DAY_NAMES = ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'];
    const affectedDays = new Set<string>();
    for (const err of errors) {
      for (const day of DAY_NAMES) {
        if (err.includes(day)) affectedDays.add(day);
      }
    }
    // If no specific day is named in the errors (e.g. "Missing planMeta", "No rest day"),
    // include all days at full fidelity so the AI can restructure freely.
    const includeAll = affectedDays.size === 0;

    const planContext = JSON.stringify({
      planMeta: badPlan.planMeta,
      dayCount: (badPlan.days ?? []).length,
      days: (badPlan.days ?? []).map((d: any) => {
        if (includeAll || affectedDays.has(d.dayOfWeek)) {
          // Full content — AI can see and fix the actual problematic exercises/meals
          return d;
        }
        // Structural skeleton only — tokens saved for days that don't need repair
        return {
          dayOfWeek: d.dayOfWeek,
          sessionType: d.sessionType,
          isRestDay: d.isRestDay,
          exerciseCount: (d.mainWork ?? []).length,
          mealCount: (d.meals ?? []).length,
        };
      }),
    }, null, 0);

    const repairPrompt =
      `The following ${type} plan has validation errors. ` +
      `Fix ONLY the listed issues. Return the corrected, complete JSON (pure JSON — no markdown, no prose).\n\n` +
      `ERRORS:\n${errorList}\n\n` +
      `PLAN (affected days shown in full; others summarised):\n${planContext}`;

    const mealsPerDay = payload.mealsPerDay ?? 3;
    const systemPrompt = type === 'WORKOUT'
      ? buildWorkoutSystemPrompt()
      : buildDietSystemPrompt(mealsPerDay, getMealNameSet(mealsPerDay));

    let rawContent = '';

    const callPromise = (async () => {
      if (aiConfig.activeProvider === 'OPENAI' && aiConfig.openaiApiKey) {
        const r = await axios.post(
          'https://api.openai.com/v1/chat/completions',
          {
            model: aiConfig.openaiModel,
            messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: repairPrompt }],
            temperature: aiConfig.temperature ?? 0.7,
            max_tokens: aiConfig.maxTokensPerRequest || 4096,
            response_format: { type: 'json_object' },
          },
          { headers: { Authorization: `Bearer ${aiConfig.openaiApiKey}` } }
        );
        rawContent = r.data.choices[0].message.content;
      } else if (aiConfig.activeProvider === 'ANTHROPIC' && aiConfig.anthropicApiKey) {
        const r = await axios.post(
          'https://api.anthropic.com/v1/messages',
          {
            model: aiConfig.anthropicModel,
            max_tokens: Math.min(aiConfig.maxTokensPerRequest || 4096, 8192),
            temperature: aiConfig.temperature ?? 0.7,
            system: systemPrompt,
            messages: [{ role: 'user', content: repairPrompt }],
          },
          { headers: { 'x-api-key': aiConfig.anthropicApiKey, 'anthropic-version': ANTHROPIC_API_VERSION } }
        );
        rawContent = r.data.content[0].text;
      } else if (aiConfig.activeProvider === 'DEEPSEEK' && aiConfig.deepseekApiKey) {
        const r = await axios.post(
          `${aiConfig.deepseekBaseUrl}/chat/completions`,
          {
            model: aiConfig.deepseekModel,
            messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: repairPrompt }],
            temperature: aiConfig.temperature ?? 0.7,
            max_tokens: Math.min(aiConfig.maxTokensPerRequest || 4096, 8192),
            response_format: { type: 'json_object' },
          },
          { headers: { Authorization: `Bearer ${aiConfig.deepseekApiKey}` } }
        );
        rawContent = r.data.choices[0].message.content;
      } else {
        throw new Error('No AI provider available for repair');
      }
    })();

    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Repair timeout')), REPAIR_TIMEOUT_MS)
    );

    await Promise.race([callPromise, timeoutPromise]);

    const cleaned = rawContent.trim();
    const start = cleaned.indexOf('{');
    const end   = cleaned.lastIndexOf('}');
    if (start === -1 || end === -1 || end <= start) return null;

    return JSON.parse(cleaned.substring(start, end + 1));
  } catch (err: any) {
    logger.warn(`[AI_REPAIR] Repair call failed: ${err.message}`);
    return null;
  }
}

// ─── AI Config Cache ──────────────────────────────────────────────────────────
// Module-level cache with 60-second TTL. Eliminates 1 DB read per job without
// risking stale config — platform admins rarely change AI settings mid-flight,
// and 60s lag is acceptable.

let _aiConfigCache: { value: any; expiresAt: number } | null = null;

async function getAiConfig(prisma: any): Promise<any> {
  const now = Date.now();
  if (_aiConfigCache && now < _aiConfigCache.expiresAt) return _aiConfigCache.value;
  // orderBy: updatedAt desc — deterministic when multiple configs are enabled.
  // Without this, findFirst returns an arbitrary row on each cache miss.
  const cfg = await prisma.aIConfig.findFirst({ where: { isEnabled: true }, orderBy: { updatedAt: 'desc' } });
  const decrypted = cfg ? {
    ...cfg,
    openaiApiKey:    decryptField(cfg.openaiApiKey),
    anthropicApiKey: decryptField(cfg.anthropicApiKey),
    googleApiKey:    decryptField(cfg.googleApiKey),
    azureApiKey:     decryptField(cfg.azureApiKey),
    deepseekApiKey:  decryptField(cfg.deepseekApiKey),
  } : cfg;
  _aiConfigCache = { value: decrypted, expiresAt: now + 60_000 };
  return decrypted;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/** Returns the model name string for the active AI provider. */
function resolveModelName(aiConfig: any): string {
  switch (aiConfig.activeProvider) {
    case 'OPENAI':        return aiConfig.openaiModel ?? 'unknown';
    case 'ANTHROPIC':     return aiConfig.anthropicModel ?? 'unknown';
    case 'DEEPSEEK':      return aiConfig.deepseekModel ?? 'unknown';
    case 'GOOGLE_GEMINI': return aiConfig.googleModel ?? 'unknown';
    default:              return 'unknown';
  }
}

// ─── Job Processors ───────────────────────────────────────────────────────────

async function processAiJob(job: Job<AiJobPayload>, type: 'WORKOUT' | 'DIET') {
  // Import here to avoid circular deps and keep startup clean
  const { default: prisma } = await import('./prisma');
  const { PlatformConfigService } = await import('../modules/platform/platform-config.service');

  await job.updateProgress({ progress: 10, message: 'Consulting top-tier coaches...' });

  // Get AI config (60-second module-level cache — eliminates 1 DB read per job)
  const aiConfig = await getAiConfig(prisma);
  if (!aiConfig) throw new Error('AI is disabled on this platform');

  // Profile compilation milestone
  await job.updateProgress({ progress: 20, message: 'Building your metabolic profile...' });

  logger.info(`[AI_${type}] Step 2/5: Consulting Intelligence Models...`, { userId: job.data.userId, jobId: job.id, type });
  const startAi = Date.now();
  
  // SYNERGY: Diet can peek at Workout schedule (but not vice versa for privacy/autonomy)
  const sanitizedPayload = { ...job.data };
  if (type === 'WORKOUT') {
    delete (sanitizedPayload as any).dietaryStyle;
    delete (sanitizedPayload as any).allergies;
  } else {
    // Diet keeps preferred_days if available to assist with macro-cycling
    delete (sanitizedPayload as any).target_muscles;
    delete (sanitizedPayload as any).daysPerWeek;
  }

  // ── PARALLEL FALLBACK (8-second hard cap) ────────────────────────────────
  // Run the AI call and an 8-second timeout race simultaneously.
  // If the AI wins: use its result.
  // If the timeout wins first: use the deterministic fallback template so the
  // user never stares at an infinite spinner. The job still completes successfully.
  const AI_HARD_TIMEOUT_MS = 8_000;

  // AbortController lets us cancel the live HTTP connection when the timeout wins the race.
  // Without this, the axios request runs for up to the provider's own timeout (minutes),
  // holding a TCP socket and counting against the provider's rate limit.
  const abortController = new AbortController();

  const aiCallPromise = callAiProvider(aiConfig, sanitizedPayload, type, abortController.signal)
    .then(r => ({ outcome: 'ai' as const, data: r }))
    .catch(err => ({ outcome: 'ai_error' as const, err }));

  const timeoutPromise = new Promise<{ outcome: 'timeout' }>(resolve =>
    setTimeout(() => {
      abortController.abort(); // cancel the in-flight HTTP request immediately
      resolve({ outcome: 'timeout' });
    }, AI_HARD_TIMEOUT_MS)
  );

  const race = await Promise.race([aiCallPromise, timeoutPromise]);

  let result: any = null;
  let usedFallback = false;
  let repairAttempted = false;

  if (race.outcome === 'ai') {
    result = race.data;
  } else if (race.outcome === 'timeout' || race.outcome === 'ai_error') {
    if (race.outcome === 'ai_error') {
      logger.error(`[AI_${type}] AI Provider Failed`, { userId: job.data.userId, error: (race as any).err?.message });
      if ((race as any).err?.usage) {
        await PlatformConfigService.logAIUsage({
          userId: job.data.userId,
          provider: aiConfig.activeProvider,
          model: resolveModelName(aiConfig),
          promptTokens: (race as any).err.usage?.prompt_tokens ?? 0,
          completionTokens: (race as any).err.usage?.completion_tokens ?? 0,
          requestType: `${type}_PLAN_GENERATION_FAILED`,
        });
      }
    } else {
      logger.warn(`[AI_${type}] AI exceeded ${AI_HARD_TIMEOUT_MS}ms hard cap. Activating deterministic fallback.`, { userId: job.data.userId });
    }
    result = { result: buildFallbackPlan(type, job.data), usage: null };
    usedFallback = true;
    // Log a zero-token usage entry so the daily quota counter still decrements.
    // Without this, every timeout generates a free plan and burns no quota —
    // users can generate unlimited fallback plans when the AI provider is down.
    try {
      await PlatformConfigService.logAIUsage({
        userId: job.data.userId,
        provider: aiConfig.activeProvider,
        model: resolveModelName(aiConfig),
        promptTokens: 0,
        completionTokens: 0,
        requestType: `${type}_PLAN_GENERATION_FALLBACK`,
      });
    } catch (_) { /* non-critical — don't fail the job over a logging error */ }
  }

  if (usedFallback) {
    logger.warn(`[AI_${type}] Using deterministic fallback plan for user ${job.data.userId}`);
  }

  const aiDuration = Date.now() - startAi;
  logger.info(`[AI_${type}] Step 2/5 COMPLETE: AI Responded.`, { 
    userId: job.data.userId, 
    durationMs: aiDuration,
    resultFound: !!result,
    usage: result?.usage
  });

  // AI call complete milestone — mobile sees progress jump to 50% when AI responds
  await job.updateProgress({ progress: 50, message: 'Analyzing your fitness data...' });

  // 2. Validate and Save AI output
  let aiPlanContent = result.result;

  // SAFETY GUARD: Resilient shifting if AI hallucinates the "plan" wrapper nonetheless.
  if (aiPlanContent && aiPlanContent.plan && !aiPlanContent.days) {
    aiPlanContent = aiPlanContent.plan;
  }

  // ── REPAIR LOOP (1 attempt, 15-second hard cap) ──────────────────────────
  // Collect all validation errors at once. If the AI made correctable mistakes,
  // send them back in a single targeted re-prompt instead of discarding the plan.
  // One repair attempt only — then deterministic fallback if still failing.
  // Skip this step if we already activated the fallback.
  if (!usedFallback) {
    const mpdForValidation = job.data.mealsPerDay ?? 3;
    const targetCalForValidation = job.data.targetCalories;
    const requestedDaysForValidation = job.data.daysPerWeek ?? 0;
    const firstPassErrors = type === 'WORKOUT'
      ? collectWorkoutErrors(aiPlanContent, requestedDaysForValidation)
      : collectDietErrors(aiPlanContent, mpdForValidation, targetCalForValidation);

    if (firstPassErrors.length > 0) {
      logger.warn(`[AI_${type}] Validation: ${firstPassErrors.length} error(s). Attempting 1-shot repair.`, {
        userId: job.data.userId,
        errors: firstPassErrors,
      });
      await job.updateProgress({ progress: 82, message: 'Fine-tuning your plan...' });
      repairAttempted = true;
      const repaired = await attemptRepair(aiConfig, aiPlanContent, firstPassErrors, type, job.data);

      if (repaired) {
        const repairErrors = type === 'WORKOUT'
          ? collectWorkoutErrors(repaired, requestedDaysForValidation)
          : collectDietErrors(repaired, mpdForValidation, targetCalForValidation);

        if (repairErrors.length === 0) {
          logger.info(`[AI_${type}] Repair successful — plan passes all validators.`, { userId: job.data.userId });
          aiPlanContent = repaired;
        } else {
          logger.warn(`[AI_${type}] Repaired plan still has ${repairErrors.length} error(s). Using deterministic fallback.`, {
            userId: job.data.userId,
            errors: repairErrors,
          });
          aiPlanContent = buildFallbackPlan(type, job.data);
          usedFallback = true;
        }
      } else {
        logger.warn(`[AI_${type}] Repair call failed or timed out. Using deterministic fallback.`, { userId: job.data.userId });
        aiPlanContent = buildFallbackPlan(type, job.data);
        usedFallback = true;
      }
    }
  }

  // ── VALIDATE + SAVE (guarded — job always completes, never lets BullMQ retry) ──
  // If the AI plan fails final validation or the DB save throws, we catch the error,
  // log it, and save the deterministic fallback instead. The user always gets a plan.
  try {
    if (type === 'WORKOUT') {
      // Fallback plans are pre-validated by construction — skip to avoid triggering
      // the emergency fallback if a future buildFallbackPlan change breaks a validator rule.
      if (!usedFallback) {
        logger.info(`[AI_WORKOUT] Step 3/5: Validating Workout Logic...`, { userId: job.data.userId });
        validateWorkoutPlan(aiPlanContent, job.data.daysPerWeek ?? 3);
      }
      await job.updateProgress({ progress: 85, message: 'Finalizing session periodization...' });
      logger.info(`[AI_WORKOUT] Step 4/5: Persisting Master Template to PostgreSQL...`, { userId: job.data.userId });
      await saveWorkoutPlan(prisma, job.data.userId, aiPlanContent, job.data);
    } else {
      if (!usedFallback) {
        logger.info(`[AI_DIET] Step 3/5: Validating Nutritional Composition...`, { userId: job.data.userId });
        validateDietPlan(aiPlanContent, job.data.mealsPerDay ?? 3, job.data.targetCalories);
      }
      await job.updateProgress({ progress: 85, message: 'Hydrating ingredient profiles...' });
      logger.info(`[AI_DIET] Step 4/5: Persisting Comprehensive Plan to PostgreSQL...`, { userId: job.data.userId });
      await saveDietPlan(prisma, job.data.userId, aiPlanContent, job.data, usedFallback);
    }
  } catch (saveError: any) {
    // Emergency fallback: if plan save fails for any reason (validation or DB),
    // save the deterministic plan instead so the user is never left without a plan.
    logger.error(`[AI_${type}] Plan save failed — activating emergency fallback.`, {
      userId: job.data.userId,
      error: saveError.message,
    });
    try {
      const emergencyPlan = buildFallbackPlan(type, job.data);
      if (type === 'WORKOUT') {
        await saveWorkoutPlan(prisma, job.data.userId, emergencyPlan, job.data);
      } else {
        await saveDietPlan(prisma, job.data.userId, emergencyPlan, job.data, true);
      }
      usedFallback = true;
    } catch (emergencyError: any) {
      // DB is unreachable — we cannot save anything. Log it and rethrow so BullMQ
      // marks the job failed. Mobile polling will surface a FAILED status to the UI
      // instead of leaving the user on an infinite spinner.
      logger.error(`[AI_${type}] EMERGENCY FALLBACK ALSO FAILED — DB may be unavailable.`, {
        userId: job.data.userId,
        error: emergencyError.message,
      });
      throw emergencyError;
    }
  }

  // SYNC TRIGGER: Force mobile app to recognize fresh data immediately
  await prisma.user.update({ where: { id: job.data.userId }, data: { updatedAt: new Date() } });

  const totalDurationMs = Date.now() - startAi;
  logger.info(`[AI_METRICS]`, {
    userId: job.data.userId,
    type,
    provider: aiConfig.activeProvider,
    model: resolveModelName(aiConfig),
    totalDurationMs,
    fallback_used: usedFallback,
    repair_attempted: repairAttempted,
    prompt_tokens: result?.usage?.prompt_tokens ?? 0,
    completion_tokens: result?.usage?.completion_tokens ?? 0,
  });
  logger.info(`[AI_${type}] Step 5/5: COMPLETE.`, { userId: job.data.userId, usedFallback });

  // 3. Log Successful AI usage via PlatformConfigService to include cost calculation
  await PlatformConfigService.logAIUsage({
    userId: job.data.userId,
    provider: aiConfig.activeProvider,
    model: resolveModelName(aiConfig),
    promptTokens: result.usage?.prompt_tokens ?? 0,
    completionTokens: result.usage?.completion_tokens ?? 0,
    requestType: `${type}_PLAN_GENERATION`,
  });

  // DB persisted — mobile now at 90%, about to receive push notification
  await job.updateProgress({ progress: 90, message: 'Sending your plan to the cloud...' });
  await job.updateProgress(100);

  // 4. Enqueue push notification
  await pushNotificationQueue.add('plan-ready', {
    userIds: [job.data.userId],
    title: `Your ${type === 'WORKOUT' ? 'workout' : 'diet'} plan is ready! 💪`,
    body: 'Tap to view your new personalized plan.',
    data: { type: `${type}_PLAN`, action: 'VIEW_PLAN' },
  }, { jobId: `push-plan-ready-${job.data.userId}-${type}` });

  return { success: true, type, plan: aiPlanContent };
}

async function callAiProvider(aiConfig: any, payload: AiJobPayload, type: 'WORKOUT' | 'DIET', signal?: AbortSignal): Promise<{ result: any; usage?: any }> {
  // Dynamic import to keep server startup fast
  const axios = (await import('axios')).default;

  const mealsPerDay = payload.mealsPerDay || 3;
  const mealNames   = getMealNameSet(mealsPerDay);

  const systemPrompt = type === 'WORKOUT'
    ? buildWorkoutSystemPrompt()
    : buildDietSystemPrompt(mealsPerDay, mealNames);

  const userPrompt = buildUserPrompt(payload, type);

  // We explicitly tell Anthropic about the system prompt outside the messages array
  const anthropicMessages = [
    { role: 'user', content: userPrompt }
  ];

  const standardMessages = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt },
  ];

  logger.info(`[AI_TRACE] Calling ${aiConfig.activeProvider} for ${type}`);
  logger.debug(`[AI_TRACE] System Prompt: ${systemPrompt.substring(0, 1000)}...`);
  logger.debug(`[AI_TRACE] User Prompt: ${userPrompt.substring(0, 1000)}...`);

  let rawContent: string = '';
  let usageData: any = null;

  if (aiConfig.activeProvider === 'OPENAI' && aiConfig.openaiApiKey) {
    try {
      const response = await axios.post(
        'https://api.openai.com/v1/chat/completions',
        {
          model: aiConfig.openaiModel,
          messages: standardMessages,
          temperature: aiConfig.temperature || 0.7,
          max_tokens: aiConfig.maxTokensPerRequest || 4096,
          response_format: { type: 'json_object' },
        },
        { headers: { Authorization: `Bearer ${aiConfig.openaiApiKey}` }, signal }
      );
      rawContent = response.data.choices[0].message.content;
      logger.info(`[AI_TRACE] Raw content received from OpenAI (${rawContent.length} chars)`);
      logger.debug(`[AI_TRACE] Raw snippet: ${rawContent.substring(0, 500)}...`);
      usageData = response.data.usage;
      if (response.data.choices[0].finish_reason === 'length') {
        logger.warn(`[AI_${type}] OpenAI response truncated. Consider increasing max_tokens or simplifying the ${type} prompt.`, { jobId: (payload as any).jobId });
      }
    } catch (error: any) {
      if (error.response?.data) {
        logger.error('OpenAI API Error Details', { data: error.response.data });
        throw new Error(`OpenAI Error: ${JSON.stringify(error.response.data)}`);
      }
      throw error;
    }
  } else if (aiConfig.activeProvider === 'ANTHROPIC' && aiConfig.anthropicApiKey) {
    try {
      const response = await axios.post(
        'https://api.anthropic.com/v1/messages',
        {
          model: aiConfig.anthropicModel,
          max_tokens: Math.min(aiConfig.maxTokensPerRequest || 4096, 8192),
          temperature: aiConfig.temperature ?? 0.7,   // P0: was missing — admin panel setting now honoured
          system: systemPrompt,
          messages: anthropicMessages,
        },
        { headers: { 'x-api-key': aiConfig.anthropicApiKey, 'anthropic-version': ANTHROPIC_API_VERSION }, signal }
      );
      rawContent = response.data.content[0].text;
      logger.info(`[AI_TRACE] Raw content received from Anthropic (${rawContent.length} chars)`);
      logger.debug(`[AI_TRACE] Raw snippet: ${rawContent.substring(0, 500)}...`);
      if (response.data.stop_reason === 'max_tokens') {
        logger.warn(`[AI_${type}] Anthropic response truncated. Consider increasing max_tokens or simplifying the ${type} prompt.`, { jobId: (payload as any).jobId });
      }
      usageData = {
        prompt_tokens: response.data.usage?.input_tokens ?? 0,
        completion_tokens: response.data.usage?.output_tokens ?? 0,
        total_tokens: (response.data.usage?.input_tokens ?? 0) + (response.data.usage?.output_tokens ?? 0),
      };
    } catch (error: any) {
      if (error.response?.data) {
        logger.error('Anthropic API Error Details', { data: error.response.data });
        throw new Error(`Anthropic Error: ${JSON.stringify(error.response.data)}`);
      }
      throw error;
    }
  } else if (aiConfig.activeProvider === 'DEEPSEEK' && aiConfig.deepseekApiKey) {
    try {
      const response = await axios.post(
        `${aiConfig.deepseekBaseUrl}/chat/completions`,
        {
          model: aiConfig.deepseekModel,
          messages: standardMessages,
          temperature: aiConfig.temperature || 0.7,
          max_tokens: Math.min(aiConfig.maxTokensPerRequest || 4096, 8192),
          response_format: { type: 'json_object' },
        },
        { headers: { Authorization: `Bearer ${aiConfig.deepseekApiKey}` }, signal }
      );
      rawContent = response.data.choices[0].message.content;
      usageData = response.data.usage;
      if (response.data.choices[0].finish_reason === 'length') {
        logger.warn(`[AI_${type}] DeepSeek response truncated. Consider increasing max_tokens or simplifying the ${type} prompt.`, { jobId: (payload as any).jobId, tokens: usageData?.completion_tokens });
      }
    } catch (error: any) {
      if (error.response?.data) {
        logger.error('DeepSeek API Error Details', { data: error.response.data });
        throw new Error(`DeepSeek Error: ${JSON.stringify(error.response.data)}`);
      }
      throw error;
    }
  } else if (aiConfig.activeProvider === 'AZURE_OPENAI' || aiConfig.activeProvider === 'GOOGLE_GEMINI') {
    throw new Error(`Provider ${aiConfig.activeProvider} is accepted in configuration but not yet implemented in the generation worker. Switch to OPENAI, ANTHROPIC, or DEEPSEEK.`);
  } else {
    throw new Error(`No AI provider configured with a valid API key (activeProvider=${aiConfig.activeProvider})`);
  }

  try {
    // Robust extraction fallback just in case of slight spacing anomalies
    let cleaned = rawContent.trim();
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    
    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }
    
    const parsed = JSON.parse(cleaned);
    
    return { 
      result: parsed, 
      usage: usageData 
    };
  } catch (err: any) {
    // If parsing fails, log a snippet for easier debugging of truncation
    logger.error('Failed to parse AI response JSON', { 
      error: err.message, 
      snippet: rawContent.substring(Math.max(0, rawContent.length - 500)), // Last 500 chars
      length: rawContent.length 
    });

    // Wrap error with usage data so it can still be logged for cost tracking
    const enrichedError: any = new Error('AI returned invalid JSON: ' + err.message);
    enrichedError.usage = usageData;
    throw enrichedError;
  }
}

async function saveWorkoutPlan(prisma: any, userId: string, aiResult: any, payload: AiJobPayload) {
  if (!aiResult?.planMeta && !aiResult?.days) {
    throw new Error('saveWorkoutPlan: AI result has neither planMeta nor days — cannot save workout plan.');
  }

  const templateName = aiResult.planMeta?.phase
    ? `${aiResult.planMeta.phase} — ${aiResult.planMeta.primaryGoal || 'Elite Cycle'}`
    : `AI Workout Template`;

  const rawDays = aiResult.days
    ? (Array.isArray(aiResult.days) ? aiResult.days : Object.values(aiResult.days))
    : [];

  // ── PRE-FETCH READS (outside transaction — reads don't need ACID) ─────────────
  // Fetch equipment ONCE for all days, not once per day inside the loop.
  const userMemberships = await prisma.gymMembership.findMany({
    where: { userId, status: 'ACTIVE' },
    include: { gym: { include: { equipment: true } } },
  });
  const gymEquipment = new Set<string>(
    userMemberships.flatMap((m: any) => m.gym.equipment.map((e: any) => e.name.toLowerCase()))
  );
  // For home users (no gym membership), fall back to the self-reported equipment
  // the user provided during onboarding — otherwise the guardrail swaps every
  // dumbbell exercise to bodyweight even when the user owns dumbbells at home.
  const selfReportedEquipment = new Set<string>(
    (payload.availableEquipment ?? []).map((e: string) => e.toLowerCase())
  );
  const availableEquipmentNames = gymEquipment.size > 0 ? gymEquipment : selfReportedEquipment;

  // Batch-load all exercise library entries in ONE query instead of N individual lookups.
  const allExerciseNames = rawDays
    .flatMap((d: any) => [...(d.mainWork ?? []), ...(d.warmup ?? [])])
    .map((ex: any) => ex.exerciseName)
    .filter((n: any): n is string => typeof n === 'string' && n.length > 0);

  const libraryEntries = allExerciseNames.length > 0
    ? await prisma.exerciseLibrary.findMany({
        where: { name: { in: allExerciseNames, mode: 'insensitive' } },
      })
    : [];
  const libraryMap = new Map<string, any>(
    libraryEntries.map((e: any) => [e.name.toLowerCase(), e])
  );

  // ── ALL WRITES IN A SINGLE TRANSACTION ───────────────────────────────────────
  // If any write fails, ALL writes roll back — no orphaned master templates.
  await prisma.$transaction(async (tx: any) => {
    const txAny = tx as any;
    const MasterWorkoutModel = txAny.MasterWorkoutTemplate || txAny.masterWorkoutTemplate;
    const MasterRoutineModel = txAny.MasterWorkoutRoutine  || txAny.masterWorkoutRoutine;
    const ExerciseSetModel   = txAny.MasterExerciseSet     || txAny.masterExerciseSet;
    const WorkoutPlanModel   = txAny.WorkoutPlan           || txAny.workoutPlan;

    if (!MasterWorkoutModel || !MasterRoutineModel || !ExerciseSetModel || !WorkoutPlanModel) {
      throw new Error('CRITICAL: One or more required Workout models are missing from Prisma client accessors.');
    }

    const masterTemplate = await MasterWorkoutModel.create({
      data: {
        name: templateName,
        description: aiResult.planMeta?.coachNote ?? `Generated for: ${payload.goals}`,
        difficulty: payload.fitnessLevel as DifficultyLevel,
        isAIGenerated: true,
        creatorId: null,
      },
    });

    for (let i = 0; i < rawDays.length; i++) {
      const day = rawDays[i];
      const masterRoutine = await MasterRoutineModel.create({
        data: {
          templateId: masterTemplate.id,
          name: day.sessionType ?? day.dayName ?? `Day ${i + 1}`,
          dayOfWeek: day.dayOfWeek ? (day.dayOfWeek.toUpperCase() as DayOfWeek) : null,
          estimatedMinutes: day.estimatedDurationMinutes ?? 60,
          orderIndex: i,
        },
      });

      // Save mainWork first, then warmup — separated by a large orderIndex gap so
      // mobile can distinguish warmup from main work without a schema change.
      // orderIndex 0–99: main work  |  1000+: warmup
      const mainWorkExercises: any[] = (day.mainWork ?? []).map((ex: any, idx: number) => ({ ...ex, _saveIdx: idx, _isWarmup: false }));
      const warmupExercises:   any[] = (day.warmup   ?? []).map((ex: any, idx: number) => ({ ...ex, _saveIdx: idx + 1000, _isWarmup: true }));
      const exercises = [...mainWorkExercises, ...warmupExercises];

      for (const ex of exercises) {
        let library = ex.exerciseName ? (libraryMap.get(ex.exerciseName.toLowerCase()) ?? null) : null;

        // ── EQUIPMENT GUARDRAIL: swap to bodyweight substitute if needed ──
        if (!ex._isWarmup && library && library.equipment && library.equipment.length > 0) {
          const canExecute = (library.equipment as string[]).every((req: string) =>
            availableEquipmentNames.has(req.toLowerCase()) || req.toLowerCase() === 'bodyweight'
          );
          if (!canExecute) {
            const substitute = await tx.exerciseLibrary.findFirst({
              where: {
                primaryMuscle: library.primaryMuscle,
                id: { not: library.id },
                OR: [
                  { equipment: { hasSome: Array.from(availableEquipmentNames) } },
                  { equipment: { isEmpty: true } },
                ],
              },
            });
            if (substitute) {
              logger.info(`GUARDRAIL: Swapping ${library.name} → ${substitute.name} (equipment mismatch).`);
              library = substitute;
              ex.exerciseName = substitute.name;
            }
          }
        }

        // minReps/maxReps: canonical AI fields. Legacy 'reps' string parsed as fallback.
        const minReps = ex.minReps ?? parseInt(String(ex.reps ?? '10').split('-')[0]) ?? 10;
        const maxReps = ex.maxReps ?? parseInt(String(ex.reps ?? '10').split('-').pop()!) ?? minReps;
        const repRange = minReps !== maxReps ? `${minReps}–${maxReps} reps. ` : '';
        // Prefix warmup note so mobile can display "(Warmup)" badge without schema change
        const warmupPrefix = ex._isWarmup ? '[Warmup] ' : '';
        const progressionNote = `${warmupPrefix}${repRange}${ex.progressionNote ?? ''}`.trim();

        // targetDuration: stores targetSeconds for timed holds (Plank, wall-sit, etc.)
        // Maps to ExerciseSetEntity.targetSeconds on mobile via targetDuration JSON field.
        const targetDuration = ex.targetSeconds != null ? Number(ex.targetSeconds) : null;

        await ExerciseSetModel.create({
          data: {
            routineId:          masterRoutine.id,
            exerciseName:       ex.exerciseName ?? ex.exercise ?? 'Unknown',
            exerciseLibraryId:  library?.id ?? null,
            targetSets:         ex.sets ?? (ex._isWarmup ? 2 : 3),
            targetReps:         minReps,
            targetRepsMax:      maxReps !== minReps ? maxReps : null,
            targetDuration,
            restSeconds:        ex.restSeconds ?? (ex._isWarmup ? 30 : 60),
            orderIndex:         ex._saveIdx,  // 0-99 = main, 1000+ = warmup
            rpe:                ex.rpe ?? null,
            progressionNote:    progressionNote || null,
            muscleGroupPrimary: ex.muscleGroupPrimary ?? null,
          },
        });
      }
    }

    // Create Plan instance last — only after all template records are safe.
    const plan = await WorkoutPlanModel.create({
      data: {
        userId,
        masterTemplateId: masterTemplate.id,
        name: templateName,
        difficulty: payload.fitnessLevel as DifficultyLevel,
        isAIGenerated: true,
        isActive: true,
        status: 'ACTIVE',
        startDate: getStartOfToday(),
        numWeeks: 4,
      },
    });

    // Deactivate old plans inside same transaction — atomic transition.
    await tx.workoutPlan.updateMany({
      where: { userId, isActive: true, id: { not: plan.id } },
      data: { isActive: false },
    });

    return plan;
  }, { timeout: 30_000 });
}

// Maps food name keywords to culinary units so countable foods aren't stored as grams.
// The AI always outputs "g" for everything; this corrects it at save time.
const COUNTABLE_UNIT_KEYWORDS: Array<{ keywords: string[]; unit: string }> = [
  { keywords: ['egg'],                              unit: 'pcs'   },
  { keywords: ['banana'],                           unit: 'pcs'   },
  { keywords: ['apple'],                            unit: 'pcs'   },
  { keywords: ['orange'],                           unit: 'pcs'   },
  { keywords: ['pear'],                             unit: 'pcs'   },
  { keywords: ['rice cake'],                        unit: 'pcs'   },
  { keywords: ['bread', 'toast'],                   unit: 'slice' },
  { keywords: ['milk', 'juice', 'oat milk', 'soy milk', 'almond milk'], unit: 'ml' },
];

function resolveIngredientUnit(name: string, aiUnit: string | undefined): string {
  if (!name) return aiUnit ?? 'g';
  const lower = name.toLowerCase();
  for (const { keywords, unit } of COUNTABLE_UNIT_KEYWORDS) {
    if (keywords.some(k => lower.includes(k))) return unit;
  }
  return aiUnit ?? 'g';
}

async function saveDietPlan(prisma: any, userId: string, aiResult: any, payload: AiJobPayload, isFallback = false) {
  const { DietProcessorService } = await import('../modules/diets/diet-processor.service');
  const dietProcessor = new DietProcessorService(prisma);

  const meta = aiResult?.planMeta ?? aiResult?.plan_meta ?? aiResult?.meta;
  if (!meta) {
    throw new Error('saveDietPlan: AI result has no planMeta — cannot save diet plan.');
  }

  // GHOST CALORIES FIX: Recalculate planMeta from actual ingredient sums.
  // The AI may hallucinate a planMeta.dailyCalories that doesn't match what the
  // ingredients actually provide. We correct the meta BEFORE saving to the DB.
  const rawDaysForRecalc = aiResult.days
    ? (Array.isArray(aiResult.days) ? aiResult.days : Object.values(aiResult.days))
    : [];
  let recalcTotalCal = 0;
  let recalcTotalPro = 0;
  let recalcTotalCarb = 0;
  let recalcTotalFat = 0;
  let recalcDayCount = 0;
  for (const day of rawDaysForRecalc) {
    for (const meal of (day.meals || [])) {
      const totals = dietProcessor.calculateMealTotals(meal.ingredients || []);
      recalcTotalCal  += totals.totalCalories;
      recalcTotalPro  += totals.protein;
      recalcTotalCarb += totals.carbs;
      recalcTotalFat  += totals.fats;
    }
    recalcDayCount++;
  }
  if (recalcDayCount > 0 && recalcTotalCal > 0) {
    const perDay = (v: number) => Math.round(v / recalcDayCount);
    const correctedCal  = perDay(recalcTotalCal);
    const correctedPro  = perDay(recalcTotalPro);
    const correctedCarb = perDay(recalcTotalCarb);
    const correctedFat  = perDay(recalcTotalFat);
    if (Math.abs(correctedCal - (meta.dailyCalories ?? 0)) > 50) {
      logger.warn(`[AI_DIET] Ghost Calories detected. AI claimed ${meta.dailyCalories} kcal/day, ingredients sum to ${correctedCal}. Correcting.`, { userId });
      logger.info(`[AI_METRICS]`, { userId, type: 'DIET', ghost_calories_corrected: true, ai_claimed: meta.dailyCalories, corrected_to: correctedCal });
    }
    meta.dailyCalories        = correctedCal;
    meta.macros               = meta.macros ?? {};
    meta.macros.protein       = correctedPro;
    meta.macros.carbs         = correctedCarb;
    meta.macros.fats          = correctedFat;
  }

  // Build disliked foods list BEFORE transaction (pure computation, no DB).
  // Use payload-level allergies/dislikedFoods only — medicalConditions contains
  // health diagnoses (e.g. "hypertension"), NOT food names.
  const payloadAllergies: string[] = (payload as any).allergies || [];
  const payloadDislikes: string[] = (payload as any).dislikedFoods || [];
  const dislikedFoods = [...payloadAllergies, ...payloadDislikes]
    .map((s: string) => s.toLowerCase().trim())
    .filter((s: string) => s.length > 2);

  // 4-DAY FOUNDATIONAL MIRROR PATTERN:
  // A(0) → MONDAY, THURSDAY  |  B(1) → TUESDAY, FRIDAY
  // C(2) → WEDNESDAY, SATURDAY  |  D(3) → SUNDAY (standalone)
  const rawDays = aiResult.days
    ? (Array.isArray(aiResult.days) ? aiResult.days : Object.values(aiResult.days))
    : [];
  const sourceDays: any[] = [];
  if (rawDays.length === 4) {
    sourceDays.push({ ...rawDays[0], dayOfWeek: 'MONDAY' });
    sourceDays.push({ ...rawDays[1], dayOfWeek: 'TUESDAY' });
    sourceDays.push({ ...rawDays[2], dayOfWeek: 'WEDNESDAY' });
    sourceDays.push({ ...rawDays[0], dayOfWeek: 'THURSDAY' });
    sourceDays.push({ ...rawDays[1], dayOfWeek: 'FRIDAY' });
    sourceDays.push({ ...rawDays[2], dayOfWeek: 'SATURDAY' });
    sourceDays.push({ ...rawDays[3], dayOfWeek: 'SUNDAY' });
  } else if (rawDays.length === 3) {
    sourceDays.push({ ...rawDays[0], dayOfWeek: 'MONDAY' });
    sourceDays.push({ ...rawDays[1], dayOfWeek: 'TUESDAY' });
    sourceDays.push({ ...rawDays[2], dayOfWeek: 'WEDNESDAY' });
    sourceDays.push({ ...rawDays[0], dayOfWeek: 'THURSDAY' });
    sourceDays.push({ ...rawDays[1], dayOfWeek: 'FRIDAY' });
    sourceDays.push({ ...rawDays[2], dayOfWeek: 'SATURDAY' });
    sourceDays.push({ ...rawDays[0], dayOfWeek: 'SUNDAY' });
  } else {
    const enumDays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    rawDays.forEach((rd: any, i: number) => sourceDays.push({ ...rd, dayOfWeek: enumDays[i % 7] }));
  }
  logger.info(`[AI_DIET_SAVE] Foundational pattern: ${rawDays.length} source days expanded to ${sourceDays.length} days (mirrored week).`);

  const imageMap: Record<string, string> = {
    BREAKFAST: 'https://images.unsplash.com/photo-1484723088684-0498b5840673?w=400&h=400&fit=crop',
    LUNCH:     'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&h=400&fit=crop',
    DINNER:    'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=400&h=400&fit=crop',
    SNACK:     'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?w=400&h=400&fit=crop',
    'SNACK 1': 'https://images.unsplash.com/photo-1505576399279-565b52d4ac71?w=400&h=400&fit=crop',
    'SNACK 2': 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=400&h=400&fit=crop',
  };

  // ── ALL WRITES IN A SINGLE TRANSACTION ───────────────────────────────────────
  // If any write fails, ALL writes roll back — no orphaned master templates.
  await prisma.$transaction(async (tx: any) => {
    const txAny = tx as any;
    const MasterDietModel  = txAny.MasterDietTemplate   || txAny.masterDietTemplate;
    const MasterMealModel  = txAny.MasterMeal           || txAny.masterMeal;
    const IngredientModel  = txAny.MasterMealIngredient || txAny.masterMealIngredient;

    if (!MasterDietModel || !MasterMealModel || !IngredientModel) {
      throw new Error('CRITICAL: One or more required Diet models are missing from Prisma client accessors.');
    }

    const masterDiet = await MasterDietModel.create({
      data: {
        name: `AI Diet Plan — ${payload.goals.substring(0, 40)}`,
        isAIGenerated: true,
        targetCalories: meta.dailyCalories ?? 2000,
        targetProtein: meta.macros?.protein ?? 150,
        targetCarbs: meta.macros?.carbs ?? 200,
        targetFats: meta.macros?.fats ?? 65,
        targetWater: (meta.hydrationTargetMl ?? 2500) / 1000,
      },
    });
    logger.info(`[AI_DIET_SAVE] Master Diet Template created: ${masterDiet.id}`);

    for (let dayIndex = 0; dayIndex < sourceDays.length; dayIndex++) {
      const dayData = sourceDays[dayIndex];
      if (!dayData || !dayData.meals) continue;
      logger.info(`[AI_DIET_SAVE] Processing Day ${dayIndex + 1}: ${dayData.dayOfWeek}`);

      // P1-D: compute this day's total macros from ingredients so each meal
      // row carries the correct daily target for its rotation day.
      let dayTotCal = 0, dayTotPro = 0, dayTotCarb = 0, dayTotFat = 0;
      for (const md of dayData.meals) {
        const t = dietProcessor.calculateMealTotals(md.ingredients || []);
        dayTotCal  += t.totalCalories;
        dayTotPro  += t.protein;
        dayTotCarb += t.carbs;
        dayTotFat  += t.fats;
      }

      for (let mealIndex = 0; mealIndex < dayData.meals.length; mealIndex++) {
        const mealData = dayData.meals[mealIndex];
        const mealType = String(mealData.type || 'MEAL').toUpperCase();

        const MasterMealResult = await MasterMealModel.create({
          data: {
            templateId: masterDiet.id,
            name: mealType,
            timeOfDay: mealData.time,
            dayOfWeek: dayData.dayOfWeek ? String(dayData.dayOfWeek).toUpperCase() : null,
            // mealIndex = position within the day (0=first meal, 1=second, …).
            // Previously stored dayIndex (0-6) here, which caused inferMealType()
            // step 3 to map all meals on day 1 (TUESDAY) to LUNCH regardless of type.
            orderIndex: mealIndex,
            instructions: `${mealData.name}\n\n${mealData.instructions}`,
            mediaUrl: imageMap[mealType] || (mealType.includes('SNACK') ? imageMap.SNACK : imageMap.LUNCH),
            dayTargetCalories: Math.round(dayTotCal)  || null,
            dayTargetProtein:  Math.round(dayTotPro)  || null,
            dayTargetCarbs:    Math.round(dayTotCarb) || null,
            dayTargetFats:     Math.round(dayTotFat)  || null,
          },
        } as any);
        logger.info(`[AI_DIET_SAVE]   Meal: ${mealType} — ${mealData.name} (${mealData.ingredients?.length ?? 0} ingredients)`);

        for (const ing of (mealData.ingredients || [])) {
          // Fallback plans only have 2 ingredients per meal — skipping any one of them
          // would gut the calorie total and cause the ghost-calories fix to drag the
          // plan's targetCalories down, breaking the nutritional guarantee.
          if (!isFallback && dislikedFoods.some((d: string) => d && ing.name.toLowerCase().includes(d))) {
            logger.info(`[AI_DIET_SAVE] Skipping disliked ingredient: ${ing.name}`);
            continue;
          }
          await IngredientModel.create({
            data: {
              mealId: MasterMealResult.id,
              name: ing.name || 'Unknown Item',
              amount: String(ing.amount ?? '1'),
              unit: resolveIngredientUnit(ing.name, ing.unit),
              calories: Math.round(Number(ing.calories ?? 0)),
              protein: Number(ing.protein ?? 0),
              carbs: Number(ing.carbs ?? 0),
              fats: Number(ing.fats ?? 0),
            } as any,
          });
        }
      }
    }

    // Create Plan instance last — only after all template records are confirmed safe.
    const dietPlan = await tx.dietPlan.create({
      data: {
        userId,
        masterTemplateId: masterDiet.id,
        name: masterDiet.name,
        isAIGenerated: true,
        isActive: true,
        status: 'ACTIVE',
        isPublished: true,
        startDate: getStartOfToday(),
        numWeeks: 4,
        targetCalories: Math.round(meta.dailyCalories || 2000),
        targetProtein: Math.round(meta.macros?.protein || 150),
        targetCarbs: Math.round(meta.macros?.carbs || 200),
        targetFats: Math.round(meta.macros?.fats || 65),
        targetWater: parseFloat(((meta.hydrationTargetMl || 2500) / 1000).toFixed(1)),
      },
    });

    // Deactivate old plans inside same transaction — atomic transition.
    await tx.dietPlan.updateMany({
      where: { userId, id: { not: dietPlan.id }, isActive: true },
      data: { isActive: false, status: 'ARCHIVED' },
    });

    logger.info('[AI_DIET_SAVE] Plan fully persisted inside transaction.');
    return dietPlan;
  }, { timeout: 30_000 });
}

// ─── AI Safety Validators ─────────────────────────────────────────────────────
//
// These return a list of error strings (never throw directly) so the repair loop
// can collect ALL problems at once and send them back to the AI in one shot.
// The caller decides whether to throw or repair.

const MAX_SETS_PER_DAY   = 35;
const MAX_WORKOUT_DAYS   = 28;
const MIN_SETS_PER_EX    = 2;
const MAX_SETS_PER_EX    = 6;
const MIN_REPS           = 3;
const MAX_REPS           = 30;
const MACRO_TOLERANCE    = 0.05; // ±5%
const DAY_TOTAL_TOLERANCE = 0.15; // ±15% — day meal sum vs daily target

/**
 * Dynamic per-meal calorie bounds derived entirely from the member's daily
 * calorie target and number of meals chosen. No magic numbers.
 *
 * avgPerMeal = targetCal ÷ mealsPerDay
 * floor = avg × 0.60  (snacks/lighter meals can be 40% below average)
 * cap   = avg × 1.50  (main meals can be 50% above average)
 *
 * Examples:
 *   2300 kcal, 2 meals → avg 1150 → floor 690, cap 1725
 *   2300 kcal, 3 meals → avg  767 → floor 460, cap 1150
 *   2300 kcal, 5 meals → avg  460 → floor 276, cap  690
 */
function mealCalorieBounds(targetCal: number, mealsPerDay: number): { min: number; max: number } {
  const avg = targetCal / Math.max(1, mealsPerDay);
  return {
    min: Math.max(150, Math.round(avg * 0.60)),  // absolute floor 150 kcal
    max: Math.min(2000, Math.round(avg * 1.50)), // absolute cap 2000 kcal
  };
}

/**
 * Dynamic per-meal protein cap derived from daily protein target and meal count.
 * Allows one meal to carry up to 150% of the average protein allocation.
 * Clamped to [35, 130] g.
 */
function maxMealProtein(dailyProteinG: number, mealsPerDay: number): number {
  const avg = dailyProteinG / Math.max(1, mealsPerDay);
  return Math.min(130, Math.max(35, Math.round(avg * 1.5)));
}

function collectWorkoutErrors(plan: any, requestedDays = 0): string[] {
  const errors: string[] = [];
  if (!plan || typeof plan !== 'object') { errors.push('Plan is not an object'); return errors; }

  const days: any[] = plan.days ?? [];
  if (days.length > MAX_WORKOUT_DAYS) errors.push(`Too many days: ${days.length} (max ${MAX_WORKOUT_DAYS})`);

  let hasRestDay = false;
  let trainingDays = 0;

  // Collect all exercise names across training days to check for repetition
  const exerciseNamesByDay: Map<string, Set<string>> = new Map();

  for (const day of days) {
    if (day.isRestDay) { hasRestDay = true; continue; }
    trainingDays++;

    const exercises: any[] = [...(day.warmup ?? []), ...(day.mainWork ?? [])];
    const totalSets = exercises.reduce((sum, ex) => sum + (Number(ex.sets) || 0), 0);
    if (totalSets > MAX_SETS_PER_DAY) {
      errors.push(`Day ${day.dayOfWeek}: set volume too high (${totalSets}, max ${MAX_SETS_PER_DAY})`);
    }

    const dayExNames = new Set<string>(
      (day.mainWork ?? []).map((ex: any) => (ex.exerciseName ?? '').toLowerCase())
    );
    if (day.dayOfWeek) exerciseNamesByDay.set(day.dayOfWeek, dayExNames);

    for (const ex of day.mainWork ?? []) {
      const sets    = Number(ex.sets ?? 0);
      const minReps = Number(ex.minReps ?? ex.reps ?? 0);
      const maxReps = Number(ex.maxReps ?? ex.reps ?? 0);

      if (sets < MIN_SETS_PER_EX || sets > MAX_SETS_PER_EX) {
        errors.push(`Exercise "${ex.exerciseName}" on ${day.dayOfWeek}: sets=${sets} must be ${MIN_SETS_PER_EX}–${MAX_SETS_PER_EX}`);
      }
      // Timed exercises (plank, wall-sit, etc.) use minReps=maxReps=1 as sentinel
      const isTimedHold = minReps === 1 && maxReps === 1 && ex.targetSeconds != null;
      if (!isTimedHold && (minReps < MIN_REPS || maxReps > MAX_REPS)) {
        errors.push(`Exercise "${ex.exerciseName}" on ${day.dayOfWeek}: reps ${minReps}–${maxReps} must be ${MIN_REPS}–${MAX_REPS}`);
      }
    }
  }

  if (trainingDays > 6) errors.push(`Too many training days: ${trainingDays} (max 6)`);
  if (!hasRestDay)      errors.push('No rest day found — at least 1 required');
  // Verify AI generated exactly as many training days as the user requested.
  // A mismatch means the AI ignored the schedule — catch it before saving.
  if (requestedDays > 0 && trainingDays !== requestedDays) {
    errors.push(`Training day count mismatch: AI generated ${trainingDays} training days, user requested ${requestedDays}`);
  }

  // Diversity check: if 2+ training days share >60% of their exercises, the plan is a copy-paste.
  // A professional split (PPL, Upper/Lower, Bro) must have categorically different exercises per day.
  const dayKeys = Array.from(exerciseNamesByDay.keys());
  for (let a = 0; a < dayKeys.length; a++) {
    for (let b = a + 1; b < dayKeys.length; b++) {
      const setA = exerciseNamesByDay.get(dayKeys[a])!;
      const setB = exerciseNamesByDay.get(dayKeys[b])!;
      if (setA.size === 0 || setB.size === 0) continue;
      const shared = [...setA].filter(n => setB.has(n)).length;
      const similarity = shared / Math.min(setA.size, setB.size);
      if (similarity > 0.6) {
        errors.push(
          `Days ${dayKeys[a]} and ${dayKeys[b]} share ${Math.round(similarity * 100)}% of exercises — ` +
          `each training day MUST target a distinct muscle group (e.g. PUSH vs PULL vs LEGS). ` +
          `Do NOT repeat the same exercises across different training days.`
        );
      }
    }
  }

  return errors;
}

function collectDietErrors(plan: any, mealsPerDay = 3, targetCaloriesOverride?: number): string[] {
  const errors: string[] = [];
  if (!plan || typeof plan !== 'object') { errors.push('Plan is not an object'); return errors; }

  const meta = plan.planMeta ?? plan.plan_meta ?? plan.meta;
  if (!meta) { errors.push('Missing planMeta'); return errors; }

  const targetCal = targetCaloriesOverride ?? Number(meta.dailyCalories ?? meta.calories ?? 0);
  if (targetCal < 800 || targetCal > 6000) {
    errors.push(`planMeta.dailyCalories=${targetCal} is out of range (800–6000)`);
  }

  // Macro formula: protein×4 + carbs×4 + fats×9 must equal dailyCalories ±5%
  const dailyProtein = Number(meta.macros?.protein ?? 0);
  const carbs        = Number(meta.macros?.carbs   ?? 0);
  const fats         = Number(meta.macros?.fats    ?? 0);
  const macroCalories = dailyProtein * 4 + carbs * 4 + fats * 9;
  if (targetCal > 0 && Math.abs(macroCalories - targetCal) / targetCal > MACRO_TOLERANCE) {
    errors.push(
      `Macro formula mismatch: protein(${dailyProtein})×4 + carbs(${carbs})×4 + fats(${fats})×9 = ${macroCalories} kcal, ` +
      `but planMeta.dailyCalories=${targetCal} (tolerance ±${MACRO_TOLERANCE * 100}%)`
    );
  }

  const sourceWeek: any[] = plan.days ?? [];
  // Validate day count: must be exactly 4 (the ABCD foundational pattern).
  // Do NOT early-return — collect per-meal errors even if day count is wrong.
  if (sourceWeek.length < 4) {
    errors.push(`Only ${sourceWeek.length} days returned — expected exactly 4 (MONDAY, TUESDAY, WEDNESDAY, SUNDAY)`);
  }
  if (sourceWeek.length > 4) {
    errors.push(`Too many days: ${sourceWeek.length} returned — expected exactly 4`);
  }

  // Per-meal calorie bounds derived from member's actual target and meal count.
  // No magic numbers — scales correctly for 2-meal plans (large meals) and
  // 5-meal plans (small snacks) at any calorie target.
  const { min: mealCalMin, max: mealCalMax } = mealCalorieBounds(targetCal, mealsPerDay);
  const mealProMax = maxMealProtein(dailyProtein > 0 ? dailyProtein : targetCal * 0.30 / 4, mealsPerDay);
  const avgPerMeal = Math.round(targetCal / Math.max(1, mealsPerDay));

  for (const day of sourceWeek) {
    const meals: any[] = day.meals || [];
    if (meals.length === 0) {
      errors.push(`Day ${day.dayOfWeek}: no meals`);
      continue;
    }

    // Day-total check: all meals in this day must sum to within ±15% of target.
    const dayTotal = meals.reduce((s: number, m: any) => s + Number(m.calories ?? 0), 0);
    if (targetCal > 0 && Math.abs(dayTotal - targetCal) / targetCal > DAY_TOTAL_TOLERANCE) {
      errors.push(
        `Day ${day.dayOfWeek} total=${dayTotal} kcal deviates from target ${targetCal} kcal by ` +
        `${Math.round(Math.abs(dayTotal - targetCal))} kcal (max ±${DAY_TOTAL_TOLERANCE * 100}%). ` +
        `With ${mealsPerDay} meals each should average ~${avgPerMeal} kcal.`
      );
    }

    for (const meal of meals) {
      const mealCal = Number(meal.calories ?? 0);
      const mealPro = Number(meal.protein  ?? 0);

      if (mealCal < mealCalMin || mealCal > mealCalMax) {
        errors.push(
          `Day ${day.dayOfWeek} meal "${meal.name ?? meal.type}": calories=${mealCal} must be ` +
          `${mealCalMin}–${mealCalMax} kcal (derived from target ${targetCal} ÷ ${mealsPerDay} meals = ~${avgPerMeal} kcal avg)`
        );
      }
      if (mealPro > mealProMax) {
        errors.push(
          `Day ${day.dayOfWeek} meal "${meal.name ?? meal.type}": protein=${mealPro}g exceeds max ${mealProMax}g per meal`
        );
      }

      const ingredients: any[] = meal.ingredients || meal.items || [];
      if (ingredients.length === 0) {
        errors.push(`Day ${day.dayOfWeek} meal "${meal.name ?? meal.type}": no ingredients`);
      }
    }

    // Ingredient diversity: no ingredient may appear in more than one meal within the same day.
    const seenIngredients = new Map<string, string>(); // normalised name → first meal type
    for (const meal of meals) {
      for (const ing of (meal.ingredients || meal.items || [])) {
        const key = String(ing.name ?? '').toLowerCase().trim();
        if (!key) continue;
        const firstMeal = seenIngredients.get(key);
        if (firstMeal) {
          errors.push(
            `Day ${day.dayOfWeek}: ingredient "${ing.name}" appears in both "${firstMeal}" and ` +
            `"${meal.name ?? meal.type}" — each meal on the same day MUST use different ingredients`
          );
        } else {
          seenIngredients.set(key, meal.name ?? meal.type ?? 'unknown');
        }
      }
    }
  }

  // All-zero ingredient calories = AI skipped per-ingredient macros
  const allIngredients = sourceWeek.flatMap((d: any) =>
    (d.meals || []).flatMap((m: any) => m.ingredients || [])
  );
  const totalIngCal = allIngredients.reduce((s: number, i: any) => s + Number(i.calories ?? 0), 0);
  if (allIngredients.length > 0 && totalIngCal === 0) {
    errors.push('All ingredient calories are 0 — AI did not provide per-ingredient macros');
  }

  return errors;
}

// Thin wrappers used by the main flow — throw on any error so callers can catch.
function validateWorkoutPlan(plan: any, requestedDays: number): void {
  const errors = collectWorkoutErrors(plan, requestedDays);
  if (errors.length > 0) throw new Error(`Workout validation failed:\n${errors.map(e => `  • ${e}`).join('\n')}`);
}

function validateDietPlan(plan: any, mealsPerDay = 3, targetCaloriesOverride?: number): void {
  const errors = collectDietErrors(plan, mealsPerDay, targetCaloriesOverride);
  if (errors.length > 0) throw new Error(`Diet validation failed:\n${errors.map(e => `  • ${e}`).join('\n')}`);
}

// ─── Prompt Builders ──────────────────────────────────────────────────────────

/**
 * Normalises the Dart MuscleGroup enum names (camelCase) that arrive from the
 * mobile into human-readable muscle labels used in the AI prompt.
 */
function normaliseMuscleNames(rawNames: string[]): string[] {
  const map: Record<string, string> = {
    chest:       'Chest',
    back:        'Back (Lats, Rhomboids)',
    shoulders:   'Shoulders (Deltoids)',
    biceps:      'Biceps',
    triceps:     'Triceps',
    forearms:    'Forearms',
    abs:         'Abdominals',
    obliques:    'Obliques',
    quads:       'Quadriceps',
    hamstrings:  'Hamstrings',
    glutes:      'Glutes',
    calves:      'Calves',
    traps:       'Trapezius',
    neck:        'Neck',
    adductors:   'Adductors',
    fullBody:    'Full Body',
    fullbody:    'Full Body',
    cardio:      'Cardiovascular',
    lats:        'Lats',
    core:        'Core',
  };
  return rawNames.map(n => map[n] ?? map[n.toLowerCase()] ?? n);
}

/**
 * Groups user-selected muscles into Push / Pull / Legs sessions automatically.
 * Used when the member picked specific muscles (custom split) so the AI knows
 * which session each muscle belongs to rather than lumping everything into Full Body.
 *
 *  PUSH muscles → Chest, Shoulders, Triceps, Anterior Deltoids
 *  PULL muscles → Back, Lats, Biceps, Traps, Rear Deltoids
 *  LEGS muscles → Quads, Hamstrings, Glutes, Calves, Adductors, Abs, Core
 */
function groupMusclesIntoSessions(
  selectedMuscles: string[],   // normalised names
  trainingDays: string[],
): { day: string; session: string; muscles: string }[] {
  const pushSet  = new Set(['Chest','Shoulders (Deltoids)','Triceps','Front Deltoids']);
  const pullSet  = new Set(['Back (Lats, Rhomboids)','Lats','Biceps','Trapezius','Rear Deltoids']);
  const legsSet  = new Set(['Quadriceps','Hamstrings','Glutes','Calves','Adductors','Abdominals','Obliques','Core']);

  const pushMuscles  = selectedMuscles.filter(m => pushSet.has(m));
  const pullMuscles  = selectedMuscles.filter(m => pullSet.has(m));
  const legsMuscles  = selectedMuscles.filter(m => legsSet.has(m));
  const otherMuscles = selectedMuscles.filter(m => !pushSet.has(m) && !pullSet.has(m) && !legsSet.has(m));

  // Build session slots — only include a session if the member selected muscles for it
  const sessions: { session: string; muscles: string }[] = [];
  if (pushMuscles.length > 0)  sessions.push({ session: 'PUSH',  muscles: pushMuscles.join(', ') });
  if (pullMuscles.length > 0)  sessions.push({ session: 'PULL',  muscles: pullMuscles.join(', ') });
  if (legsMuscles.length > 0)  sessions.push({ session: 'LEGS',  muscles: legsMuscles.join(', ') });
  // Muscles that don't fit a canonical session get their own "FOCUS" day
  if (otherMuscles.length > 0) sessions.push({ session: 'FOCUS', muscles: otherMuscles.join(', ') });

  // Single-session guard: when all selected muscles belong to one category
  // (e.g. Chest + Triceps + Shoulders = all PUSH), every training day would get the
  // identical session label and muscle list → AI copy-pastes → diversity validator fires.
  // Fix: split the muscles across days so each day gets a distinct subset.
  if (sessions.length === 1) {
    const { session, muscles } = sessions[0];
    const muscleList = muscles.split(', ');
    // Distribute muscles across days. Each day gets a unique label (A, B, C…) so the AI
    // is explicitly prompted to vary exercises. When muscles < days, later days cycle back
    // through muscles but keep unique labels — the distinct label is enough for the AI
    // to understand it must choose different exercises.
    return trainingDays.map((day, i) => ({
      day,
      session: `${session} ${String.fromCharCode(65 + (i % 26))}`,
      muscles: muscleList[i % muscleList.length],
    }));
  }

  // Cycle sessions across available training days
  return trainingDays.map((day, i) => ({
    day,
    ...sessions[i % sessions.length],
  }));
}

/**
 * Expands a training split name + preferred training days into an explicit
 * per-day session schedule that is injected directly into the AI prompt.
 *
 * When the member chose specific muscles (custom split), their selection
 * is used to determine which session (PUSH/PULL/LEGS) each day gets.
 * This ensures the muscle body selector in the app directly controls
 * what exercises the AI generates for each day.
 */
function expandSplitSchedule(
  split: string,
  trainingDays: string[],       // e.g. ['MONDAY','WEDNESDAY','FRIDAY']
  targetMuscles?: string[],     // raw muscle names from mobile (may be empty)
): { day: string; session: string; muscles: string }[] {
  const s = (split || 'fullbody').toLowerCase().replace(/[^a-z]/g, '');

  // If the member made an explicit muscle selection, respect it over the split label
  if (targetMuscles && targetMuscles.length > 0) {
    const normalised = normaliseMuscleNames(targetMuscles);
    return groupMusclesIntoSessions(normalised, trainingDays);
  }

  // Canonical muscle groupings for each split pattern (no custom selection)
  const pplPattern = [
    { session: 'PUSH', muscles: 'Chest, Front Deltoids, Lateral Deltoids, Triceps' },
    { session: 'PULL', muscles: 'Lats, Rhomboids, Rear Deltoids, Biceps, Trapezius' },
    { session: 'LEGS', muscles: 'Quadriceps, Hamstrings, Glutes, Calves, Core' },
  ];
  const upperLowerPattern = [
    { session: 'UPPER', muscles: 'Chest, Back, Shoulders, Biceps, Triceps' },
    { session: 'LOWER', muscles: 'Quadriceps, Hamstrings, Glutes, Calves, Core' },
  ];
  const broSplitPattern = [
    { session: 'CHEST DAY',     muscles: 'Chest, Front Deltoids, Triceps' },
    { session: 'BACK DAY',      muscles: 'Lats, Rhomboids, Rear Deltoids, Biceps' },
    { session: 'SHOULDER DAY',  muscles: 'Front/Lateral/Rear Deltoids, Trapezius' },
    { session: 'ARMS DAY',      muscles: 'Biceps, Triceps, Forearms' },
    { session: 'LEGS DAY',      muscles: 'Quadriceps, Hamstrings, Glutes, Calves' },
  ];

  let pattern: { session: string; muscles: string }[];
  if (s.includes('push') || s.includes('ppl') || s.includes('pullleg')) {
    pattern = pplPattern;
  } else if (s.includes('upper') || s.includes('lower')) {
    pattern = upperLowerPattern;
  } else if (s.includes('bro')) {
    pattern = broSplitPattern;
  } else {
    // fullBody: each training day works all muscle groups but with a different
    // exercise selection — labelled uniquely so the AI doesn't copy-paste
    return trainingDays.map((day, i) => ({
      day,
      session: `FULL BODY ${i + 1}`,
      muscles: 'Chest, Back, Shoulders, Quadriceps, Hamstrings, Glutes, Core — choose DIFFERENT exercises than the other Full Body days',
    }));
  }

  return trainingDays.map((day, i) => ({
    day,
    ...pattern[i % pattern.length],
  }));
}

function buildWorkoutSystemPrompt(): string {
  return `You are an elite strength and conditioning coach (NSCA-CSCS, NASM-CPT).
You design evidence-based, periodised training programs.

🏋️ CRITICAL DIRECTIVES — READ CAREFULLY:
1. EQUIPMENT: Use ONLY exercises achievable with the listed 'available_equipment'. Do NOT assume unlisted machines.
2. UNIQUENESS: Each training day MUST have a completely different exercise list targeting its assigned muscle group. NEVER repeat the same exercise on two different training days.
3. SPLIT COMPLIANCE: Follow the per-day session assignments exactly as specified in the user prompt. A PUSH day contains ONLY push-pattern exercises (Chest/Shoulders/Triceps). A PULL day contains ONLY pull-pattern exercises (Back/Biceps). A LEGS day contains ONLY lower-body exercises.
4. 7-DAY CALENDAR: Include EXACTLY 7 items in the 'days' array — one per day of the week.
5. REST DAYS: Non-training days MUST use "sessionType": "REST" and "isRestDay": true with empty warmup and mainWork arrays.
6. EXERCISE SELECTION: Choose 4–6 main work exercises per training day. Each exercise must be different from every other training day. Compound movements first, isolation last.
7. PROGRESSION: Each exercise must include a specific 'progressionNote' (e.g. "Add 2.5 kg when you hit 12 reps for 3 sets").
8. REPS: INTEGERS only. Use separate 'minReps' and 'maxReps' fields. Never strings like "8-12".
9. OUTPUT: Pure JSON only. No markdown, no prose.

OUTPUT SCHEMA:
{
  "planMeta": { "phase": "string", "primaryGoal": "string", "coachNote": "string" },
  "days": [
    {
      "dayOfWeek": "MONDAY | TUESDAY | WEDNESDAY | THURSDAY | FRIDAY | SATURDAY | SUNDAY",
      "dayName": "string  (e.g. 'Push Day — Chest & Shoulders')",
      "sessionType": "PUSH | PULL | LEGS | UPPER | LOWER | FULL BODY | REST",
      "targetMuscles": ["Chest", "Front Deltoids", "Triceps"],
      "isRestDay": false,
      "estimatedDurationMinutes": 60,
      "warmup": [{ "exerciseName": "string", "sets": 2, "minReps": 10, "maxReps": 15, "restSeconds": 30 }],
      "mainWork": [
        {
          "exerciseName": "string",
          "sets": 4,
          "minReps": 8,
          "maxReps": 12,
          "rpe": 7,
          "restSeconds": 90,
          "progressionNote": "string",
          "muscleGroupPrimary": "string"
        }
      ]
    }
  ]
}
`;
}

function buildDietSystemPrompt(_mealsPerDay: number, mealNames: string[]): string {
  const namesStr = mealNames.join(', ');
  return `You are a Registered Dietitian (RD).
Generate EXACTLY 4 unique foundational diet days. These will be mirrored to fill a full week:
  MONDAY=THURSDAY, TUESDAY=FRIDAY, WEDNESDAY=SATURDAY, SUNDAY=standalone.

🥗 RULES:
1. Every day MUST include exactly these meal types in order: [${namesStr}].
2. Include EXACTLY 4 items in the 'days' array with dayOfWeek: MONDAY, TUESDAY, WEDNESDAY, SUNDAY.
3. Per-meal macros (calories, protein, carbs, fats) MUST sum to match planMeta values across the day.
4. Per-ingredient macros MUST be accurate integers. Sum of ingredient calories MUST equal the meal's calories.
5. PURE JSON output only. No markdown, no prose.
6. All numeric values MUST be integers (no decimals).
7. ALLERGIES: Severe items are absolutely excluded — never appear even as trace amounts.
8. instructions: Max 20 words. Action verbs only (e.g. "Grill chicken, steam rice, mix with olive oil").
9. ingredient names: Use clear, concise ingredient names (e.g. "Chicken Breast", "Oats", "Olive Oil"). No cooking methods in ingredient names.
10. INGREDIENT DIVERSITY (CRITICAL): Within a single day, NO ingredient may appear in more than one meal. Breakfast, Lunch, Dinner and Snacks MUST each use completely different ingredients. Never repeat an ingredient across meals on the same day.
11. UNITS: Use realistic culinary units — "pcs" for countable foods (Eggs, Banana, Apple, Orange), "slice" for bread/toast, "ml" for liquids (milk, juice), "g" for bulk solids. Never use grams for countable whole foods.

OUTPUT SCHEMA:
{
  "planMeta": { "dailyCalories": 2000, "macros": { "protein": 150, "carbs": 200, "fats": 65 }, "hydrationTargetMl": 2500 },
  "days": [
    {
      "dayOfWeek": "MONDAY",
      "isTrainingDay": true,
      "meals": [
        {
          "type": "one of: ${namesStr}",
          "name": "Recipe Name",
          "time": "08:00",
          "calories": 500,
          "protein": 40,
          "carbs": 50,
          "fats": 15,
          "ingredients": [
            { "name": "Oats", "canonicalName": "oats_rolled", "amount": 80, "unit": "g", "calories": 300, "protein": 10, "carbs": 54, "fats": 6 }
          ],
          "instructions": "Boil oats 5 min, top with berries and honey."
        }
      ]
    }
  ]
}
`;
}

/**
 * Maps meal count (2-5) to official naming convention.
 */
function getMealNameSet(count: number): string[] {
  switch (count) {
    case 2:  return ['BREAKFAST', 'DINNER'];
    case 3:  return ['BREAKFAST', 'LUNCH', 'DINNER'];
    case 4:  return ['BREAKFAST', 'LUNCH', 'SNACK', 'DINNER'];
    case 5:  return ['BREAKFAST', 'SNACK 1', 'LUNCH', 'SNACK 2', 'DINNER'];
    default: return Array.from({ length: Math.max(1, count) }, (_, i) => `MEAL ${i + 1}`);
  }
}

function buildUserPrompt(payload: AiJobPayload, type: string): string {
  const m = payload.userMetrics;
  if (type === 'WORKOUT') {
    const restrictions = payload.restrictions?.join(', ') || m?.medicalConditions || 'None';

    const allDays = ['MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY','SUNDAY'];
    const trainingDayNames: string[] = payload.preferred_days && payload.preferred_days.length > 0
      ? payload.preferred_days.map((d: number) => allDays[d]).filter(Boolean)
      : ['MONDAY', 'WEDNESDAY', 'FRIDAY']; // sensible default

    const schedule = expandSplitSchedule(
      payload.trainingSplit || 'fullbody',
      trainingDayNames,
      payload.target_muscles,   // member's visual muscle selection from the app
    );
    const restDays = allDays.filter(d => !trainingDayNames.includes(d));

    const scheduleLines = [
      ...schedule.map(s => `  ${s.day}: ${s.session} — target muscles: ${s.muscles}`),
      ...restDays.map(d => `  ${d}: REST — isRestDay: true, empty warmup and mainWork`),
    ].join('\n');

    return `Generate Flagship 7-Day Workout Cycle Blueprint (MONDAY to SUNDAY):
- Goal: ${payload.goals}
- Training Split: ${payload.trainingSplit || 'Full Body'}
- Level: ${payload.fitnessLevel}
- Equipment: ${payload.availableEquipment?.join(', ') || 'Standard Gym'}
- Metrics: ${m?.weightKg != null ? `${m.weightKg}kg` : 'weight unknown'}, ${m?.heightCm != null ? `${m.heightCm}cm` : 'height unknown'}, age ${m?.age ?? 'unknown'}, gender ${m?.gender ?? 'unknown'}
- Additional Target Muscles: ${payload.target_muscles?.join(', ') || 'per split assignment'}
- Injuries/Restrictions: ${restrictions}

MANDATORY PER-DAY SCHEDULE — follow exactly, no deviations:
${scheduleLines}

CRITICAL: Each training day listed above has a distinct session type and distinct target muscles.
You MUST choose a completely different set of exercises for each training day.
Do NOT use the same exercise on more than one day.`;
  }

  // Format meal times for the prompt
  const mealTimesStr = payload.mealTimes
    ? Object.entries(payload.mealTimes)
        .filter(([, v]) => v)
        .map(([k, v]) => `${k.replace('_', ' ')}: ${v}`)
        .join(', ')
    : null;

  // Format allergies — use structured (with severity) when available, else flat list
  const allergiesStr = payload.allergiesStructured && payload.allergiesStructured.length > 0
    ? payload.allergiesStructured
        .map(a => `${a.name || a.type} (${a.severity})`)
        .join(', ')
    : payload.allergies?.join(', ') || 'None';

  // Compute per-meal calorie budget so the prompt is explicit — AI must not
  // guess portion sizes. Bounds mirror the validator so the AI targets the
  // middle of the valid range, minimising repair-loop triggers.
  const mealsPerDay     = payload.mealsPerDay || 3;
  const dailyTarget     = payload.targetCalories || 2000;
  const { min: mealMin, max: mealMax } = mealCalorieBounds(dailyTarget, mealsPerDay);
  const avgPerMeal      = Math.round(dailyTarget / mealsPerDay);
  const mealBudgetLine  = `- Per-meal calorie budget: ${mealMin}–${mealMax} kcal each (avg ~${avgPerMeal} kcal). ALL meals in a day MUST sum to exactly ${dailyTarget} kcal ±5%. This is non-negotiable.`;

  return `Generate Flagship 4-Day Foundational Diet Blueprint:
- IMPORTANT: You are generating exactly 4 UNIQUE days (MONDAY, TUESDAY, WEDNESDAY, SUNDAY). These will be mirrored to fill the week: MONDAY=THURSDAY, TUESDAY=FRIDAY, WEDNESDAY=SATURDAY, SUNDAY=standalone. Focus on nutritional diversity across these 4 days.
- Goal: ${payload.goals}
- Dietary Preference: ${payload.dietaryStyle || 'Balanced'}
- Max Prep Time: ${payload.maxPrepMinutes ? payload.maxPrepMinutes + ' min per meal' : 'flexible'}
- Avoid (Dislikes): ${payload.dislikedFoods?.join(', ') || 'None'}
- Allergies/Restrictions: ${allergiesStr}
- Meals/Day: ${mealsPerDay}${mealTimesStr ? `\n- Meal Times: ${mealTimesStr}` : ''}
${payload.targetCalories ? `- Daily calorie target: ${dailyTarget} kcal` : ''}${payload.targetProteinG ? `\n- Daily protein target: ${payload.targetProteinG}g` : ''}
${mealBudgetLine}`;
}

async function processPushNotification(job: Job<PushNotificationPayload>) {
  const { default: prisma } = await import('./prisma');
  for (const userId of job.data.userIds) {
    await prisma.notification.create({
      data: {
        userId,
        type: NotificationType.MOTIVATIONAL,
        channel: NotificationChannel.PUSH,
        title: job.data.title,
        body: job.data.body,
        data: (job.data.data ?? undefined) as any,
        isSent: false,
      },
    });
  }
  // Notification records are created with isSent=false.
  // A separate dispatcher service (FCM/APNs) reads and delivers them.
  logger.info(`[PUSH] ${job.data.userIds.length} notification record(s) created (isSent=false) — awaiting dispatcher.`, {
    userIds: job.data.userIds,
    title: job.data.title,
  });
  return { notified: job.data.userIds.length };
}

export { connection as redisConnection };

/**
 * Returns Monday of the current UTC week at 00:00:00 UTC.
 *
 * Plans anchor to this week's Monday so the 28-day projection window always
 * starts on Monday. Mobile `_loadMealsForDay(dayIndex)` maps dayIndex 0-6 to
 * Monday-Sunday of the current week — if the plan's startDate is any other day
 * (e.g., tomorrow mid-week), getDayPlan(today) would return null and the UI
 * shows "0/0 Logged" even though meals exist.
 *
 * Anchoring to Monday ensures plan.startDate ≡ anchorMonday on both backend
 * (getActiveDietPlan projection) and mobile (DietPlanMapper.planStartDate).
 */
function getStartOfToday(): Date {
  const now = new Date();
  const dayOfWeek = now.getUTCDay(); // 0=Sun, 1=Mon, ..., 6=Sat
  const daysToSubtract = (dayOfWeek - 1 + 7) % 7; // days since last Monday
  const monday = new Date(now);
  monday.setUTCDate(now.getUTCDate() - daysToSubtract);
  monday.setUTCHours(0, 0, 0, 0);
  return monday;
}

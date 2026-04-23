import { Job } from 'bullmq';
import { DifficultyLevel, DayOfWeek } from '@prisma/client';
import axios from 'axios';
import * as QRCode from 'qrcode';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';
import { decryptField } from '../../lib/db-crypto';
import { ProgressService } from '../../modules/mobile-sync/progress.service';
import { PlatformConfigService } from '../../modules/platform/platform-config.service';
import { pushNotificationQueue } from '../queue.config';

const ANTHROPIC_API_VERSION = '2023-06-01';

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
  targetCalories?: number;
  tdee?: number;
  targetProteinG?: number;
  mealsPerDay?: number;
  mealTimes?: Record<string, string>;
  maxPrepMinutes?: number;
}

const MAX_SETS_PER_DAY = 35;
const MAX_WORKOUT_DAYS = 28;
const MIN_SETS_PER_EX = 2;
const MAX_SETS_PER_EX = 6;
const MIN_REPS = 3;
const MAX_REPS = 30;
const MACRO_TOLERANCE = 0.05;
const DAY_TOTAL_TOLERANCE = 0.15;

export async function processAiJob(job: Job<AiJobPayload>, type: 'WORKOUT' | 'DIET') {
  await job.updateProgress({ progress: 10, message: 'Consulting top-tier coaches...' });

  const aiConfig = await getAiConfig();
  if (!aiConfig) throw new Error('AI is disabled on this platform');

  await job.updateProgress({ progress: 20, message: 'Building your metabolic profile...' });
  logger.info(`[AI_${type}] Step 2/5: Consulting Intelligence Models...`, { userId: job.data.userId, jobId: job.id, type });
  
  const startAi = Date.now();
  const sanitizedPayload = { ...job.data };
  if (type === 'WORKOUT') {
    delete (sanitizedPayload as any).dietaryStyle;
    delete (sanitizedPayload as any).allergies;
  } else {
    delete (sanitizedPayload as any).target_muscles;
    delete (sanitizedPayload as any).daysPerWeek;
  }

  const AI_HARD_TIMEOUT_MS = 8_000;
  const abortController = new AbortController();

  const aiCallPromise = callAiProvider(aiConfig, sanitizedPayload, type, abortController.signal)
    .then(r => ({ outcome: 'ai' as const, data: r }))
    .catch(err => ({ outcome: 'ai_error' as const, err }));

  const timeoutPromise = new Promise<{ outcome: 'timeout' }>(resolve =>
    setTimeout(() => {
      abortController.abort();
      resolve({ outcome: 'timeout' });
    }, AI_HARD_TIMEOUT_MS)
  );

  const race = await Promise.race([aiCallPromise, timeoutPromise]);

  let result: any = null;
  let usedFallback = false;
  let repairAttempted = false;

  if (race.outcome === 'ai') {
    result = race.data;
  } else {
    usedFallback = true;
    result = { result: buildFallbackPlan(type, job.data), usage: null };
  }

  await job.updateProgress({ progress: 50, message: 'Analyzing your fitness data...' });

  let aiPlanContent = result.result;
  if (aiPlanContent && aiPlanContent.plan && !aiPlanContent.days) {
    aiPlanContent = aiPlanContent.plan;
  }

  if (!usedFallback) {
    const mpd = job.data.mealsPerDay ?? 3;
    const errors = type === 'WORKOUT'
      ? collectWorkoutErrors(aiPlanContent, job.data.daysPerWeek ?? 0)
      : collectDietErrors(aiPlanContent, mpd, job.data.targetCalories);

    if (errors.length > 0) {
      repairAttempted = true;
      await job.updateProgress({ progress: 82, message: 'Fine-tuning your plan...' });
      const repaired = await attemptRepair(aiConfig, aiPlanContent, errors, type, job.data);
      if (repaired) {
        const repairErrors = type === 'WORKOUT'
          ? collectWorkoutErrors(repaired, job.data.daysPerWeek ?? 0)
          : collectDietErrors(repaired, mpd, job.data.targetCalories);
        if (repairErrors.length === 0) aiPlanContent = repaired;
        else { aiPlanContent = buildFallbackPlan(type, job.data); usedFallback = true; }
      } else { aiPlanContent = buildFallbackPlan(type, job.data); usedFallback = true; }
    }
  }

  try {
    if (type === 'WORKOUT') {
      await saveWorkoutPlan(job.data.userId, aiPlanContent, job.data);
    } else {
      await saveDietPlan(job.data.userId, aiPlanContent, job.data, usedFallback);
    }
  } catch (err) {
    const emergencyPlan = buildFallbackPlan(type, job.data);
    if (type === 'WORKOUT') await saveWorkoutPlan(job.data.userId, emergencyPlan, job.data);
    else await saveDietPlan(job.data.userId, emergencyPlan, job.data, true);
    usedFallback = true;
  }

  await prisma.user.update({ where: { id: job.data.userId }, data: { updatedAt: new Date() } });
  await PlatformConfigService.logAIUsage({
    userId: job.data.userId,
    provider: aiConfig.activeProvider,
    model: resolveModelName(aiConfig),
    promptTokens: result?.usage?.prompt_tokens ?? 0,
    completionTokens: result?.usage?.completion_tokens ?? 0,
    requestType: `${type}_PLAN_GENERATION`,
  });

  await job.updateProgress({ progress: 90, message: 'Sending your plan to the cloud...' });
  await job.updateProgress(100);

  await pushNotificationQueue.add('plan-ready', {
    userIds: [job.data.userId],
    title: `Your ${type === 'WORKOUT' ? 'workout' : 'diet'} plan is ready! 💪`,
    body: 'Tap to view your new personalized plan.',
    data: { type: `${type}_PLAN`, action: 'VIEW_PLAN' },
  }, { jobId: `push-plan-ready-${job.data.userId}-${type}` });

  return { success: true, type, plan: aiPlanContent };
}

async function callAiProvider(aiConfig: any, payload: AiJobPayload, type: 'WORKOUT' | 'DIET', signal?: AbortSignal) {
  const mealsPerDay = payload.mealsPerDay || 3;
  const mealNames = getMealNameSet(mealsPerDay);
  const systemPrompt = type === 'WORKOUT' ? buildWorkoutSystemPrompt() : buildDietSystemPrompt(mealsPerDay, mealNames);
  const userPrompt = buildUserPrompt(payload, type);

  let rawContent = '';
  let usageData: any = null;

  if (aiConfig.activeProvider === 'OPENAI' && aiConfig.openaiApiKey) {
    const r = await axios.post('https://api.openai.com/v1/chat/completions', {
      model: aiConfig.openaiModel,
      messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
      temperature: aiConfig.temperature || 0.7,
      response_format: { type: 'json_object' },
    }, { headers: { Authorization: `Bearer ${aiConfig.openaiApiKey}` }, signal });
    rawContent = r.data.choices[0].message.content;
    usageData = r.data.usage;
  } else if (aiConfig.activeProvider === 'ANTHROPIC' && aiConfig.anthropicApiKey) {
    const r = await axios.post('https://api.anthropic.com/v1/messages', {
      model: aiConfig.anthropicModel,
      max_tokens: 4096,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    }, { headers: { 'x-api-key': aiConfig.anthropicApiKey, 'anthropic-version': ANTHROPIC_API_VERSION }, signal });
    rawContent = r.data.content[0].text;
    usageData = { prompt_tokens: r.data.usage.input_tokens, completion_tokens: r.data.usage.output_tokens };
  } else if (aiConfig.activeProvider === 'DEEPSEEK' && aiConfig.deepseekApiKey) {
    const r = await axios.post(`${aiConfig.deepseekBaseUrl}/chat/completions`, {
      model: aiConfig.deepseekModel,
      messages: [{ role: 'system', content: systemPrompt }, { role: 'user', content: userPrompt }],
      response_format: { type: 'json_object' },
    }, { headers: { Authorization: `Bearer ${aiConfig.deepseekApiKey}` }, signal });
    rawContent = r.data.choices[0].message.content;
    usageData = r.data.usage;
  }

  const cleaned = rawContent.trim();
  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  return { result: JSON.parse(cleaned.substring(start, end + 1)), usage: usageData };
}

async function attemptRepair(aiConfig: any, badPlan: any, errors: string[], type: string, payload: any) {
  try {
    const prompt = `The following ${type} plan JSON has validation errors:\n${errors.map(e => `- ${e}`).join('\n')}\n\nOriginal JSON:\n${JSON.stringify(badPlan)}\n\nFix the JSON and return the COMPLETE valid object.`;
    let rawContent = '';
    if (aiConfig.activeProvider === 'OPENAI') {
      const r = await axios.post('https://api.openai.com/v1/chat/completions', {
        model: aiConfig.openaiModel,
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' },
      }, { headers: { Authorization: `Bearer ${aiConfig.openaiApiKey}` } });
      rawContent = r.data.choices[0].message.content;
    } else if (aiConfig.activeProvider === 'ANTHROPIC') {
      const r = await axios.post('https://api.anthropic.com/v1/messages', {
        model: aiConfig.anthropicModel,
        max_tokens: 4096,
        messages: [{ role: 'user', content: prompt }],
      }, { headers: { 'x-api-key': aiConfig.anthropicApiKey, 'anthropic-version': ANTHROPIC_API_VERSION } });
      rawContent = r.data.content[0].text;
    }
    const cleaned = rawContent.trim();
    const start = cleaned.indexOf('{');
    const end = cleaned.lastIndexOf('}');
    return JSON.parse(cleaned.substring(start, end + 1));
  } catch { return null; }
}

async function saveWorkoutPlan(userId: string, aiResult: any, payload: AiJobPayload) {
  const templateName = aiResult.planMeta?.phase ? `${aiResult.planMeta.phase} — ${aiResult.planMeta.primaryGoal}` : `AI Workout Template`;
  const rawDays = Array.isArray(aiResult.days) ? aiResult.days : Object.values(aiResult.days || {});

  await prisma.$transaction(async (tx) => {
    const masterTemplate = await (tx as any).masterWorkoutTemplate.create({
      data: {
        name: templateName,
        description: aiResult.planMeta?.coachNote ?? `Generated for: ${payload.goals}`,
        difficulty: payload.fitnessLevel as DifficultyLevel,
        isAIGenerated: true,
      },
    });

    for (let i = 0; i < rawDays.length; i++) {
      const day = rawDays[i] as any;
      const masterRoutine = await (tx as any).masterWorkoutRoutine.create({
        data: {
          templateId: masterTemplate.id,
          name: day.sessionType ?? day.dayName ?? `Day ${i + 1}`,
          dayOfWeek: day.dayOfWeek ? (day.dayOfWeek.toUpperCase() as DayOfWeek) : null,
          estimatedMinutes: day.estimatedDurationMinutes ?? 60,
          orderIndex: i,
        },
      });

      const exercises = [...(day.mainWork ?? []).map((ex: any, idx: number) => ({ ...ex, _saveIdx: idx })), ...(day.warmup ?? []).map((ex: any, idx: number) => ({ ...ex, _saveIdx: idx + 1000 }))];
      for (const ex of exercises) {
        await (tx as any).masterExerciseSet.create({
          data: {
            routineId: masterRoutine.id,
            exerciseName: ex.exerciseName ?? 'Unknown',
            targetSets: ex.sets ?? 3,
            targetReps: ex.minReps ?? 10,
            targetRepsMax: ex.maxReps ?? 12,
            restSeconds: ex.restSeconds ?? 60,
            orderIndex: ex._saveIdx,
            progressionNote: ex.progressionNote ?? null,
          },
        });
      }
    }

    const plan = await tx.workoutPlan.create({
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

    await tx.workoutPlan.updateMany({ where: { userId, isActive: true, id: { not: plan.id } }, data: { isActive: false } });
    await ProgressService.initializeTodayProgress(userId);
  });
}

async function saveDietPlan(userId: string, aiResult: any, payload: AiJobPayload, usedFallback: boolean) {
  const meta = aiResult.planMeta || aiResult.plan_meta || aiResult.meta;
  const rawDays = Array.isArray(aiResult.days) ? aiResult.days : Object.values(aiResult.days || {});

  await prisma.$transaction(async (tx) => {
    const masterDiet = await (tx as any).masterDietTemplate.create({
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

    for (let i = 0; i < rawDays.length; i++) {
      const day = rawDays[i] as any;
      for (let j = 0; j < (day.meals || []).length; j++) {
        const meal = day.meals[j];
        const masterMeal = await (tx as any).masterMeal.create({
          data: {
            templateId: masterDiet.id,
            name: meal.type?.toUpperCase() || 'MEAL',
            timeOfDay: meal.time,
            dayOfWeek: day.dayOfWeek?.toUpperCase(),
            orderIndex: j,
            instructions: meal.instructions,
          } as any,
        });
        for (const ing of (meal.ingredients || [])) {
          await (tx as any).masterMealIngredient.create({
            data: {
              mealId: masterMeal.id,
              name: ing.name,
              amount: String(ing.amount),
              unit: ing.unit,
              calories: Math.round(ing.calories),
              protein: ing.protein,
              carbs: ing.carbs,
              fats: ing.fats,
            } as any,
          });
        }
      }
    }

    const plan = await tx.dietPlan.create({
      data: {
        userId,
        masterTemplateId: masterDiet.id,
        name: masterDiet.name,
        isAIGenerated: true,
        isActive: true,
        status: 'ACTIVE',
        startDate: getStartOfToday(),
        numWeeks: 4,
        targetCalories: Math.round(meta.dailyCalories || 2000),
        targetProtein: Math.round(meta.macros?.protein || 150),
        targetCarbs: Math.round(meta.macros?.carbs || 200),
        targetFats: Math.round(meta.macros?.fats || 65),
      },
    });

    await tx.dietPlan.updateMany({ where: { userId, isActive: true, id: { not: plan.id } }, data: { isActive: false, status: 'ARCHIVED' } });
    await ProgressService.initializeTodayProgress(userId);
  });
}

function collectWorkoutErrors(plan: any, requestedDays: number): string[] {
  const errors: string[] = [];
  const days = plan.days || [];
  if (days.length > MAX_WORKOUT_DAYS) errors.push('Too many days');
  let trainingDays = 0;
  for (const day of days) {
    if (!day.isRestDay) trainingDays++;
    const totalSets = [...(day.warmup || []), ...(day.mainWork || [])].reduce((s, ex) => s + (Number(ex.sets) || 0), 0);
    if (totalSets > MAX_SETS_PER_DAY) errors.push(`Day ${day.dayOfWeek}: too many sets`);
  }
  if (requestedDays > 0 && trainingDays !== requestedDays) errors.push('Day count mismatch');
  return errors;
}

function collectDietErrors(plan: any, mealsPerDay: number, targetCal?: number): string[] {
  const errors: string[] = [];
  const meta = plan.planMeta || plan.plan_meta || plan.meta;
  if (!meta) return ['Missing meta'];
  const cal = targetCal ?? Number(meta.dailyCalories || 0);
  if (cal < 800 || cal > 6000) errors.push('Calories out of range');
  return errors;
}

function buildWorkoutSystemPrompt() { return `You are an elite strength coach. Generate JSON.`; }
function buildDietSystemPrompt(mpd: number, names: string[]) { return `You are an RD. Generate JSON for ${mpd} meals: ${names.join(', ')}.`; }
function getMealNameSet(count: number) {
  if (count === 3) return ['BREAKFAST', 'LUNCH', 'DINNER'];
  return Array.from({ length: count }, (_, i) => `MEAL ${i + 1}`);
}
function buildUserPrompt(payload: AiJobPayload, type: string) { return `Generate ${type} plan for ${payload.goals}.`; }

function buildFallbackPlan(type: 'WORKOUT' | 'DIET', payload: AiJobPayload): any {
  if (type === 'WORKOUT') {
    return { planMeta: { phase: 'Foundation' }, days: [{ dayOfWeek: 'MONDAY', isRestDay: false, mainWork: [{ exerciseName: 'Push-Up', sets: 3, minReps: 10, maxReps: 12 }] }] };
  }
  return { planMeta: { dailyCalories: 2000 }, days: [{ dayOfWeek: 'MONDAY', meals: [{ type: 'BREAKFAST', calories: 500, ingredients: [{ name: 'Oats', amount: 80, unit: 'g', calories: 300 }] }] }] };
}

let _aiConfigCache: any = null;
async function getAiConfig() {
  if (_aiConfigCache && Date.now() < _aiConfigCache.expiresAt) return _aiConfigCache.value;
  const cfg = await prisma.aIConfig.findFirst({ where: { isEnabled: true }, orderBy: { updatedAt: 'desc' } });
  if (!cfg) return null;
  const dec = { ...cfg, openaiApiKey: decryptField(cfg.openaiApiKey), anthropicApiKey: decryptField(cfg.anthropicApiKey), deepseekApiKey: decryptField(cfg.deepseekApiKey) };
  _aiConfigCache = { value: dec, expiresAt: Date.now() + 60000 };
  return dec;
}

function resolveModelName(aiConfig: any) { return aiConfig.openaiModel || aiConfig.anthropicModel || aiConfig.deepseekModel || 'unknown'; }
function getStartOfToday() { const d = new Date(); d.setUTCHours(0, 0, 0, 0); return d; }

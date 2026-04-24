import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

/**
 * TrainerContributionService — manages trainer-created items and super admin review.
 *
 * Rules:
 *   - Trainers create food items / exercises → status defaults to PENDING
 *   - Super admin changes status (UNDER_REVIEW → APPROVED | REJECTED)
 *   - Super admin can attach media (imageUrl + iconUrl for food, videoUrl for exercise)
 *   - Only APPROVED items appear in filter queries
 */

// ─── Input types ─────────────────────────────────────────────────────────────

export interface CreateFoodItemInput {
  name: string;
  nameKa?: string;
  nameRu?: string;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
  fiber?: number;
  sugar?: number;
  sodium?: number;
  foodCategory?: string;
  countryCodes?: string[];
  seasonality?: string[];
  allergyTags?: string[];
  substitutionGroup?: string;
}

export interface CreateExerciseInput {
  name: string;
  nameKa?: string;
  nameRu?: string;
  primaryMuscle: string;
  secondaryMuscles?: string[];
  equipment?: string[];
  difficulty?: string;
  mechanics?: string;
  force?: string;
  cues?: string[];
  commonMistakes?: string[];
  metValue?: number;
  location?: string[];
  fitnessGoals?: string[];
}

export interface ReviewFoodItemInput {
  status: 'UNDER_REVIEW' | 'APPROVED' | 'REJECTED';
  imageUrl?: string;
  iconUrl?: string;
  /** Optional corrections to metadata during review */
  countryCodes?: string[];
  allergyTags?: string[];
  availabilityScore?: number;
}

export interface ReviewExerciseInput {
  status: 'UNDER_REVIEW' | 'APPROVED' | 'REJECTED';
  videoUrl?: string;
  location?: string[];
  fitnessGoals?: string[];
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class TrainerContributionService {

  // ── Trainer: create food item (PENDING) ────────────────────────────────────

  static async createFoodItem(trainerId: string, input: CreateFoodItemInput) {
    const item = await prisma.foodItem.create({
      data: {
        id: require('crypto').randomUUID(),
        name: input.name,
        nameKa: input.nameKa,
        nameRu: input.nameRu,
        calories: input.calories,
        protein: input.protein,
        carbs: input.carbs,
        fats: input.fats,
        fiber: input.fiber,
        sugar: input.sugar,
        sodium: input.sodium,
        foodCategory: input.foodCategory as any,
        source: 'TRAINER',
        isVerified: false,
        status: 'PENDING',
        countryCodes: input.countryCodes ?? [],
        seasonality: input.seasonality ?? [],
        allergyTags: input.allergyTags ?? [],
        substitutionGroup: input.substitutionGroup,
        createdById: trainerId,
      },
    });
    logger.info(`[Contribution] Trainer ${trainerId} created food item ${item.id}`);
    return item;
  }

  // ── Trainer: create exercise (PENDING) ─────────────────────────────────────

  static async createExercise(trainerId: string, input: CreateExerciseInput) {
    const item = await prisma.exerciseLibrary.create({
      data: {
        id: require('crypto').randomUUID(),
        name: input.name,
        nameKa: input.nameKa,
        nameRu: input.nameRu,
        primaryMuscle: input.primaryMuscle,
        secondaryMuscles: input.secondaryMuscles ?? [],
        equipment: input.equipment ?? [],
        difficulty: (input.difficulty ?? 'BEGINNER') as any,
        mechanics: (input.mechanics ?? 'COMPOUND') as any,
        force: (input.force ?? 'PUSH') as any,
        cues: input.cues ?? [],
        commonMistakes: input.commonMistakes ?? [],
        metValue: input.metValue ?? 3.0,
        status: 'PENDING',
        location: input.location ?? [],
        fitnessGoals: input.fitnessGoals ?? [],
        createdById: trainerId,
      },
    });
    logger.info(`[Contribution] Trainer ${trainerId} created exercise ${item.id}`);
    return item;
  }

  // ── Super Admin: review food item ──────────────────────────────────────────

  static async reviewFoodItem(itemId: string, adminId: string, input: ReviewFoodItemInput) {
    const updateData: any = { status: input.status };
    if (input.imageUrl !== undefined) updateData.imageUrl = input.imageUrl;
    if (input.iconUrl !== undefined) updateData.iconUrl = input.iconUrl;
    if (input.countryCodes !== undefined) updateData.countryCodes = input.countryCodes;
    if (input.allergyTags !== undefined) updateData.allergyTags = input.allergyTags;
    if (input.availabilityScore !== undefined) updateData.availabilityScore = input.availabilityScore;

    if (input.status === 'APPROVED') updateData.isVerified = true;

    const item = await prisma.foodItem.update({ where: { id: itemId }, data: updateData });
    logger.info(`[Contribution] Admin ${adminId} set food item ${itemId} → ${input.status}`);
    return item;
  }

  // ── Super Admin: review exercise ───────────────────────────────────────────

  static async reviewExercise(itemId: string, adminId: string, input: ReviewExerciseInput) {
    const updateData: any = { status: input.status };
    if (input.videoUrl !== undefined) updateData.videoUrl = input.videoUrl;
    if (input.location !== undefined) updateData.location = input.location;
    if (input.fitnessGoals !== undefined) updateData.fitnessGoals = input.fitnessGoals;

    const item = await prisma.exerciseLibrary.update({ where: { id: itemId }, data: updateData });
    logger.info(`[Contribution] Admin ${adminId} set exercise ${itemId} → ${input.status}`);
    return item;
  }

  // ── Admin: list pending items ───────────────────────────────────────────────

  static async listPendingFoodItems(page = 1, limit = 20) {
    const [items, total] = await Promise.all([
      prisma.foodItem.findMany({
        where: { status: { in: ['PENDING', 'UNDER_REVIEW'] } },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: { createdByUser: { select: { id: true, fullName: true, email: true } } },
      }),
      prisma.foodItem.count({ where: { status: { in: ['PENDING', 'UNDER_REVIEW'] } } }),
    ]);
    return { items, total, page, pages: Math.ceil(total / limit) };
  }

  static async listPendingExercises(page = 1, limit = 20) {
    const [items, total] = await Promise.all([
      prisma.exerciseLibrary.findMany({
        where: { status: { in: ['PENDING', 'UNDER_REVIEW'] } },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: { createdByUser: { select: { id: true, fullName: true, email: true } } },
      }),
      prisma.exerciseLibrary.count({ where: { status: { in: ['PENDING', 'UNDER_REVIEW'] } } }),
    ]);
    return { items, total, page, pages: Math.ceil(total / limit) };
  }

  // ── SubstitutionMap management (admin) ────────────────────────────────────

  static async addSubstitution(input: {
    foodItemId: string;
    substituteId: string;
    culturalScore?: number;
    nutritionalScore?: number;
    countryCodes?: string[];
  }) {
    return prisma.substitutionMap.upsert({
      where: {
        foodItemId_substituteId: {
          foodItemId: input.foodItemId,
          substituteId: input.substituteId,
        },
      },
      update: {
        culturalScore: input.culturalScore ?? 50,
        nutritionalScore: input.nutritionalScore ?? 50,
        countryCodes: input.countryCodes ?? [],
        isActive: true,
      },
      create: {
        id: require('crypto').randomUUID(),
        foodItemId: input.foodItemId,
        substituteId: input.substituteId,
        culturalScore: input.culturalScore ?? 50,
        nutritionalScore: input.nutritionalScore ?? 50,
        countryCodes: input.countryCodes ?? [],
      },
    });
  }
}

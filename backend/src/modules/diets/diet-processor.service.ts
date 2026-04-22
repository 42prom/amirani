import { PrismaClient } from '@prisma/client';

export interface MealIngredient {
  name: string;
  amount: number;
  unit: string;
  calories: number;
  protein: number;
  carbs: number;
  fats: number;
}

export class DietProcessorService {
  private prisma: PrismaClient;

  constructor(prisma: PrismaClient) {
    this.prisma = prisma;
  }

  /**
   * Sums up the macros of ingredients and returns a validated meal object.
   * Ensures that the totalCalories field is actually the sum of parts.
   */
  calculateMealTotals(ingredients: MealIngredient[]): {
    totalCalories: number;
    protein: number;
    carbs: number;
    fats: number;
    ingredients: MealIngredient[];
  } {
    let totalCalories = 0;
    let protein = 0;
    let carbs = 0;
    let fats = 0;

    for (const ing of ingredients) {
      totalCalories += ing.calories || 0;
      protein += ing.protein || 0;
      carbs += ing.carbs || 0;
      fats += ing.fats || 0;
    }

    return {
      totalCalories: Math.round(totalCalories),
      protein: Math.round(protein),
      carbs: Math.round(carbs),
      fats: Math.round(fats),
      ingredients: ingredients,
    };
  }

  /**
   * Estimates daily targets using Mifflin-St Jeor BMR × TDEE activity multiplier.
   * Incorporates age, gender, activity level, and goal adjustment.
   * Used for both AI generating plans and Trainer assigning them.
   */
  calculateDailyTargets(userContext: any): {
    calories: number;
    protein: number;
    carbs: number;
    fats: number;
    water: number;
  } {
    const weight = Math.max(30, userContext.weightKg || 70);   // kg, floor at 30
    const height = Math.max(100, userContext.heightCm || 170); // cm, floor at 100
    const age    = Math.max(10, Math.min(100, userContext.age || 30));
    const gender = (userContext.gender || 'male').toLowerCase();
    const goal   = (userContext.goal || 'MAINTAIN').toUpperCase(); // BURN | BUILD | MAINTAIN

    // Map activity strings to TDEE multipliers (Mifflin-St Jeor)
    const activityMultipliers: Record<string, number> = {
      SEDENTARY:   1.2,
      LIGHT:       1.375,
      MODERATE:    1.55,
      ACTIVE:      1.725,
      VERY_ACTIVE: 1.9,
    };
    const activityKey = (userContext.activityLevel || 'MODERATE').toUpperCase();
    const multiplier  = activityMultipliers[activityKey] ?? 1.55;

    // Mifflin-St Jeor BMR formula
    let bmr: number;
    if (gender === 'female' || gender === 'f') {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    }

    let calories = bmr * multiplier;

    // Goal-based adjustment
    if (goal === 'BURN')  calories -= 500;
    if (goal === 'BUILD') calories += 300;

    // Safety floor: 1200 kcal minimum to prevent dangerous deficits
    calories = Math.max(1200, Math.round(calories));

    const protein = Math.round(weight * 2.0);          // 2 g/kg
    const fats    = Math.round(weight * 0.8);          // 0.8 g/kg
    // Derive carbs from remaining calories; floor at 0 to prevent negatives
    const carbs = Math.max(0, Math.round((calories - protein * 4 - fats * 9) / 4));
    const water = Math.round(weight * 0.035 * 10) / 10; // 35 ml/kg → litres

    return { calories, protein, fats, carbs, water };
  }
}

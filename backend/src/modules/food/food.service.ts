import prisma from '../../lib/prisma';
import { FoodSource, MealType } from '@prisma/client';
import axios from 'axios';
import config from '../../config/env';
import logger from '../../lib/logger';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface FoodSearchResult {
  id?: string;             // local DB id if cached
  name: string;
  nameEn?: string;         // always English fallback
  brand?: string;
  barcode?: string;
  calories: number;        // per 100g
  protein: number;
  carbs: number;
  fats: number;
  fiber?: number;
  source: 'DB' | 'NUTRITIONIX' | 'OPEN_FOOD_FACTS';
}

export interface LogFoodInput {
  foodItemId?: string;      // if logging from DB
  externalFood?: {          // if logging from search without saving first
    name: string;
    brand?: string;
    barcode?: string;
    calories: number;
    protein: number;
    carbs: number;
    fats: number;
    fiber?: number;
    source: 'NUTRITIONIX' | 'OPEN_FOOD_FACTS' | 'USER';
  };
  mealType: 'BREAKFAST' | 'LUNCH' | 'DINNER' | 'SNACK' | 'PRE_WORKOUT' | 'POST_WORKOUT';
  grams: number;
  loggedAt?: string;        // ISO date string, defaults to now
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class FoodService {

  // ─── Search foods ─────────────────────────────────────────────────────────

  static async search(query: string, limit = 20, lang: 'EN' | 'KA' | 'RU' = 'EN'): Promise<FoodSearchResult[]> {
    query = query.trim();
    if (!query || query.length < 2) return [];

    // 1. Check local DB first (cached results)
    const localResults = await prisma.foodItem.findMany({
      where: {
        OR: [
          { name:   { contains: query, mode: 'insensitive' } },
          { nameKa: { contains: query, mode: 'insensitive' } },
          { nameRu: { contains: query, mode: 'insensitive' } },
          { brand:  { contains: query, mode: 'insensitive' } },
        ],
      },
      take: limit,
      orderBy: [{ isVerified: 'desc' }, { name: 'asc' }],
    });

    if (localResults.length >= 5) {
      return localResults.map(r => this.toSearchResult(r, lang));
    }

    // 2. Fallback to Nutritionix API
    try {
      const nutritionixResults = await this.searchNutritionix(query, limit);
      // Cache results in background
      this.cacheResults(nutritionixResults).catch((e) => logger.warn('[Food] Cache write failed', { e }));
      // Merge with local, deduplicate by name+brand
      const localNames = new Set(localResults.map(r => `${r.name}|${r.brand ?? ''}`));
      const merged = [
        ...localResults.map(r => this.toSearchResult(r, lang)),
        ...nutritionixResults.filter(r => !localNames.has(`${r.name}|${r.brand ?? ''}`)),
      ];
      return merged.slice(0, limit);
    } catch (nutritionixErr) {
      logger.warn('[FoodService] Nutritionix failed, falling back to Open Food Facts', { nutritionixErr });
    }

    // 3. Fallback to Open Food Facts (free)
    try {
      const offResults = await this.searchOpenFoodFacts(query, limit);
      this.cacheResults(offResults).catch((e) => logger.warn('[Food] Cache write failed', { e }));
      return [...localResults.map(r => this.toSearchResult(r, lang)), ...offResults].slice(0, limit);
    } catch (offErr) {
      logger.warn('[FoodService] Open Food Facts also failed', { offErr });
    }

    // Return local results only
    return localResults.map(r => this.toSearchResult(r, lang));
  }

  // ─── Barcode lookup ───────────────────────────────────────────────────────

  static async lookupBarcode(barcode: string): Promise<FoodSearchResult | null> {
    // 1. Check local DB
    const local = await prisma.foodItem.findUnique({ where: { barcode } });
    if (local) return this.toSearchResult(local);

    // 2. Nutritionix barcode lookup
    try {
      const result = await this.lookupNutritionixBarcode(barcode);
      if (result) {
        await this.cacheResults([result]);
        return result;
      }
    } catch {}

    // 3. Open Food Facts barcode
    try {
      const result = await this.lookupOpenFoodFactsBarcode(barcode);
      if (result) {
        await this.cacheResults([result]);
        return result;
      }
    } catch {}

    return null;
  }

  // ─── Log a food entry ─────────────────────────────────────────────────────

  static async logFood(userId: string, input: LogFoodInput) {
    const { mealType, grams, loggedAt } = input;
    const logDate = loggedAt ? new Date(loggedAt) : new Date();

    if (grams <= 0) throw Object.assign(new Error('Grams must be positive'), { status: 400 });

    // Resolve or create FoodItem
    let foodItemId = input.foodItemId;
    let foodItem = foodItemId
      ? await prisma.foodItem.findUnique({ where: { id: foodItemId } })
      : null;

    if (!foodItem && input.externalFood) {
      // Auto-save to DB
      foodItem = await prisma.foodItem.upsert({
        where: { barcode: input.externalFood.barcode ?? `__nobc__${Date.now()}` },
        update: {},
        create: {
          name: input.externalFood.name,
          brand: input.externalFood.brand,
          barcode: input.externalFood.barcode,
          calories: input.externalFood.calories,
          protein: input.externalFood.protein,
          carbs: input.externalFood.carbs,
          fats: input.externalFood.fats,
          fiber: input.externalFood.fiber,
          source: input.externalFood.source as FoodSource,
          isVerified: false,
        },
      });
      foodItemId = foodItem.id;
    }

    if (!foodItem) throw Object.assign(new Error('Food item not found'), { status: 404 });

    // Calculate macros from grams
    const factor = grams / 100;
    const calories = Math.round(foodItem.calories * factor * 10) / 10;
    const protein  = Math.round(foodItem.protein  * factor * 10) / 10;
    const carbs    = Math.round(foodItem.carbs    * factor * 10) / 10;
    const fats      = Math.round(foodItem.fats      * factor * 10) / 10;
    const fiber    = foodItem.fiber != null ? Math.round(foodItem.fiber * factor * 10) / 10 : null;

    // Get or create DailyProgress for the log date (UTC midnight — matches all other DailyProgress upserts)
    const dateKey = new Date(logDate);
    dateKey.setUTCHours(0, 0, 0, 0);

    const dailyProgress = await prisma.dailyProgress.upsert({
      where: { userId_date: { userId, date: dateKey } },
      update: {},
      create: {
        userId,
        date: dateKey,
        caloriesConsumed: 0,
        proteinConsumed: 0,
        carbsConsumed: 0,
        fatsConsumed: 0,
      },
    });

    // Atomic transaction: create FoodLog + update DailyProgress macros
    const [foodLog] = await prisma.$transaction([
      prisma.foodLog.create({
        data: {
          userId,
          dailyProgressId: dailyProgress.id,
          foodItemId: foodItem.id,
          mealType: mealType as MealType,
          grams,
          calories,
          protein,
          carbs,
          fats,
          fiber,
          loggedAt: logDate,
        },
        include: { foodItem: true },
      }),
      prisma.dailyProgress.update({
        where: { id: dailyProgress.id },
        data: {
          caloriesConsumed: { increment: Math.round(calories) },
          proteinConsumed:  { increment: Math.round(protein) },
          carbsConsumed:    { increment: Math.round(carbs) },
          fatsConsumed:     { increment: Math.round(fats) },
        },
      }),
    ]);

    return foodLog;
  }

  // ─── Get diary for a date ─────────────────────────────────────────────────

  static async getDiary(userId: string, date: string) {
    const dateKey = new Date(date);
    dateKey.setHours(0, 0, 0, 0);

    const [logs, dailyProgress] = await Promise.all([
      prisma.foodLog.findMany({
        where: {
          userId,
          loggedAt: {
            gte: dateKey,
            lt: new Date(dateKey.getTime() + 24 * 60 * 60 * 1000),
          },
        },
        include: { foodItem: { select: { id: true, name: true, brand: true, calories: true } } },
        orderBy: { loggedAt: 'asc' },
      }),
      prisma.dailyProgress.findUnique({
        where: { userId_date: { userId, date: dateKey } },
      }),
    ]);

    // Group by meal type
    const byMeal: Record<string, typeof logs> = {};
    for (const log of logs) {
      if (!byMeal[log.mealType]) byMeal[log.mealType] = [];
      byMeal[log.mealType].push(log);
    }

    const totals = {
      calories: logs.reduce((s, l) => s + l.calories, 0),
      protein:  logs.reduce((s, l) => s + l.protein, 0),
      carbs:    logs.reduce((s, l) => s + l.carbs, 0),
      fats:     logs.reduce((s, l) => s + l.fats, 0),
    };

    return { byMeal, totals, dailyProgress };
  }

  // ─── Delete a food log entry ──────────────────────────────────────────────

  static async deleteLog(userId: string, logId: string) {
    const log = await prisma.foodLog.findUnique({
      where: { id: logId },
    });

    if (!log) throw Object.assign(new Error('Log entry not found'), { status: 404 });
    if (log.userId !== userId) throw Object.assign(new Error('Access denied'), { status: 403 });

    // Reverse the macro update atomically
    const ops: any[] = [prisma.foodLog.delete({ where: { id: logId } })];

    if (log.dailyProgressId) {
      ops.push(
        prisma.dailyProgress.update({
          where: { id: log.dailyProgressId },
          data: {
            caloriesConsumed: { decrement: Math.round(log.calories) },
            proteinConsumed:  { decrement: Math.round(log.protein) },
            carbsConsumed:    { decrement: Math.round(log.carbs) },
            fatsConsumed:     { decrement: Math.round(log.fats) },
          },
        })
      );
    }

    await prisma.$transaction(ops);
    return { deleted: true };
  }

  // ─── Nutritionix API ──────────────────────────────────────────────────────

  private static async searchNutritionix(query: string, limit: number): Promise<FoodSearchResult[]> {
    const appId  = (config as any).nutritionix?.appId;
    const appKey = (config as any).nutritionix?.appKey;
    if (!appId || !appKey) throw new Error('Nutritionix not configured');

    const response = await axios.get('https://trackapi.nutritionix.com/v2/search/instant', {
      params: { query, branded: true, common: true },
      headers: { 'x-app-id': appId, 'x-app-key': appKey },
      timeout: 5000,
    });

    const items = [
      ...(response.data.common ?? []).slice(0, Math.ceil(limit / 2)),
      ...(response.data.branded ?? []).slice(0, Math.floor(limit / 2)),
    ];

    return items.map((item: any) => ({
      name: item.food_name,
      brand: item.brand_name,
      barcode: item.upc,
      calories: item.nf_calories ?? 0,
      protein: item.nf_protein ?? 0,
      carbs: item.nf_total_carbohydrate ?? 0,
      fats: item.nf_total_fat ?? 0,
      fiber: item.nf_dietary_fiber,
      source: 'NUTRITIONIX' as const,
    }));
  }

  private static async lookupNutritionixBarcode(barcode: string): Promise<FoodSearchResult | null> {
    const appId  = (config as any).nutritionix?.appId;
    const appKey = (config as any).nutritionix?.appKey;
    if (!appId || !appKey) return null;

    const response = await axios.get(`https://trackapi.nutritionix.com/v2/search/item`, {
      params: { upc: barcode },
      headers: { 'x-app-id': appId, 'x-app-key': appKey },
      timeout: 5000,
    });

    const item = response.data?.foods?.[0];
    if (!item) return null;

    return {
      name: item.food_name,
      brand: item.brand_name,
      barcode,
      calories: item.nf_calories ?? 0,
      protein: item.nf_protein ?? 0,
      carbs: item.nf_total_carbohydrate ?? 0,
      fats: item.nf_total_fat ?? 0,
      fiber: item.nf_dietary_fiber,
      source: 'NUTRITIONIX',
    };
  }

  // ─── Open Food Facts API ──────────────────────────────────────────────────

  private static async searchOpenFoodFacts(query: string, limit: number): Promise<FoodSearchResult[]> {
    const response = await axios.get('https://world.openfoodfacts.org/cgi/search.pl', {
      params: {
        search_terms: query,
        search_simple: 1,
        action: 'process',
        json: 1,
        page_size: limit,
        fields: 'product_name,brands,code,nutriments',
      },
      timeout: 8000,
    });

    return (response.data?.products ?? [])
      .filter((p: any) => p.product_name && p.nutriments?.['energy-kcal_100g'])
      .map((p: any) => ({
        name: p.product_name,
        brand: p.brands?.split(',')[0]?.trim(),
        barcode: p.code,
        calories: p.nutriments['energy-kcal_100g'] ?? 0,
        protein: p.nutriments.proteins_100g ?? 0,
        carbs: p.nutriments.carbohydrates_100g ?? 0,
        fats: p.nutriments.fat_100g ?? 0,
        fiber: p.nutriments.fiber_100g,
        source: 'OPEN_FOOD_FACTS' as const,
      }));
  }

  private static async lookupOpenFoodFactsBarcode(barcode: string): Promise<FoodSearchResult | null> {
    const response = await axios.get(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`, {
      timeout: 8000,
    });

    const product = response.data?.product;
    if (!product || response.data.status !== 1) return null;

    return {
      name: product.product_name,
      brand: product.brands?.split(',')[0]?.trim(),
      barcode,
      calories: product.nutriments?.['energy-kcal_100g'] ?? 0,
      protein: product.nutriments?.proteins_100g ?? 0,
      carbs: product.nutriments?.carbohydrates_100g ?? 0,
      fats: product.nutriments?.fat_100g ?? 0,
      fiber: product.nutriments?.fiber_100g,
      source: 'OPEN_FOOD_FACTS',
    };
  }

  // ─── Cache results to local DB ────────────────────────────────────────────

  private static async cacheResults(results: FoodSearchResult[]) {
    for (const r of results) {
      try {
        const where = r.barcode
          ? { barcode: r.barcode }
          : { name_brand: { name: r.name, brand: r.brand ?? '' } as any };

        if (r.barcode) {
          await prisma.foodItem.upsert({
            where: { barcode: r.barcode },
            update: { name: r.name, calories: r.calories, protein: r.protein, carbs: r.carbs, fats: r.fats, fiber: r.fiber ?? null },
            create: {
              name: r.name, brand: r.brand, barcode: r.barcode,
              calories: r.calories, protein: r.protein, carbs: r.carbs, fats: r.fats,
              fiber: r.fiber ?? null, source: r.source as FoodSource, isVerified: true,
            },
          });
        } else {
          // Only insert if name doesn't exist yet (avoid spamming DB)
          const existing = await prisma.foodItem.findFirst({ where: { name: r.name, brand: r.brand ?? null } });
          if (!existing) {
            await prisma.foodItem.create({
              data: {
                name: r.name, brand: r.brand, calories: r.calories,
                protein: r.protein, carbs: r.carbs, fats: r.fats,
                fiber: r.fiber ?? null, source: r.source as FoodSource, isVerified: true,
              },
            });
          }
        }
      } catch {
        // silently skip caching errors
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  private static toSearchResult(item: any, lang: 'EN' | 'KA' | 'RU' = 'EN'): FoodSearchResult {
    const displayName = (lang === 'KA' && item.nameKa) ? item.nameKa
                      : (lang === 'RU' && item.nameRu) ? item.nameRu
                      : item.name;
    return {
      id:      item.id,
      name:    displayName,
      nameEn:  item.name,
      brand:   item.brand,
      barcode: item.barcode,
      calories: item.calories,
      protein:  item.protein,
      carbs:    item.carbs,
      fats:     item.fats,
      fiber:    item.fiber,
      source:   'DB',
    };
  }
}


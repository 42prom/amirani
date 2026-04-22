import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function migrate() {
  console.log('🚀 Starting Ingredient Migration (Foundation Hardening)...');

  const mealsWithItems = await (prisma as any).meal.findMany({
    where: {
      items: { not: null }
    }
  });

  console.log(`🔍 Found ${mealsWithItems.length} meals with legacy JSON items.`);

  let migratedCount = 0;
  let ingredientCount = 0;

  for (const meal of mealsWithItems) {
    try {
      let ingredients: any[] = [];
      
      // Handle various JSON formats encountered in earlier versions
      if (Array.isArray(meal.items)) {
        ingredients = meal.items;
      } else if (meal.items && typeof meal.items === 'object' && Array.isArray((meal.items as any).ingredients)) {
        ingredients = (meal.items as any).ingredients;
      }

      if (ingredients.length > 0) {
        // Create relational ingredients
        await prisma.$transaction(
          ingredients.map((ing: any) => (prisma as any).mealIngredient.create({
            data: {
              mealId: meal.id,
              name: ing.name || ing.item || 'Food Item',
              amount: ing.amount || 100,
              unit: ing.unit || 'g',
              calories: ing.calories || 0,
              protein: ing.protein || 0,
              carbs: ing.carbs || 0,
              fats: ing.fats || ing.fat || 0,
            }
          }))
        );
        ingredientCount += ingredients.length;
      }

      // Nullify the legacy field
      await (prisma as any).meal.update({
        where: { id: meal.id },
        data: { items: null }
      });

      migratedCount++;
      if (migratedCount % 10 === 0) {
        console.log(`✅ Progress: ${migratedCount}/${mealsWithItems.length} meals processed.`);
      }
    } catch (err: any) {
      console.error(`❌ Failed to migrate meal ${meal.id}: ${err.message}`);
    }
  }

  console.log('🏁 Migration Complete!');
  console.log(`📊 Stats: ${migratedCount} meals cleaned, ${ingredientCount} ingredients created.`);
}

migrate()
  .catch((e) => {
    console.error('❌ Migration Critical Error:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

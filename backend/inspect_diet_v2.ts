
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function checkLastDietPlan() {
  const plan = await prisma.dietPlan.findFirst({
    where: { isActive: true },
    orderBy: { createdAt: 'desc' },
    include: {
      masterTemplate: {
        include: {
          meals: {
            include: { ingredients: true }
          }
        }
      }
    }
  });

  if (!plan) {
    console.log("No active diet plan found.");
    return;
  }

  console.log("--- DIET PLAN CHECK ---");
  console.log(`ID: ${plan.id}`);
  console.log(`Start Date (DB): ${plan.startDate}`);
  
  const masterMeals = plan.masterTemplate?.meals || [];
  console.log(`Master Meals Count: ${masterMeals.length}`);
  
  if (masterMeals.length > 0) {
    // Show first day's meals
    const day0Meals = masterMeals.filter(m => m.orderIndex === 0);
    console.log(`Day 0 Meals: ${day0Meals.length}`);
    day0Meals.forEach(m => {
        console.log(`  - ${m.name} | DayOfWeek: ${m.dayOfWeek} | Time: ${m.timeOfDay}`);
    });
  }
}

checkLastDietPlan()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

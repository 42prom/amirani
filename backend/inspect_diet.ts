
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
      },
      meals: {
        include: { ingredients: true }
      }
    }
  });

  if (!plan) {
    console.log("No active diet plan found.");
    return;
  }

  console.log("--- DIET PLAN CHECK ---");
  console.log(`ID: ${plan.id}`);
  console.log(`Name: ${plan.name}`);
  console.log(`Is AI: ${plan.isAIGenerated}`);
  console.log(`Master Template ID: ${plan.masterTemplateId}`);
  console.log(`Master Meals Count: ${plan.masterTemplate?.meals?.length || 0}`);
  
  if (plan.masterTemplate?.meals) {
    plan.masterTemplate.meals.forEach((m, i) => {
      console.log(`  Meal ${i}: ${m.name} | Day: ${m.dayOfWeek} | OrderIndex: ${m.orderIndex} | Ingredients: ${m.ingredients.length}`);
    });
  }

  console.log(`Direct Meals Count: ${plan.meals?.length || 0}`);
}

checkLastDietPlan()
  .catch(console.error)
  .finally(() => prisma.$disconnect());


import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function testMobileSync() {
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
    console.log("No plan found.");
    return;
  }

  const userId = plan.userId;
  console.log(`Testing Sync for User: ${userId}`);

  // We can't easily call the controller method directly without a full Express setup,
  // but we can simulate the hydration logic to see what it produces.
  const masterMeals = (plan as any).masterTemplate?.meals || [];
  console.log(`Total Master Meals available: ${masterMeals.length}`);

  // Test anchor
  let anchorMonday = new Date(); // Mocking getAnchorMonday() logic
  const day = anchorMonday.getUTCDay();
  const diff = anchorMonday.getUTCDate() - day + (day === 0 ? -6 : 1);
  anchorMonday.setUTCDate(diff);
  anchorMonday.setUTCHours(0, 0, 0, 0);
  
  let planStartDate = plan.startDate ? new Date(plan.startDate) : anchorMonday;
  planStartDate.setUTCHours(0, 0, 0, 0);
  console.log(`Plan Start Date: ${planStartDate.toISOString()}`);
  console.log(`Anchor Monday: ${anchorMonday.toISOString()}`);

  const projectedDates = [];
  for (let i = 0; i < 28; i++) {
    const targetDate = new Date(planStartDate);
    targetDate.setUTCDate(planStartDate.getUTCDate() + i);
    
    // Check cycle mapping
    const diffTime = targetDate.getTime() - anchorMonday.getTime();
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));
    
    const availableIndices = Array.from(new Set(masterMeals.map(m => (m as any).orderIndex)));
    const targetIndex = ((diffDays % 7) + 7) % 7; 
    
    const todaysMeals = masterMeals.filter(m => (m as any).orderIndex === targetIndex);
    if (i === 0) {
      console.log(`Day 0 (Plan Start) | Index: ${targetIndex} | Found Meals: ${todaysMeals.length}`);
    }
    if (todaysMeals.length > 0) projectedDates.push(targetDate);
  }
  
  console.log(`Total Days Projected with Meals: ${projectedDates.length}/28`);
}

testMobileSync().catch(console.error).finally(() => prisma.$disconnect());

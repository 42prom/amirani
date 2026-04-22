
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function checkRecentActivity() {
  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
  
  console.log("--- RECENT DIET PLANS ---");
  const plans = await prisma.dietPlan.findMany({
    where: { createdAt: { gte: tenMinutesAgo } },
    orderBy: { createdAt: 'desc' },
    include: {
      masterTemplate: {
        include: {
          meals: true
        }
      }
    }
  });

  if (plans.length === 0) {
    console.log("No new diet plans found in the last 10 minutes.");
    
    // Check if there are any PENDING jobs in the queue system? 
    // We don't have direct access to BullMQ Bull, but we can check the logs.
  } else {
    plans.forEach(p => {
      console.log(`Plan ID: ${p.id} | Active: ${p.isActive} | Created: ${p.createdAt.toISOString()}`);
      console.log(`  Master Meals: ${p.masterTemplate?.meals?.length ?? 0}`);
    });
  }

  console.log("\n--- RECENT JOBS (If stored in DB) ---");
  // Some systems store job status in a 'Job' table. Let's check for any 'Job' or 'Task' table.
}

checkRecentActivity().catch(console.error).finally(() => prisma.$disconnect());

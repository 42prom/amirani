
import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function checkAIUsageLogs() {
  console.log("--- SCANNING AI USAGE DATA ---");
  const logs = await prisma.aIUsage.findMany({
    orderBy: { createdAt: 'desc' },
    take: 10,
    include: { user: { select: { email: true } } }
  });

  if (logs.length === 0) {
    console.log("No AI usage records found. This usually means the generation didn't even start or crashed before logging.");
  } else {
    logs.forEach(l => {
      console.log(`[${l.createdAt.toISOString()}] User: ${l.user?.email || l.userId}`);
      console.log(`  Type: ${l.requestType} | Provider: ${l.provider} | Model: ${l.model}`);
      console.log(`  Usage: ${l.promptTokens} in / ${l.completionTokens} out`);
    });
  }

  console.log("\n--- SCANNING ACTIVE PLANS ---");
  const plans = await prisma.dietPlan.findMany({
    where: { isActive: true },
    orderBy: { createdAt: 'desc' },
    include: { masterTemplate: true }
  });
  
  if (plans.length > 0) {
    plans.forEach(p => {
       console.log(`Active Plan: ${p.id} | Name: ${p.name} | Created: ${p.createdAt.toISOString()}`);
    });
  } else {
    console.log("CRITICAL: ZERO Active plans found in the system. This implies the 'deactivate' worked but the 'create' failed.");
  }
}

checkAIUsageLogs().catch(console.error).finally(() => prisma.$disconnect());


const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function run() {
  console.log("--- SCANNING RECENT AI LOGS (RAW) ---");
  const logs = await prisma.aIUsage.findMany({
    orderBy: { createdAt: 'desc' },
    take: 10
  });
  console.log(JSON.stringify(logs, null, 2));

  console.log("--- RECENT DIET PLANS ---");
  const plans = await prisma.dietPlan.findMany({
    orderBy: { createdAt: 'desc' },
    take: 5
  });
  console.log(JSON.stringify(plans, null, 2));
}

run().catch(console.error).finally(() => prisma.$disconnect());

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('--- EXHAUSTIVE DB COUNT ---');
  
  const counts = {
    gyms: await prisma.gym.count(),
    users: await prisma.user.count(),
    memberships: await prisma.gymMembership.count(),
    plans: await prisma.subscriptionPlan.count(),
    trainers: await prisma.trainerProfile.count(),
    equipment: await prisma.equipment.count(),
    doorSystems: await prisma.doorSystem.count(),
    accessLogs: await prisma.doorAccessLog.count(),
    attendances: await prisma.attendance.count(),
  };
  
  console.log(JSON.stringify(counts, null, 2));
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

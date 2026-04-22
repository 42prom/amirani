import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('--- DETAILED GYM DIAGNOSTICS ---');
  
  const gyms = await prisma.gym.findMany({
    select: {
      id: true,
      name: true,
      ownerId: true,
      isActive: true
    }
  });
  
  console.log(`Total Gyms: ${gyms.length}`);
  console.log('Gym Details:', JSON.stringify(gyms, null, 2));
  
  const users = await prisma.user.findMany({
    select: {
      id: true,
      email: true,
      role: true,
      managedGymId: true
    }
  });
  
  console.log(`Total Users: ${users.length}`);
  console.log('User Details:', JSON.stringify(users, null, 2));
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

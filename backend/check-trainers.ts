import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const user = await prisma.user.findFirst({
    where: { fullName: { contains: 'Alex', mode: 'insensitive' } }
  });

  if (!user) {
    console.log('User Alex not found');
    return;
  }
  
  const membership = await prisma.gymMembership.findFirst({
    where: { userId: user.id, status: 'ACTIVE' },
    include: { gym: { include: { trainers: true } } }
  });

  if (!membership) {
    console.log('No active membership found for Alex');
    return;
  }

  const gym = membership.gym;
  console.log(`Gym found from Alex's membership: ${gym.name} (ID: ${gym.id})`);

  const responseJson = {
    id: gym.id,
    name: gym.name,
    address: gym.address,
    currentOccupancy: 1,
    maxCapacity: 0,
    registrationRequirements: gym.registrationRequirements,
    trainers: gym.trainers.map(t => ({
      id: t.id,
      fullName: t.fullName,
      specialization: t.specialization,
      bio: t.bio,
      avatarUrl: t.avatarUrl,
      isAvailable: t.isAvailable,
    })),
  };

  console.log('--- JSON Output ---');
  console.log(JSON.stringify(responseJson, null, 2));
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

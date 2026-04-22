import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const users = await prisma.user.findMany({
    where: { email: 'mobile@amirani.dev' },
    include: {
      memberships: {
        include: {
          gym: true,
          plan: true,
        },
      },
    },
  });

  console.log(JSON.stringify(users, null, 2));

  const gyms = await prisma.gym.findMany();
  console.log('Total Gyms:', gyms.length);
  gyms.forEach(g => console.log(`- ${g.name} (${g.id})`));
}

main()
  .catch(e => console.error(e))
  .finally(() => prisma.$disconnect());

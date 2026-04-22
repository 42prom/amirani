const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Listing all gyms...');
  const gyms = await prisma.gym.findMany({
    select: {
      id: true,
      name: true
    }
  });
  gyms.forEach(g => console.log(`ID: ${g.id} | Name: ${g.name}`));
}

main()
  .catch(e => console.error(e))
  .finally(async () => await prisma.$disconnect());

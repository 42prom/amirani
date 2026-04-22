const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  console.log('Checking gyms table for registrationRequirements column...');
  const gyms = await prisma.gym.findMany({ take: 1 });
  console.log('Sample gym data:', JSON.stringify(gyms, null, 2));
}

main()
  .catch(e => {
    console.error('VERIFICATION FAILED:', e.message);
    process.exit(1);
  })
  .finally(async () => await prisma.$disconnect());

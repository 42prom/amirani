import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  console.log('Verifying branches...');
  const branches = await (prisma as any).branch.findMany();
  console.log('Branches found:', branches);

  console.log('Verifying weight history...');
  const weights = await (prisma as any).userWeightHistory.findMany();
  console.log('Weight records found:', weights.length);
  
  await prisma.$disconnect();
}

main().catch(console.error);

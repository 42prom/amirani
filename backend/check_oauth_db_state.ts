import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  try {
    const cfg = await (prisma as any).oAuthConfig.findUnique({ where: { id: 'singleton' } });
    console.log('OAuth Config:', JSON.stringify(cfg, null, 2));
    
    // Also check if any users exist to see if DB is generally healthy
    const userCount = await prisma.user.count();
    console.log('Total Users:', userCount);
    
  } catch (err) {
    console.error('Error checking config:', err);
  } finally {
    await prisma.$disconnect();
  }
}

main();

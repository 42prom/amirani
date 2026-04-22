import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  try {
    const oauth = await (prisma as any).oAuthConfig.findUnique({ where: { id: 'singleton' } });
    console.log('--- OAUTH CONFIG START ---');
    console.log(JSON.stringify(oauth, null, 2));
    console.log('--- OAUTH CONFIG END ---');
  } catch (err: any) {
    console.error('Error:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

main();

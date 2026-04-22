import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const cfg = await (prisma as any).oAuthConfig.findUnique({ where: { id: 'singleton' } });
  console.log('GOOGLE_ENABLED:', cfg?.googleEnabled);
  console.log('GOOGLE_CLIENT_ID:', cfg?.googleClientId?.substring(0, 10) + '...');
  console.log('GOOGLE_HAS_SECRET:', !!cfg?.googleClientSecret);
  console.log('APPLE_ENABLED:', cfg?.appleEnabled);
  console.log('APPLE_CLIENT_ID:', cfg?.appleClientId);
  await prisma.$disconnect();
}
main();

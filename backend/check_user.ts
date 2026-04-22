import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function main() {
  const user = await prisma.user.findFirst({ where: { email: 'wisario@mail.com' } });
  console.log('USER_DATA_START');
  console.log(JSON.stringify(user, null, 2));
  console.log('USER_DATA_END');
  await prisma.$disconnect();
}
main().catch(e => { console.error(e); process.exit(1); });

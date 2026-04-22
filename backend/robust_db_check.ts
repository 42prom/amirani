import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';

const prisma = new PrismaClient();

async function main() {
  const result: any = {};
  try {
    const oauth = await (prisma as any).oAuthConfig.findUnique({ where: { id: 'singleton' } });
    result.oauth = oauth;
    result.userCount = await prisma.user.count();
    result.latestUsers = await prisma.user.findMany({
      orderBy: { createdAt: 'desc' },
      take: 5,
      select: { email: true, role: true, createdAt: true }
    });
    fs.writeFileSync('db_check_result.json', JSON.stringify(result, null, 2));
    console.log('Result saved to db_check_result.json');
  } catch (err: any) {
    fs.writeFileSync('db_check_error.txt', err.message + '\n' + err.stack);
    console.error('Error:', err);
  } finally {
    await prisma.$disconnect();
  }
}

main();

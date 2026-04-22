import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const logs = await prisma.auditLog.findMany({
    where: { entity: 'AIConfig' },
    orderBy: { createdAt: 'desc' },
    take: 10
  });
  
  console.log('Last 10 AIConfig Audit Logs:');
  logs.forEach((l: any) => {
    console.log(`[${l.createdAt.toISOString()}] Action: ${l.action}, Actor: ${l.actorId}`);
    if (l.metadata) {
       const meta = typeof l.metadata === 'string' ? JSON.parse(l.metadata) : l.metadata;
       const keys = Object.keys(meta);
       console.log(`   Fields Updated: ${keys.join(', ')}`);
    }
  });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

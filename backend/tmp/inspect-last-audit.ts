import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const lastLog = await prisma.auditLog.findFirst({
    where: { action: 'AI_CONFIG_UPDATE' },
    orderBy: { createdAt: 'desc' }
  });
  
  if (lastLog) {
    console.log('--- Last AI Config Audit Log ---');
    console.log(`Time: ${lastLog.createdAt.toISOString()}`);
    console.log(`Action: ${lastLog.action}`);
    console.log(`Label: ${lastLog.label}`);
    
    if (lastLog.metadata) {
      const meta = typeof lastLog.metadata === 'string' ? JSON.parse(lastLog.metadata) : lastLog.metadata;
      // Mask for logging to avoid exposing key in my logs, but check prefix/suffix
      for (const [key, val] of Object.entries(meta)) {
        if (typeof val === 'string' && val.length > 5) {
          console.log(`${key}: ...${val.substring(val.length - 4)} (Length: ${val.length})`);
        } else {
          console.log(`${key}: ${val}`);
        }
      }
    }
  } else {
    console.log('No AI Config Audit logs found.');
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

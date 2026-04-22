const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    // AuditLog might be 'audit_logs' or something else. I'll search via prisma keys
    const keys = Object.keys(prisma).filter(k => k.toLowerCase().includes('audit'));
    console.log('PRISMA_AUDIT_KEYS:', JSON.stringify(keys));
    if (keys.length > 0) {
      const model = keys[0];
      const logs = await prisma[model].findMany({
        orderBy: { createdAt: 'desc' },
        take: 20
      });
      console.log('AUDIT_LOGS:', JSON.stringify(logs, null, 2));
    } else {
      console.log('No Audit model found via reflection.');
    }
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}
main();

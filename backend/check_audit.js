const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const logs = await prisma.auditLog.findMany({
      where: { resource: { contains: 'oauth', mode: 'insensitive' } },
      orderBy: { createdAt: 'desc' },
      take: 10
    });
    console.log('AUDIT_LOGS:', JSON.stringify(logs, null, 2));
  } catch (err) {
    console.error('Error fetching logs:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}
main();

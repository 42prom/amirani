const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const cfg = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
  console.log('CFG:', JSON.stringify(cfg, null, 2));
  process.exit(0);
}
main();

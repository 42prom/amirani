const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const config = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
    if (config) {
      process.stdout.write(config.googleClientId);
    } else {
      console.log('NOT_FOUND');
    }
  } catch (err) {
    console.error(err);
  } finally {
    await prisma.$disconnect();
  }
}
main();

const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const cfg = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
  if (!cfg) {
    console.log('No OAuth config found!');
  } else {
    const id = cfg.googleClientId;
    console.log('ID: "' + id + '"');
    console.log('LENGTH:', id.length);
    console.log('TRIMMED_LENGTH:', id.trim().length);
    if (id !== id.trim()) {
      console.log('WARNING: TRAILING OR LEADING SPACES DETECTED!');
    }
  }
  process.exit(0);
}
main();

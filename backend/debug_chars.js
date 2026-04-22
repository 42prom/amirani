const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const cfg = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
  if (!cfg) {
    console.log('No OAuth config found!');
  } else {
    const id = cfg.googleClientId;
    console.log('ID: ' + id);
    let codes = [];
    for (let i = 0; i < id.length; i++) {
      codes.push(id.charCodeAt(i));
    }
    console.log('CODES:', JSON.stringify(codes));
    console.log('TRIMMED_CODES:', JSON.stringify(id.trim().split('').map(c => c.charCodeAt(0))));
  }
  process.exit(0);
}
main();

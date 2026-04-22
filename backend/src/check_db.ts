import prisma from './lib/prisma';
import fs from 'fs';

async function main() {
  try {
    const prismaAny = prisma as any;
    const config = await prismaAny.oAuthConfig.findUnique({
      where: { id: 'singleton' },
    });
    const output = JSON.stringify(config, null, 2);
    fs.writeFileSync('db_results.txt', output);
    console.log('Results written to db_results.txt');
  } catch (err: any) {
    fs.writeFileSync('db_results.txt', 'Error: ' + err.message);
  } finally {
    process.exit(0);
  }
}

main();

import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const config = await prisma.aIConfig.findFirst({ where: { id: 'singleton' } });
  
  if (config) {
    console.log('--- AI Configuration Check ---');
    console.log(`Provider: ${config.activeProvider}`);
    console.log(`Enabled: ${config.isEnabled}`);
    
    if (config.deepseekApiKey) {
      console.log(`DeepSeek Key Length: ${config.deepseekApiKey.length}`);
      console.log(`DeepSeek Key Starts: ${config.deepseekApiKey.substring(0, 10)}...`);
      console.log(`DeepSeek Key Ends: ...${config.deepseekApiKey.substring(config.deepseekApiKey.length - 4)}`);
    } else {
      console.log('DeepSeek Key: MISSING');
    }
  } else {
    console.log('AI Configuration: NOT FOUND');
  }
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

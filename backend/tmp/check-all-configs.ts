import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const configs = await prisma.aIConfig.findMany();
  
  console.log(`Found ${configs.length} AI configurations:`);
  configs.forEach(c => {
    console.log(`ID: ${c.id}, Provider: ${c.activeProvider}, Enabled: ${c.isEnabled}`);
    if (c.deepseekApiKey) {
      console.log(`   DeepSeek Key: ...${c.deepseekApiKey.substring(c.deepseekApiKey.length - 4)} (Length: ${c.deepseekApiKey.length})`);
    }
  });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());

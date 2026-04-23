/// <reference types="node" />
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

/**
 * Seeds the platform AIConfig record.
 *
 * IMPORTANT: This is the single source of truth for all AI API keys on the platform.
 * The BullMQ workers (in lib/queue.ts) read `prisma.aIConfig.findFirst({ isEnabled: true })`
 * before every AI generation job.
 *
 * HOW TO ACTIVATE:
 *   1. Set DEEPSEEK_API_KEY in your .env file
 *   2. Run: npx ts-node prisma/ai-config-seed.ts
 *
 * To switch provider: update `activeProvider` and set the corresponding key.
 */
export async function seedAIConfig() {
  const deepseekKey = process.env.DEEPSEEK_API_KEY || 'MOCK_KEY_PLEASE_SET_IN_ENV';

  if (!process.env.DEEPSEEK_API_KEY) {
    console.log('   ⚠️  DEEPSEEK_API_KEY not set — using placeholder for record initialization.');
  }

  console.log('🤖 Seeding AIConfig (DeepSeek)...');

  // Upsert is safe — running seed multiple times won't duplicate the config
  const config = await (prisma as any).aIConfig.upsert({
    where: { id: 'singleton' },
    create: {
      id: 'singleton',
      isEnabled: true,
      activeProvider: 'DEEPSEEK',

      // DeepSeek configuration
      deepseekApiKey: deepseekKey,
      deepseekBaseUrl: 'https://api.deepseek.com/v1',
      deepseekModel: 'deepseek-chat',

      // Safety limits
      maxTokensPerRequest: 8192,
      temperature: 0.7,
    },
    update: {
      // Sync key and enabled status on re-run
      deepseekApiKey: deepseekKey,
      isEnabled: true,
      activeProvider: 'DEEPSEEK',
    },
  });

  console.log(`   ✓ AIConfig active: provider=${config.activeProvider}, model=${config.deepseekModel}`);
  console.log(`   ✓ Max ${config.maxTokensPerRequest} tokens / ${config.maxRequestsPerUserPerDay} requests per user per day`);
  return config;
}

// Run standalone: npx ts-node prisma/ai-config-seed.ts
if (require.main === module) {
  seedAIConfig()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
}

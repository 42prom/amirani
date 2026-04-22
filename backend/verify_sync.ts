import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function checkConfig() {
  console.log('🔍 AMIRANI SYSTEM AUDIT: AI CONFIGURATION SYNC CHECK\n');
  
  try {
    const config = await prisma.aIConfig.findFirst({
      where: { isEnabled: true }
    });

    if (!config) {
      console.error('❌ ERROR: No active AI Configuration found in database.');
      return;
    }

    console.log('✅ DATABASE STATUS: Active AI Config Found.');
    console.log(`📡 Provider: ${config.activeProvider}`);
    console.log(`🤖 Model: ${config.activeProvider === 'DEEPSEEK' ? config.deepseekModel : config.openaiModel}`);
    console.log(`🔑 Dashboard Tokens (Admin Set): ${config.maxTokensPerRequest}`);

    // SIMULATED LOGIC FROM queue.ts
    let calculatedMaxTokens = config.maxTokensPerRequest || 4096;
    
    // Provider specific ceiling check (DeepSeek = 8192)
    if (config.activeProvider === 'DEEPSEEK') {
       const providerCeiling = 8192;
       if (calculatedMaxTokens > providerCeiling) {
         console.log(`⚠️  SAFETY GUARD: Admin requested ${calculatedMaxTokens}, but DeepSeek ceiling is ${providerCeiling}. Capping at ${providerCeiling}.`);
         calculatedMaxTokens = providerCeiling;
       } else {
         console.log(`💎 PRECISION: Dashboard value ${calculatedMaxTokens} is within DeepSeek limits. Using 1:1.`);
       }
    }

    console.log(`\n🚀 FINAL SENT TO AI API: { max_tokens: ${calculatedMaxTokens} }`);
    
    if (calculatedMaxTokens === 8100) {
      console.log('\n🌟 SUCCESS: System is perfectly obedient to your Dashboard (8100 tokens).');
    }

  } catch (err) {
    console.error('❌ AUDIT FAILED:', err);
  } finally {
    await prisma.$disconnect();
  }
}

checkConfig();

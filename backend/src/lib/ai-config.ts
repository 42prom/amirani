import prisma from './prisma';
import { decryptField } from './db-crypto';

let _aiConfigCache: any = null;

export async function getAiConfig() {
  if (_aiConfigCache && Date.now() < _aiConfigCache.expiresAt) return _aiConfigCache.value;
  
  const cfg = await prisma.aIConfig.findFirst({ 
    where: { isEnabled: true }, 
    orderBy: { updatedAt: 'desc' } 
  });
  
  if (!cfg) return null;
  
  const dec = { 
    ...cfg, 
    openaiApiKey: decryptField(cfg.openaiApiKey), 
    anthropicApiKey: decryptField(cfg.anthropicApiKey), 
    deepseekApiKey: decryptField(cfg.deepseekApiKey) 
  };
  
  _aiConfigCache = { value: dec, expiresAt: Date.now() + 60000 }; // 1 minute cache
  return dec;
}

export function resolveModelName(aiConfig: any) {
  return aiConfig.openaiModel || aiConfig.anthropicModel || aiConfig.deepseekModel || 'unknown';
}

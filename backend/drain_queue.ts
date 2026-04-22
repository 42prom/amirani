import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import config from './src/config/env';

const connection = new IORedis(config.redis.url, { maxRetriesPerRequest: null });

async function drainQueues() {
  const queues = ['ai-workout-generation', 'ai-diet-generation'];
  
  for (const qName of queues) {
    const q = new Queue(qName, { connection: connection as any });
    console.log(`🧹 Draining Queue: ${qName}...`);
    
    // Obscure: BullMQ drain removes waiting but we need to remove stalled/active cases
    await q.obliterate({ force: true });
    console.log(`✅ Queue ${qName} OBLITERATED.`);
  }
}

drainQueues()
  .then(() => console.log('🚀 SYSTEM PURGE COMPLETE. QUEUES ARE EMPTY.'))
  .catch(console.error)
  .finally(() => connection.quit());

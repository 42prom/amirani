
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import config from './src/config/env';

const connection = new IORedis(config.redisUrl, { maxRetriesPerRequest: null });

async function checkJobs() {
  const queues = ['ai-workout-generation', 'ai-diet-generation'];
  
  for (const qName of queues) {
    const q = new Queue(qName, { connection });
    const waiting = await q.getWaiting();
    const active = await q.getActive();
    
    console.log(`--- Q: ${qName} ---`);
    console.log(`Waiting: ${waiting.length} | Active: ${active.length}`);
    
    [...waiting, ...active].forEach(j => {
      console.log(`Job ID: ${j.id} | Age: ${((Date.now() - j.timestamp) / 1000).toFixed(0)}s | Failed: ${j.failedReason ?? 'none'}`);
    });
  }
}

checkJobs().catch(console.error).finally(() => connection.quit());

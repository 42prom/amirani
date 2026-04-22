
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import config from './src/config/env';

const connection = new IORedis(config.redis.url, { maxRetriesPerRequest: null });

async function checkQueueStatus() {
  const queues = ['ai-workout-generation', 'ai-diet-generation'];
  
  for (const qName of queues) {
    const q = new Queue(qName, { connection: connection as any });
    const counts = await q.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed');
    console.log(`--- Queue: ${qName} ---`);
    console.log(JSON.stringify(counts, null, 2));
    
    const active = await q.getActive();
    if (active.length > 0) {
      console.log(`Active Jobs: ${active.length}`);
      active.forEach(j => {
        const age = (Date.now() - (j.timestamp || 0)) / 1000;
        console.log(`  Job ID: ${j.id} | User: ${j.data?.userId} | Age: ${age.toFixed(1)}s`);
      });
    }
  }
}

checkQueueStatus().catch(console.error).finally(() => connection.quit());

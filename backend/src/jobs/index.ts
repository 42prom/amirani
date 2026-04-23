import { Job } from 'bullmq';
import { aiWorkoutQueue, aiDietQueue } from './queue.config';
import logger from '../lib/logger';

export * from './queue.config';
export * from './processors/ai-job.processor';
export * from './processors/push-notification.processor';

export type JobStatus = 'QUEUED' | 'PROCESSING' | 'COMPLETED' | 'FAILED';

export function stateToStatus(state: string): JobStatus {
  switch (state) {
    case 'completed': return 'COMPLETED';
    case 'failed':    return 'FAILED';
    case 'active':    return 'PROCESSING';
    default:          return 'QUEUED';
  }
}

export async function enqueueAiPlanGeneration(type: 'WORKOUT' | 'DIET' | 'BOTH', payload: any): Promise<{ jobId: string; dietJobId?: string }> {
  if (type === 'BOTH') {
    const w = await aiWorkoutQueue.add('generate-workout', payload, { priority: 1, jobId: `ai-workout-${payload.userId}` });
    const d = await aiDietQueue.add('generate-diet', payload, { priority: 1, jobId: `ai-diet-${payload.userId}` });
    return { jobId: w.id!, dietJobId: d.id! };
  }
  const q = type === 'DIET' ? aiDietQueue : aiWorkoutQueue;
  const id = `ai-${type.toLowerCase()}-${payload.userId}`;
  const job = await q.add(`generate-${type.toLowerCase()}`, payload, { priority: 1, jobId: id });
  return { jobId: job.id! };
}

export async function enqueueAiJobStatus(jobId: string, type: 'WORKOUT' | 'DIET' | 'BOTH'): Promise<any> {
  const q = type === 'DIET' ? aiDietQueue : aiWorkoutQueue;
  const job = await q.getJob(jobId);
  if (!job) return { status: 'FAILED', error: 'Job not found' };
  const state = await job.getState();
  const progress = job.progress;
  const progressNumber = typeof progress === 'number' ? progress : (progress as any)?.progress;
  const progressMessage = (progress as any)?.message;
  return {
    status: stateToStatus(state),
    progress: progressNumber,
    message: progressMessage,
    result: state === 'completed' ? job.returnvalue : undefined,
    error: state === 'failed' ? (job.failedReason ?? 'Unknown error') : undefined,
  };
}

/**
 * Shared ioredis client — singleton used across rate limiters, leaderboard, and any
 * module that needs a plain Redis connection (not BullMQ's internal connection).
 *
 * BullMQ maintains its own internal connection; do NOT pass this client to BullMQ.
 * For BullMQ, use the `connection` object exported from jobs/queue.ts.
 */
import IORedis from 'ioredis';
import config from '../config/env';

let _client: IORedis | null = null;

/**
 * Returns the shared ioredis singleton.
 * Creates it on first call; subsequent calls return the cached instance.
 */
export function getRedisClient(): IORedis {
  if (!_client) {
    _client = new IORedis(config.redis.url, {
      maxRetriesPerRequest: null, // required by BullMQ-style pattern; benign here
      lazyConnect: true,
      enableOfflineQueue: false,  // fail fast when Redis is down, don't queue commands
    });

    _client.on('error', (err) => {
      // Log but don't crash — rate limiters fall back to in-memory on Redis failure
      // eslint-disable-next-line no-console
      console.error('[Redis] Connection error:', err.message);
    });
  }
  return _client;
}

/**
 * Gracefully disconnect the shared client (called during graceful shutdown).
 */
export async function disconnectRedisClient(): Promise<void> {
  if (_client) {
    await _client.quit().catch(() => {}); // ignore errors on shutdown
    _client = null;
  }
}

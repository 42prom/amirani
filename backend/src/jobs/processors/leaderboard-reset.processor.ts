import IORedis from 'ioredis';
import config from '../../config/env';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';

let _redis: IORedis | null = null;

function getRedis(): IORedis {
  if (!_redis) {
    _redis = new IORedis(config.redis.url, { maxRetriesPerRequest: null, lazyConnect: true });
  }
  return _redis;
}

export async function processLeaderboardReset() {
  logger.info('[LEADERBOARD_RESET] Starting weekly reset');

  // Reset weeklyPoints for all memberships in active rooms
  const updated = await prisma.roomMembership.updateMany({
    where: { room: { isActive: true } },
    data:  { weeklyPoints: 0 },
  });

  // Clear Redis week keys so they rebuild from fresh DB state
  const redis = getRedis();
  const keys = await redis.keys('leaderboard:week:*');
  if (keys.length > 0) {
    await redis.del(...keys);
  }

  logger.info('[LEADERBOARD_RESET] Weekly reset complete', {
    membershipsReset: updated.count,
    redisKeysCleared: keys.length,
  });
}

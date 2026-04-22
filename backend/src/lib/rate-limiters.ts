import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { getRedisClient } from './redis';

const RL_MSG = (msg: string) => ({
  success: false,
  error: { code: 'RATE_LIMITED', message: msg },
});

/**
 * Build a RedisStore backed by the shared ioredis client.
 * Falls back to in-memory store if Redis is unavailable (dev without Redis).
 */
function makeStore(prefix: string): RedisStore | undefined {
  try {
    const client = getRedisClient();
    return new RedisStore({
      // rate-limit-redis v4 expects a sendCommand callback
      sendCommand: (...args: string[]) => (client as any).sendCommand(args),
      prefix: `rl:${prefix}:`,
    });
  } catch {
    // Redis not ready — fall back to default in-memory store (dev only)
    return undefined;
  }
}

// Global: 300 req / IP / 15 min
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeStore('global'),
  message: RL_MSG('Too many requests, please try again later.'),
});

// Login / OAuth: 10 attempts / IP / 15 min — brute-force protection
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeStore('login'),
  message: RL_MSG('Too many login attempts, please try again in 15 minutes.'),
});

// Registration: 5 accounts / IP / hour — spam account creation protection
export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeStore('register'),
  message: RL_MSG('Too many registration attempts, please try again later.'),
});

// Password change / reset: 10 / IP / 15 min
export const passwordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  store: makeStore('password'),
  message: RL_MSG('Too many password change attempts, please try again later.'),
});

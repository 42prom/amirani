import rateLimit from 'express-rate-limit';

const RL_MSG = (msg: string) => ({
  success: false,
  error: { code: 'RATE_LIMITED', message: msg },
});

// Global: 300 req / IP / 15 min
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: RL_MSG('Too many requests, please try again later.'),
});

// Login / OAuth: 10 attempts / IP / 15 min — brute-force protection
export const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: RL_MSG('Too many login attempts, please try again in 15 minutes.'),
});

// Registration: 5 accounts / IP / hour — spam account creation protection
export const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: RL_MSG('Too many registration attempts, please try again later.'),
});

// Password change / reset: 10 / IP / 15 min
export const passwordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: RL_MSG('Too many password change attempts, please try again later.'),
});

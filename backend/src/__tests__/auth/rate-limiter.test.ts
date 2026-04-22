import { describe, it, expect, vi } from 'vitest';
import request from 'supertest';
import express from 'express';
import { loginLimiter, registerLimiter } from '../../lib/rate-limiters';

vi.mock('../../lib/prisma', () => ({
  default: {
    user: { findUnique: vi.fn().mockResolvedValue(null) },
    refreshToken: { create: vi.fn(), deleteMany: vi.fn() },
    $extends: vi.fn().mockReturnThis(),
  },
}));

vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    cors: { allowedOrigins: [] },
    stripe: { webhookSecret: '' },
    port: 3000,
    nodeEnv: 'test',
    frontendUrl: 'http://localhost:3000',
  },
}));

describe('Rate limiter middleware', () => {
  it('loginLimiter allows requests up to max then blocks', async () => {
    const app = express();
    app.use(express.json());
    // Minimal endpoint that just returns 200 to isolate limiter behaviour
    app.post('/login', loginLimiter, (_req, res) => res.status(200).json({ ok: true }));

    // Send max requests (10) — all should pass
    for (let i = 0; i < 10; i++) {
      const res = await request(app).post('/login').send({});
      expect(res.status).toBe(200);
    }

    // 11th request should be rate-limited
    const blocked = await request(app).post('/login').send({});
    expect(blocked.status).toBe(429);
    expect(blocked.body.error?.code).toBe('RATE_LIMITED');
  });

  it('registerLimiter allows requests up to max then blocks', async () => {
    const app = express();
    app.use(express.json());
    app.post('/register', registerLimiter, (_req, res) => res.status(200).json({ ok: true }));

    for (let i = 0; i < 5; i++) {
      const res = await request(app).post('/register').send({});
      expect(res.status).toBe(200);
    }

    const blocked = await request(app).post('/register').send({});
    expect(blocked.status).toBe(429);
    expect(blocked.body.error?.code).toBe('RATE_LIMITED');
  });

  it('rate limit response includes standard RateLimit headers', async () => {
    const app = express();
    app.use(express.json());
    app.post('/test', loginLimiter, (_req, res) => res.status(200).json({ ok: true }));

    const res = await request(app).post('/test').send({});
    expect(res.headers).toHaveProperty('ratelimit-limit');
    expect(res.headers).toHaveProperty('ratelimit-remaining');
  });
});


import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import express from 'express';
import { randomUUID } from 'crypto';

// ── Prisma mock ───────────────────────────────────────────────────────────────
vi.mock('../../lib/prisma', () => ({
  default: {
    user: {
      findUnique: vi.fn(),
      findFirst: vi.fn(),
      create: vi.fn(),
    },
    refreshToken: {
      create: vi.fn(),
      findUnique: vi.fn(),
      delete: vi.fn(),
      deleteMany: vi.fn(),
    },
    invitation: {
      findUnique: vi.fn(),
      update: vi.fn(),
    },
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

import prisma from '../../lib/prisma';
import authRoutes from '../../modules/auth/auth.controller';

function buildApp() {
  const app = express();
  app.use(express.json());
  app.use('/auth', authRoutes);
  return app;
}

const mockUser = {
  id: randomUUID(),
  email: 'test@example.com',
  password: '$2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewWDAfBwTWUf0Uu2', // 'password123'
  fullName: 'Test User',
  role: 'GYM_MEMBER',
  isVerified: true,
  isActive: true,
  managedGymId: null,
  avatarUrl: null,
  phoneNumber: null,
  gender: null,
  dob: null,
  weight: null,
  height: null,
  medicalConditions: null,
  noMedicalConditions: false,
  personalNumber: null,
  address: null,
  idPhotoUrl: null,
  totalPoints: 0,
  streakDays: 0,
  mustChangePassword: false,
};

describe('POST /auth/login', () => {
  beforeEach(() => vi.clearAllMocks());

  it('returns 422 when email is missing', async () => {
    const app = buildApp();
    const res = await request(app).post('/auth/login').send({ password: 'pass' });
    expect(res.status).toBe(422);
  });

  it('returns 422 when password is missing', async () => {
    const app = buildApp();
    const res = await request(app).post('/auth/login').send({ email: 'a@b.com' });
    expect(res.status).toBe(422);
  });

  it('returns 401 when user does not exist', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(null);
    const app = buildApp();
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'nobody@example.com', password: 'password123' });
    expect(res.status).toBe(401);
  });

  it('returns 401 when password is wrong', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockUser as any);
    const app = buildApp();
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'test@example.com', password: 'wrongpassword' });
    expect(res.status).toBe(401);
  });

  it('returns 401 when account is deactivated', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({ ...mockUser, isActive: false } as any);
    const app = buildApp();
    const res = await request(app)
      .post('/auth/login')
      .send({ email: 'test@example.com', password: 'password123' });
    expect(res.status).toBe(401);
  });
});

describe('POST /auth/register', () => {
  beforeEach(() => vi.clearAllMocks());

  it('returns 422 when required fields are missing', async () => {
    const app = buildApp();
    const res = await request(app).post('/auth/register').send({ email: 'a@b.com' });
    expect(res.status).toBe(422);
  });

  it('returns 409 when email is already registered', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockUser as any);
    const app = buildApp();
    const res = await request(app).post('/auth/register').send({
      email: 'test@example.com',
      password: 'Password123!',
      fullName: 'Test User',
    });
    expect(res.status).toBe(409);
  });
});

describe('GET /auth/me', () => {
  it('returns 401 when no Authorization header', async () => {
    const app = buildApp();
    const res = await request(app).get('/auth/me');
    expect(res.status).toBe(401);
  });

  it('returns 401 with an invalid token', async () => {
    const app = buildApp();
    const res = await request(app)
      .get('/auth/me')
      .set('Authorization', 'Bearer not.a.valid.token');
    expect(res.status).toBe(401);
  });
});


import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import express from 'express';

// ── Hoisted mock handles ──────────────────────────────────────────────────────
const mocks = vi.hoisted(() => ({
  packFindMany:    vi.fn(),
  packGroupBy:     vi.fn(),
  packFindFirst:   vi.fn(),
  packUpdate:      vi.fn(),
  packUpdateMany:  vi.fn(),
  packCount:       vi.fn(),
  transaction:     vi.fn(),
  queueAdd:        vi.fn(),
}));

// ── Config mock ───────────────────────────────────────────────────────────────
vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    redis: { url: 'redis://localhost:6379' },
    port: 3000,
    nodeEnv: 'test',
  },
}));

// ── Prisma mock ───────────────────────────────────────────────────────────────
vi.mock('../../lib/prisma', () => ({
  default: {
    languagePack: {
      findMany:   mocks.packFindMany,
      groupBy:    mocks.packGroupBy,
      findFirst:  mocks.packFindFirst,
      update:     mocks.packUpdate,
      updateMany: mocks.packUpdateMany,
      count:      mocks.packCount,
    },
    $transaction: mocks.transaction,
  },
}));

// ── BullMQ queue mock ─────────────────────────────────────────────────────────
vi.mock('../../jobs/queue.config', () => ({
  langPackGenerateQueue: { add: mocks.queueAdd },
  redisConnection: {},
}));

// ── Auth middleware mock — always passes as SUPER_ADMIN ───────────────────────
vi.mock('../../middleware/auth.middleware', () => ({
  authenticate:    (_req: any, _res: any, next: any) => {
    _req.user = { userId: 'admin-1', role: 'SUPER_ADMIN' };
    next();
  },
  superAdminOnly:  (_req: any, _res: any, next: any) => next(),
}));

vi.mock('../../lib/logger', () => ({
  default: { info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}));

import langPacksRouter from '../../modules/admin/language-packs.controller';

// ─── Test app ─────────────────────────────────────────────────────────────────

const app = express();
app.use(express.json());
app.use('/admin/language-packs', langPacksRouter);

// ─────────────────────────────────────────────────────────────────────────────

describe('GET /admin/language-packs', () => {
  beforeEach(() => vi.clearAllMocks());

  it('returns list of language packs', async () => {
    const pack = { id: 'p1', language: 'KA', data: { _meta: { displayName: 'Georgian' } }, version: 1, isSystemDefault: true, updatedAt: new Date() };
    mocks.packFindMany.mockResolvedValue([pack]);
    mocks.packGroupBy.mockResolvedValue([{ language: 'KA', _count: { gymId: 3 } }]);

    const res = await request(app).get('/admin/language-packs');

    expect(res.status).toBe(200);
    expect(res.body.data.packs).toHaveLength(1);
    expect(res.body.data.packs[0].code).toBe('ka');
    expect(res.body.data.packs[0].gymCount).toBe(3);
  });

  it('returns empty array when no packs exist', async () => {
    mocks.packFindMany.mockResolvedValue([]);
    mocks.packGroupBy.mockResolvedValue([]);

    const res = await request(app).get('/admin/language-packs');

    expect(res.status).toBe(200);
    expect(res.body.data.packs).toEqual([]);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe('GET /admin/language-packs/:code', () => {
  beforeEach(() => vi.clearAllMocks());

  it('returns pack detail with translation rows', async () => {
    const pack = {
      id: 'p1', language: 'KA',
      data: { 'button.save': 'შენახვა', _meta: { displayName: 'Georgian' } },
      version: 2, isSystemDefault: true,
    };
    mocks.packFindFirst.mockResolvedValue(pack);
    mocks.packCount.mockResolvedValue(5);

    const res = await request(app).get('/admin/language-packs/ka');

    expect(res.status).toBe(200);
    const body = res.body.data;
    expect(body.code).toBe('ka');
    expect(body.rows).toBeInstanceOf(Array);
    const saveRow = body.rows.find((r: any) => r.key === 'button.save');
    expect(saveRow.translation).toBe('შენახვა');
    expect(saveRow.isMissing).toBe(false);
  });

  it('returns 404 when pack does not exist', async () => {
    mocks.packFindFirst.mockResolvedValue(null);

    const res = await request(app).get('/admin/language-packs/zz');

    expect(res.status).toBe(404);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe('PATCH /admin/language-packs/:code — version bump on save', () => {
  beforeEach(() => vi.clearAllMocks());

  it('increments version when translations are saved', async () => {
    const existing = { id: 'p1', language: 'KA', data: {}, version: 3, isSystemDefault: false };
    mocks.packFindFirst.mockResolvedValue(existing);
    mocks.packCount.mockResolvedValue(0);
    const updated = { ...existing, version: 4 };
    mocks.packUpdate.mockResolvedValue(updated);

    const res = await request(app)
      .patch('/admin/language-packs/ka')
      .send({ translations: { 'button.save': 'შენახვა' } });

    expect(res.status).toBe(200);
    expect(mocks.packUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'p1' },
        data:  expect.objectContaining({ version: { increment: 1 } }),
      }),
    );
  });

  it('toggles isPublished without changing version', async () => {
    const existing = { id: 'p1', language: 'KA', data: {}, version: 2, isSystemDefault: false };
    mocks.packFindFirst.mockResolvedValue(existing);
    mocks.packCount.mockResolvedValue(0);
    mocks.packUpdate.mockResolvedValue({ ...existing, isSystemDefault: true });

    const res = await request(app)
      .patch('/admin/language-packs/ka')
      .send({ isPublished: true });

    expect(res.status).toBe(200);
    expect(mocks.packUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { isSystemDefault: true },
      }),
    );
  });

  it('returns 400 when neither translations nor isPublished is provided', async () => {
    const existing = { id: 'p1', language: 'KA', data: {}, version: 1, isSystemDefault: false };
    mocks.packFindFirst.mockResolvedValue(existing);
    mocks.packCount.mockResolvedValue(0);

    const res = await request(app)
      .patch('/admin/language-packs/ka')
      .send({});

    expect(res.status).toBe(400);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe('POST /admin/language-packs/:code/push — propagation', () => {
  beforeEach(() => vi.clearAllMocks());

  it('propagates system pack data to all gym-specific packs', async () => {
    const systemPack = { id: 'p1', language: 'KA', data: { 'button.save': 'შენახვა' }, version: 5, isSystemDefault: true };
    mocks.packFindFirst.mockResolvedValue(systemPack);
    mocks.transaction.mockResolvedValue([{}, { count: 4 }]);

    const res = await request(app).post('/admin/language-packs/ka/push');

    expect(res.status).toBe(200);
    expect(res.body.data.pushed).toBe(4);
    expect(res.body.data.published).toBe(true);

    const txOps = mocks.transaction.mock.calls[0][0];
    expect(txOps).toHaveLength(2);
  });

  it('returns 404 when no system pack exists for the language', async () => {
    mocks.packFindFirst.mockResolvedValue(null);

    const res = await request(app).post('/admin/language-packs/zz/push');

    expect(res.status).toBe(404);
  });
});

// ─────────────────────────────────────────────────────────────────────────────

describe('POST /admin/language-packs/ai-generate — queues job', () => {
  beforeEach(() => vi.clearAllMocks());

  it('returns queued job id when language does not exist yet', async () => {
    mocks.packFindFirst.mockResolvedValue(null);
    mocks.queueAdd.mockResolvedValue({ id: 'job-42' });

    const res = await request(app)
      .post('/admin/language-packs/ai-generate')
      .send({ targetLanguage: 'Georgian', languageCode: 'KA', countryCode: 'ge' });

    expect(res.status).toBe(200);
    expect(res.body.data.jobId).toBe('job-42');
    expect(res.body.data.status).toBe('queued');
  });

  it('returns 400 when pack already exists', async () => {
    mocks.packFindFirst.mockResolvedValue({ id: 'p1', language: 'KA' });

    const res = await request(app)
      .post('/admin/language-packs/ai-generate')
      .send({ targetLanguage: 'Georgian', languageCode: 'KA' });

    expect(res.status).toBe(400);
    expect(mocks.queueAdd).not.toHaveBeenCalled();
  });

  it('returns 400 when required fields are missing', async () => {
    const res = await request(app)
      .post('/admin/language-packs/ai-generate')
      .send({ languageCode: 'KA' }); // missing targetLanguage

    expect(res.status).toBe(400);
  });
});

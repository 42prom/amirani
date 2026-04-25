import { describe, it, expect, vi, beforeEach } from 'vitest';

// ── Hoisted mock handles ──────────────────────────────────────────────────────

const mocks = vi.hoisted(() => ({
  foodFindMany: vi.fn(),
}));

// ── Mocks ─────────────────────────────────────────────────────────────────────

vi.mock('../../config/env', () => ({
  default: {
    jwt: { secret: 'test-jwt-secret-32-characters-long', expiresIn: '1h' },
    redis: { url: 'redis://localhost:6379' },
    port: 3000,
    nodeEnv: 'test',
  },
}));

vi.mock('../../lib/prisma', () => ({
  default: {
    foodItem: {
      findMany:   mocks.foodFindMany,
      findUnique: vi.fn(),
      upsert:     vi.fn(),
      findFirst:  vi.fn(),
      create:     vi.fn(),
    },
  },
}));

vi.mock('axios');

import { FoodService } from '../../modules/food/food.service';

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeItem(name: string, countryCodes: string[], availabilityScore = 50) {
  return { id: name, name, nameKa: null, nameRu: null, brand: null, barcode: null,
           calories: 100, protein: 10, carbs: 20, fats: 5, fiber: null,
           source: 'DB', isVerified: true, countryCodes, availabilityScore };
}

// ─────────────────────────────────────────────────────────────────────────────

describe('FoodService.rankByCountry — tier ordering', () => {
  beforeEach(() => vi.clearAllMocks());

  it('places country-matching items first (tier 0)', async () => {
    const items = [
      makeItem('global-food',  [],     80),  // tier 1 — no country codes
      makeItem('other-food',   ['RU'], 90),  // tier 2 — different country
      makeItem('local-food',   ['GE'], 70),  // tier 0 — country match
    ];
    mocks.foodFindMany.mockResolvedValue(items);

    const results = await FoodService.search('food', 10, 'EN', 'GE');

    expect(results[0].name).toBe('local-food');
  });

  it('places global items (empty countryCodes) in tier 1, before other-country items', async () => {
    const items = [
      makeItem('other-food',  ['US'], 95),  // tier 2
      makeItem('global-food', [],     60),  // tier 1
    ];
    mocks.foodFindMany.mockResolvedValue(items);

    const results = await FoodService.search('food', 10, 'EN', 'GE');

    expect(results[0].name).toBe('global-food');
    expect(results[1].name).toBe('other-food');
  });

  it('sorts within each tier by availabilityScore descending', async () => {
    const items = [
      makeItem('local-low',   ['GE'], 30),
      makeItem('local-high',  ['GE'], 90),
      makeItem('local-mid',   ['GE'], 60),
    ];
    mocks.foodFindMany.mockResolvedValue(items);

    const results = await FoodService.search('food', 10, 'EN', 'GE');

    expect(results.map(r => r.name)).toEqual(['local-high', 'local-mid', 'local-low']);
  });

  it('returns all items in original order when no country is provided', async () => {
    const items = [
      makeItem('item-a', ['GE'], 80),
      makeItem('item-b', ['RU'], 90),
      makeItem('item-c', [],     70),
    ];
    mocks.foodFindMany.mockResolvedValue(items);

    const results = await FoodService.search('item', 10, 'EN');

    // No country → no reordering, order from DB preserved
    expect(results.map(r => r.name)).toEqual(['item-a', 'item-b', 'item-c']);
  });

  it('returns empty array when query is blank', async () => {
    const results = await FoodService.search('', 10, 'EN', 'GE');
    expect(results).toEqual([]);
    expect(mocks.foodFindMany).not.toHaveBeenCalled();
  });

  it('returns empty array when query is a single character', async () => {
    const results = await FoodService.search('a', 10, 'EN');
    expect(results).toEqual([]);
  });

  it('respects limit — never returns more than limit items', async () => {
    const items = Array.from({ length: 30 }, (_, i) => makeItem(`item-${i}`, [], 50));
    mocks.foodFindMany.mockResolvedValue(items);

    const results = await FoodService.search('item', 5, 'EN');

    expect(results.length).toBeLessThanOrEqual(5);
  });

  it('returns Georgian name when lang=KA and nameKa is set', async () => {
    const item = { ...makeItem('Chicken', ['GE'], 80), nameKa: 'ქათამი', nameRu: null };
    mocks.foodFindMany.mockResolvedValue([item]);

    const results = await FoodService.search('chicken', 10, 'KA', 'GE');

    expect(results[0].name).toBe('ქათამი');
  });

  it('falls back to English name when lang=KA but nameKa is null', async () => {
    mocks.foodFindMany.mockResolvedValue([makeItem('Beef', ['GE'], 80)]);

    const results = await FoodService.search('beef', 10, 'KA', 'GE');

    expect(results[0].name).toBe('Beef');
  });

  it('full ordering: country match → global → other country', async () => {
    const items = [
      makeItem('other1',  ['US'], 99),
      makeItem('global1', [],     40),
      makeItem('other2',  ['RU'], 88),
      makeItem('local1',  ['GE'], 55),
      makeItem('global2', [],     70),
    ];
    mocks.foodFindMany.mockResolvedValue(items);

    const results = await FoodService.search('item', 10, 'EN', 'GE');

    expect(results[0].name).toBe('local1');   // tier 0
    expect(results[1].name).toBe('global2');  // tier 1, score 70
    expect(results[2].name).toBe('global1');  // tier 1, score 40
    // other1 and other2 are tier 2 (sorted by score desc)
    expect(results[3].name).toBe('other1');
    expect(results[4].name).toBe('other2');
  });
});

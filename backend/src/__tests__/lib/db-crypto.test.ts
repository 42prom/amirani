import { describe, it, expect, beforeEach, afterEach } from 'vitest';

// We test with an actual key so encrypt/decrypt round-trips work
const TEST_KEY = 'a'.repeat(64); // 64 hex chars = 32 bytes

describe('db-crypto', () => {
  beforeEach(() => {
    process.env.DB_ENCRYPTION_KEY = TEST_KEY;
  });

  afterEach(() => {
    delete process.env.DB_ENCRYPTION_KEY;
  });

  it('encrypts a string and produces enc:v1: prefix', async () => {
    const { encryptField } = await import('../../lib/db-crypto');
    const result = encryptField('my-secret-api-key');
    expect(result).toMatch(/^enc:v1:/);
  });

  it('decrypts back to the original plaintext', async () => {
    const { encryptField, decryptField } = await import('../../lib/db-crypto');
    const plaintext = 'sk-test-1234567890abcdef';
    const encrypted = encryptField(plaintext);
    expect(encrypted).not.toBe(plaintext);
    expect(decryptField(encrypted)).toBe(plaintext);
  });

  it('produces different ciphertext each call (random IV)', async () => {
    const { encryptField } = await import('../../lib/db-crypto');
    const a = encryptField('same-secret');
    const b = encryptField('same-secret');
    expect(a).not.toBe(b);
  });

  it('passes through null without throwing', async () => {
    const { encryptField, decryptField } = await import('../../lib/db-crypto');
    expect(encryptField(null)).toBeNull();
    expect(decryptField(null)).toBeNull();
  });

  it('passes through plaintext values that lack enc:v1: prefix', async () => {
    const { decryptField } = await import('../../lib/db-crypto');
    expect(decryptField('legacy-plaintext-value')).toBe('legacy-plaintext-value');
  });

  it('returns plaintext when no DB_ENCRYPTION_KEY is set', async () => {
    delete process.env.DB_ENCRYPTION_KEY;
    // Re-import to pick up missing key (vitest caches modules — bypass with isolateModules)
    const { encryptField } = await import('../../lib/db-crypto');
    expect(encryptField('my-key')).toBe('my-key');
  });
});


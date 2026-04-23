import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';
import logger from './logger';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const PREFIX = 'enc:v1:';

function getKey(): Buffer | null {
  const raw = process.env.DB_ENCRYPTION_KEY;
  if (!raw) return null;
  const buf = Buffer.from(raw, 'hex');
  if (buf.length !== 32) {
    logger.warn('[db-crypto] DB_ENCRYPTION_KEY must be 64 hex chars (32 bytes). Encryption disabled.');
    return null;
  }
  return buf;
}

export function encryptField(plaintext: string | null | undefined): string | null {
  if (plaintext == null) return null;
  const key = getKey();
  if (!key) return plaintext; // no key configured — pass through (dev)
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${PREFIX}${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

export function decryptField(value: string | null | undefined): string | null {
  if (value == null) return null;
  if (!value.startsWith(PREFIX)) return value; // legacy plaintext — return as-is
  const key = getKey();
  if (!key) {
    logger.warn('[db-crypto] Encrypted value in DB but DB_ENCRYPTION_KEY not set — cannot decrypt');
    return null;
  }
  const parts = value.slice(PREFIX.length).split(':');
  if (parts.length !== 3) return null;
  const [ivHex, tagHex, ciphertextHex] = parts;
  try {
    const iv = Buffer.from(ivHex, 'hex');
    const tag = Buffer.from(tagHex, 'hex');
    const ciphertext = Buffer.from(ciphertextHex, 'hex');
    const decipher = createDecipheriv(ALGORITHM, key, iv);
    decipher.setAuthTag(tag);
    return decipher.update(ciphertext).toString('utf8') + decipher.final('utf8');
  } catch {
    logger.error('[db-crypto] Decryption failed — wrong key or corrupted value');
    return null;
  }
}

/**
 * Utility for batch migrations.
 * Takes an array of plaintext values and returns encrypted ones.
 */
export function batchEncrypt(values: string[]): (string | null)[] {
  return values.map(v => encryptField(v));
}

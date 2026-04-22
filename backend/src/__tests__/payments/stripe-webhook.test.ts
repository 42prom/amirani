import { describe, it, expect } from 'vitest';
import { createHmac } from 'crypto';
import { verifyStripeSignature } from '../../modules/payments/payment.controller';

const SECRET = 'whsec_test_secret_key_for_testing';

function buildSignatureHeader(body: string, secret: string, timestamp = String(Math.floor(Date.now() / 1000))): string {
  const signedPayload = `${timestamp}.${body}`;
  const sig = createHmac('sha256', secret).update(signedPayload).digest('hex');
  return `t=${timestamp},v1=${sig}`;
}

describe('verifyStripeSignature', () => {
  const body = JSON.stringify({ type: 'payment_intent.succeeded', data: {} });
  const rawBody = Buffer.from(body, 'utf8');

  it('accepts a valid signature', () => {
    const header = buildSignatureHeader(body, SECRET);
    expect(verifyStripeSignature(rawBody, header, SECRET)).toBe(true);
  });

  it('rejects a tampered body', () => {
    const header = buildSignatureHeader(body, SECRET);
    const tamperedBody = Buffer.from(body + ' ', 'utf8');
    expect(verifyStripeSignature(tamperedBody, header, SECRET)).toBe(false);
  });

  it('rejects a wrong secret', () => {
    const header = buildSignatureHeader(body, SECRET);
    expect(verifyStripeSignature(rawBody, header, 'wrong_secret')).toBe(false);
  });

  it('rejects a missing t= timestamp', () => {
    const header = 'v1=fakesignature';
    expect(verifyStripeSignature(rawBody, header, SECRET)).toBe(false);
  });

  it('rejects a missing v1= signature', () => {
    const header = `t=${Math.floor(Date.now() / 1000)}`;
    expect(verifyStripeSignature(rawBody, header, SECRET)).toBe(false);
  });

  it('accepts when multiple v1= parts are present (Stripe rotation)', () => {
    const ts = String(Math.floor(Date.now() / 1000));
    const validHeader = buildSignatureHeader(body, SECRET, ts);
    // Prepend a stale/invalid v1 signature — Stripe sends both during key rotation
    const header = `${validHeader},v1=0000000000000000000000000000000000000000000000000000000000000000`;
    expect(verifyStripeSignature(rawBody, header, SECRET)).toBe(true);
  });
});

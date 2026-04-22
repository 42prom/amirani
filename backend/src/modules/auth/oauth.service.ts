import { OAuth2Client } from 'google-auth-library';
import * as https from 'https';
import * as jwt from 'jsonwebtoken';
import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';
import config from '../../config/env';
import { AuthService, AuthResult, AuthenticationError, ValidationError } from './auth.service';
import logger from '../../lib/logger';

// DB-backed credential helpers (fall back to env vars)
async function getGoogleClientId(): Promise<string | undefined> {
  try {
    const cfg = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
    return cfg?.googleClientId || process.env.GOOGLE_CLIENT_ID;
  } catch { return process.env.GOOGLE_CLIENT_ID; }
}

async function getAppleClientId(): Promise<string | undefined> {
  try {
    const cfg = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
    return cfg?.appleClientId || process.env.APPLE_CLIENT_ID;
  } catch { return process.env.APPLE_CLIENT_ID; }
}

// ─── Apple public key cache ───────────────────────────────────────────────────

let appleKeysCache: any[] | null = null;
let appleKeysCachedAt = 0;

async function getApplePublicKeys(): Promise<any[]> {
  const now = Date.now();
  if (appleKeysCache && now - appleKeysCachedAt < 3600_000) return appleKeysCache;

  return new Promise((resolve, reject) => {
    https.get('https://appleid.apple.com/auth/keys', (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        try {
          const { keys } = JSON.parse(raw);
          appleKeysCache = keys;
          appleKeysCachedAt = now;
          resolve(keys);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class OAuthService {
  static async getPublicConfig() {
    const cfg = await prisma.oAuthConfig.findUnique({ where: { id: 'singleton' } });
    
    return {
      googleEnabled:  cfg?.googleEnabled ?? false,
      googleClientId: cfg?.googleClientId || process.env.GOOGLE_CLIENT_ID || null,
      appleEnabled:   cfg?.appleEnabled  ?? false,
      appleClientId:  cfg?.appleClientId  || process.env.APPLE_CLIENT_ID  || null,
    };
  }

  static async authenticate(provider: string, idToken: string): Promise<AuthResult> {
    let email: string;
    let fullName: string;
    let avatarUrl: string | undefined;

    if (provider === 'google') {
      ({ email, fullName, avatarUrl } = await OAuthService.verifyGoogle(idToken));
    } else if (provider === 'apple') {
      ({ email, fullName } = await OAuthService.verifyApple(idToken));
    } else {
      throw new ValidationError('Unsupported provider', [
        { field: 'provider', message: 'Must be "google" or "apple"' },
      ]);
    }

    // Find or create user
    let user = await prisma.user.findUnique({ where: { email } });

    if (!user) {
      logger.info('[OAuth] Creating new user via OAuth');
      try {
        user = await prisma.user.create({
          data: {
            email,
            fullName,
            password: '', // no password for OAuth users
            role: Role.GYM_MEMBER,
            isVerified: true,
            avatarUrl: avatarUrl ?? null,
          },
        });
        logger.info('[OAuth] New user created', { userId: user.id });
      } catch (error: any) {
        logger.error('[OAuth] Failed to create user', { error });
        throw error;
      }
    } else if (!user.isActive) {
      throw new AuthenticationError('Account is deactivated');
    }

    const token = jwt.sign(
      { userId: user.id, role: user.role, managedGymId: user.managedGymId || null },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn as jwt.SignOptions['expiresIn'] }
    );

    const refreshToken = await AuthService.issueRefreshToken(user.id);

    return {
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        role: user.role,
        isVerified: user.isVerified,
        managedGymId: user.managedGymId,
        avatarUrl: user.avatarUrl,
        phoneNumber: user.phoneNumber,
        gender: user.gender,
        dob: user.dob,
        weight: user.weight ? user.weight.toString() : null,
        height: user.height ? user.height.toString() : null,
        medicalConditions: user.medicalConditions,
        noMedicalConditions: user.noMedicalConditions,
        personalNumber: user.personalNumber,
        address: user.address,
        idPhotoUrl: user.idPhotoUrl,
        totalPoints: (user as any).totalPoints ?? 0,
        streakDays: (user as any).streakDays ?? 0,
        mustChangePassword: (user as any).mustChangePassword ?? false,
      },
      token,
      refreshToken,
    };
  }

  // ── Google ────────────────────────────────────────────────────────────────

  private static async verifyGoogle(idToken: string) {
    const clientId = await getGoogleClientId();
    if (!clientId) {
      logger.error('[OAuth] Google Client ID is not configured');
      throw new AuthenticationError('Google Sign-In is not configured on the server');
    }

    try {
      const client = new OAuth2Client(clientId);
      const ticket = await client.verifyIdToken({
        idToken,
        audience: clientId,
      });
      const payload = ticket.getPayload();
      if (!payload?.email) {
        logger.warn('[OAuth] No email in Google ID token payload');
        throw new Error('No email in token');
      }
      return {
        email: payload.email,
        fullName: payload.name ?? payload.email.split('@')[0],
        avatarUrl: payload.picture,
      };
    } catch (error: any) {
      logger.warn('[OAuth] Google ID token verification failed', { message: error.message });
      throw new AuthenticationError('Invalid Google ID token');
    }
  }

  // ── Apple ─────────────────────────────────────────────────────────────────

  private static async verifyApple(idToken: string) {
    try {
      const keys = await getApplePublicKeys();
      const decoded = jwt.decode(idToken, { complete: true }) as any;
      if (!decoded) throw new Error('Cannot decode token');

      const key = keys.find((k: any) => k.kid === decoded.header.kid);
      if (!key) throw new Error('Apple public key not found');

      // Build PEM from JWK
      const { createPublicKey } = await import('crypto');
      const pem = createPublicKey({ key, format: 'jwk' })
        .export({ type: 'spki', format: 'pem' }) as string;

      const appleClientId = await getAppleClientId();
      const payload = jwt.verify(idToken, pem, {
        algorithms: ['RS256'],
        issuer: 'https://appleid.apple.com',
        audience: appleClientId,
      }) as any;

      if (!payload.email) throw new Error('No email in Apple token');
      return {
        email: payload.email as string,
        fullName: (payload.given_name ?? '') + ' ' + (payload.family_name ?? '') || payload.email.split('@')[0],
      };
    } catch {
      throw new AuthenticationError('Invalid Apple ID token');
    }
  }
}

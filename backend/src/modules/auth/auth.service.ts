import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../../lib/prisma';
import { Role } from '@prisma/client';
import config from '../../config/env';
import logger from '../../lib/logger';
import { generateSecret, generateURI, verify } from 'otplib';
import QRCode from 'qrcode';
import {
  validateEmail,
  validatePassword,
  validateRequired,
  validateSelfRegisterRole,
  combineValidations,
  sanitize,
} from '../../utils/validation';
import { encryptField, decryptField } from '../../lib/db-crypto';

// ─── DTOs ────────────────────────────────────────────────────────────────────

export interface RegisterInput {
  email: string;
  password: string;
  fullName: string;
  role?: string;
}

export interface InvitedRegisterInput {
  token: string;
  password: string;
  fullName: string;
}

export interface LoginInput {
  email: string;
  password: string;
}

export interface AuthResult {
  user: {
    id: string;
    email: string;
    fullName: string;
    role: Role;
    isVerified: boolean;
    managedGymId?: string | null;
    avatarUrl?: string | null;
    phoneNumber?: string | null;
    gender?: string | null;
    dob?: string | null;
    weight?: string | null;
    height?: string | null;
    medicalConditions?: string | null;
    noMedicalConditions: boolean;
    personalNumber?: string | null;
    address?: string | null;
    idPhotoUrl?: string | null;
    totalPoints: number;
    streakDays: number;
    mustChangePassword: boolean;
  };
  token: string;
  refreshToken: string;
  requires2FA?: boolean;
}

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class ValidationError extends Error {
  constructor(
    message: string,
    public details: { field: string; message: string }[]
  ) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class ConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConflictError';
  }
}

export class AuthenticationError extends Error {
  constructor(message: string = 'Invalid credentials') {
    super(message);
    this.name = 'AuthenticationError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class AuthService {
  /**
   * Register a new user (self-registration)
   * Only GYM_MEMBER and HOME_USER roles allowed
   */
  static async register(data: RegisterInput): Promise<AuthResult> {
    // Validate input
    const validation = combineValidations(
      validateEmail(data.email),
      validatePassword(data.password),
      validateRequired(data.fullName, 'fullName', { minLength: 2, maxLength: 100 }),
      validateSelfRegisterRole(data.role)
    );

    if (!validation.valid) {
      throw new ValidationError('Validation failed', validation.errors);
    }

    // Sanitize inputs
    const email = sanitize(data.email).toLowerCase();
    const fullName = sanitize(data.fullName);

    // Determine role (only GYM_MEMBER or HOME_USER allowed for self-registration)
    const allowedRoles: Role[] = [Role.GYM_MEMBER, Role.HOME_USER];
    const requestedRole = data.role as Role | undefined;
    const userRole = requestedRole && allowedRoles.includes(requestedRole)
      ? requestedRole
      : Role.HOME_USER;

    // Check for existing user
    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      throw new ConflictError('Email already registered');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(data.password, 12);

    // Create user
    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        fullName,
        role: userRole,
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        role: true,
        isVerified: true,
        managedGymId: true,
        avatarUrl: true,
        phoneNumber: true,
        gender: true,
        dob: true,
        weight: true,
        height: true,
        medicalConditions: true,
        noMedicalConditions: true,
        personalNumber: true,
        address: true,
        idPhotoUrl: true,
        totalPoints: true,
        streakDays: true,
        mustChangePassword: true,
      },
    });

    const token = this.generateToken(user.id, user.role, user.managedGymId);
    const refreshToken = await this.issueRefreshToken(user.id);

    return {
      user: {
        ...user,
        weight: user.weight ? user.weight.toString() : null,
        height: user.height ? user.height.toString() : null,
      },
      token,
      refreshToken,
    };
  }

  /**
   * Login an existing user
   */
  static async login(data: LoginInput): Promise<AuthResult> {
    const { email: rawEmail, password } = data;

    if (!rawEmail || !password) {
      throw new ValidationError('Email and password are required', [
        { field: 'email', message: 'Email is required' },
        { field: 'password', message: 'Password is required' },
      ]);
    }

    const email = sanitize(rawEmail).toLowerCase();

    // Find user (get full user for all checks)
    const user = await prisma.user.findUnique({
      where: { email },
    });

    if (!user) {
      throw new AuthenticationError();
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new AuthenticationError();
    }

    // Check account status
    if (!user.isActive) {
      throw new AuthenticationError('Account is deactivated');
    }

    // Check 2FA
    if ((user as any).twoFactorEnabled) {
      return {
        user: { id: user.id, email: user.email, fullName: user.fullName, role: user.role } as any,
        token: '',
        refreshToken: '',
        requires2FA: true,
      };
    }

    const token = this.generateToken(user.id, user.role, user.managedGymId);
    const refreshToken = await this.issueRefreshToken(user.id);

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

  /**
   * Register a Gym Owner via invitation token
   */
  static async registerWithInvitation(data: InvitedRegisterInput): Promise<AuthResult> {
    // Validate input
    const validation = combineValidations(
      validateRequired(data.token, 'token'),
      validatePassword(data.password),
      validateRequired(data.fullName, 'fullName', { minLength: 2, maxLength: 100 })
    );

    if (!validation.valid) {
      throw new ValidationError('Validation failed', validation.errors);
    }

    // Validate invitation token
    const invitation = await prisma.invitation.findUnique({
      where: { inviteToken: data.token },
    });

    if (!invitation) {
      throw new ValidationError('Validation failed', [
        { field: 'token', message: 'Invalid invitation token' }
      ]);
    }

    if (invitation.status === 'ACCEPTED') {
      throw new ValidationError('Validation failed', [
        { field: 'token', message: 'Invitation has already been used' }
      ]);
    }

    if (invitation.status === 'EXPIRED' || invitation.expiresAt < new Date()) {
      throw new ValidationError('Validation failed', [
        { field: 'token', message: 'Invitation has expired' }
      ]);
    }

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email: invitation.email },
    });

    if (existingUser) {
      throw new ConflictError('A user with this email already exists');
    }

    // Sanitize inputs
    const fullName = sanitize(data.fullName);

    // Hash password
    const hashedPassword = await bcrypt.hash(data.password, 12);

    // Create user as GYM_OWNER
    const user = await prisma.user.create({
      data: {
        email: invitation.email,
        password: hashedPassword,
        fullName,
        role: Role.GYM_OWNER,
        isVerified: true, // Invited users are pre-verified
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        role: true,
        isVerified: true,
        managedGymId: true,
        avatarUrl: true,
        phoneNumber: true,
        gender: true,
        dob: true,
        weight: true,
        height: true,
        medicalConditions: true,
        noMedicalConditions: true,
        personalNumber: true,
        address: true,
        idPhotoUrl: true,
        totalPoints: true,
        streakDays: true,
        mustChangePassword: true,
      },
    });

    // Mark invitation as accepted
    await prisma.invitation.update({
      where: { id: invitation.id },
      data: {
        status: 'ACCEPTED',
        acceptedAt: new Date(),
        acceptedUserId: user.id,
      },
    });

    logger.info('[Auth] Gym Owner registered via invitation');

    const token = this.generateToken(user.id, user.role, user.managedGymId);
    const refreshToken = await this.issueRefreshToken(user.id);

    return {
      user: {
        ...user,
        weight: user.weight ? user.weight.toString() : null,
        height: user.height ? user.height.toString() : null,
      },
      token,
      refreshToken,
    };
  }

  /**
   * Exchange a valid refresh token for a new access token + rotated refresh token.
   * The old refresh token is revoked immediately (rotation).
   */
  static async refreshAccessToken(rawToken: string): Promise<{ token: string; refreshToken: string }> {
    const record = await prisma.refreshToken.findUnique({ where: { token: rawToken } });

    if (!record || record.revokedAt || record.expiresAt < new Date()) {
      throw new AuthenticationError('Invalid or expired refresh token');
    }

    // Revoke old token (rotation — prevents reuse)
    await prisma.refreshToken.update({
      where: { id: record.id },
      data: { revokedAt: new Date() },
    });

    const user = await prisma.user.findUnique({
      where: { id: record.userId },
      select: { id: true, role: true, managedGymId: true, isActive: true },
    });

    if (!user || !user.isActive) {
      throw new AuthenticationError('Account is deactivated');
    }

    const token = this.generateToken(user.id, user.role, user.managedGymId);
    const refreshToken = await this.issueRefreshToken(user.id);
    return { token, refreshToken };
  }

  /**
   * Revoke a specific refresh token (logout).
   */
  static async revokeRefreshToken(rawToken: string): Promise<void> {
    await prisma.refreshToken.updateMany({
      where: { token: rawToken, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Revoke ALL refresh tokens for a user (logout all devices).
   */
  static async revokeAllRefreshTokens(userId: string): Promise<void> {
    await prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Get user profile by ID for session validation
   */
  static async getUserProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        fullName: true,
        role: true,
        isVerified: true,
        managedGymId: true,
        isActive: true, // specifically needed for profile check
        avatarUrl: true,
        phoneNumber: true,
        gender: true,
        dob: true,
        weight: true,
        height: true,
        heightCm: true,
        targetWeightKg: true,
        medicalConditions: true,
        noMedicalConditions: true,
        personalNumber: true,
        address: true,
        idPhotoUrl: true,
        totalPoints: true,
        streakDays: true,
        mustChangePassword: true,
        unitPreference: true,
        languagePreference: true,
      },
    });

    if (!user) return null;

    return {
      ...user,
      weight: user.weight ? user.weight.toString() : null,
      height: user.height ? user.height.toString() : null,
      targetWeightKg: user.targetWeightKg ? user.targetWeightKg.toString() : null,
    };
  }

  /**
   * Update user FCM token
   */
  static async updateFCMToken(userId: string, fcmToken: string) {
    return prisma.notificationPreference.upsert({
      where: { userId },
      update: { fcmToken },
      create: { userId, fcmToken },
    });
  }

  // ─── Token Helpers ───────────────────────────────────────────────────────────

  private static generateToken(userId: string, role: string, gymId?: string | null): string {
    return jwt.sign(
      { userId, role, managedGymId: gymId },
      config.jwt.secret as string,
      { expiresIn: config.jwt.expiresIn as any }
    );
  }

  static async issueRefreshToken(userId: string): Promise<string> {
    const token = require('crypto').randomBytes(40).toString('hex');
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days
    await prisma.refreshToken.create({ data: { token, userId, expiresAt } });
    return token;
  }

  /**
   * Change password — validates current password, hashes new one, clears mustChangePassword.
   * Throws AuthenticationError if currentPassword doesn't match.
   */
  static async changePassword(userId: string, currentPassword: string, newPassword: string): Promise<void> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new AuthenticationError('User not found');

    const isValid = await bcrypt.compare(currentPassword, user.password);
    if (!isValid) throw new AuthenticationError('Current password is incorrect');

    const validation = validatePassword(newPassword);
    if (!validation.valid) {
      throw new ValidationError('Validation failed', validation.errors);
    }

    const hashed = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({
      where: { id: userId },
      data: { password: hashed, mustChangePassword: false },
    });
  }

  /**
   * Setup 2FA — generates secret and QR code for user to scan.
   */
  static async setup2FA(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error('User not found');

    const secret = generateSecret();
    const otpauth = generateURI({ issuer: 'Amirani', label: user.email, secret });
    const qrCode = await QRCode.toDataURL(otpauth);

    await prisma.user.update({
      where: { id: userId },
      data: { twoFactorSecret: encryptField(secret) } as any,
    });

    return { secret, qrCode };
  }

  /**
   * Enable 2FA — verifies token and activates 2FA on account.
   */
  static async enable2FA(userId: string, token: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !(user as any).twoFactorSecret) throw new Error('2FA not setup');

    const secret = decryptField((user as any).twoFactorSecret);
    if (!secret) throw new Error('Failed to decrypt 2FA secret');

    const isValidResult = await verify({ token, secret });
    const isValid = isValidResult.valid;
    if (!isValid) throw new AuthenticationError('Invalid 2FA token');

    await prisma.user.update({
      where: { id: userId },
      data: { twoFactorEnabled: true } as any,
    });

    return { success: true };
  }

  /**
   * Verify 2FA — used during login flow if requires2FA is true.
   */
  static async verify2FA(email: string, token: string): Promise<AuthResult> {
    const user = await prisma.user.findUnique({ where: { email: email.toLowerCase() } });
    if (!user || !(user as any).twoFactorSecret || !(user as any).twoFactorEnabled) {
      throw new AuthenticationError('2FA not enabled');
    }

    const secret = decryptField((user as any).twoFactorSecret);
    if (!secret) throw new Error('Failed to decrypt 2FA secret');

    const isValidResult = await verify({ token, secret });
    const isValid = isValidResult.valid;
    if (!isValid) throw new AuthenticationError('Invalid 2FA token');

    const jwtToken = this.generateToken(user.id, user.role, user.managedGymId);
    const refreshToken = await this.issueRefreshToken(user.id);

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
      token: jwtToken,
      refreshToken,
    };
  }
}

/**
 * Shared membership validation utilities.
 * Single source of truth — import from here everywhere membership status matters.
 */

import { Role } from '@prisma/client';

// ─── Branch Admin Access Check ────────────────────────────────────────────────

/**
 * Returns true when the caller is a Branch Admin assigned to the given gym.
 *
 * Previously this check was duplicated inline at 12+ call sites as:
 *   `role === Role.BRANCH_ADMIN && gym.id === managedGymId`
 * A missed null-check or copy-paste drift at any one site is a privilege
 * escalation. Centralising it here ensures every check is identical.
 *
 * @param role         - Caller's role from the JWT
 * @param gymId        - The gym being accessed
 * @param managedGymId - The gym this Branch Admin is assigned to (may be null
 *                       for legacy accounts — treated as no assignment)
 */
export function isBranchAdminOf(
  role: Role,
  gymId: string,
  managedGymId: string | null | undefined,
): boolean {
  return role === Role.BRANCH_ADMIN && !!managedGymId && gymId === managedGymId;
}

/**
 * Returns true when the caller has at least branch-admin level access to the gym:
 *   SUPER_ADMIN always passes.
 *   GYM_OWNER passes when they own the gym (ownerId === callerId).
 *   BRANCH_ADMIN passes when they are assigned to this gym.
 */
export function hasGymAccess(
  role: Role,
  gymOwnerId: string,
  callerId: string,
  gymId: string,
  managedGymId: string | null | undefined,
): boolean {
  if (role === Role.SUPER_ADMIN) return true;
  if (role === Role.GYM_OWNER && gymOwnerId === callerId) return true;
  return isBranchAdminOf(role, gymId, managedGymId);
}

// ─── Types ────────────────────────────────────────────────────────────────────

export interface MembershipLike {
  status: string;
  endDate: Date;
  frozenUntil?: Date | null;
}

export type MembershipDenyReason =
  | 'NOT_FOUND'
  | 'NOT_ACTIVE'
  | 'EXPIRED'
  | 'FROZEN';

export interface MembershipValidationResult {
  valid: boolean;
  reason?: MembershipDenyReason;
  message?: string;
}

// ─── Date Calculation ─────────────────────────────────────────────────────────

/**
 * Calculate membership end date from a start date and plan duration.
 * Handles both month-based and day-based plans.
 */
export function calcMembershipEndDate(
  startDate: Date,
  durationValue: number,
  durationUnit: string
): Date {
  const end = new Date(startDate);
  if (durationUnit === 'months') {
    end.setMonth(end.getMonth() + durationValue);
  } else {
    end.setDate(end.getDate() + durationValue);
  }
  return end;
}

// ─── Validation ───────────────────────────────────────────────────────────────

/**
 * Validate whether a membership grants access right now.
 * Checks: status ACTIVE, not expired, not currently frozen.
 */
export function validateMembershipAccess(
  membership: MembershipLike | null | undefined
): MembershipValidationResult {
  if (!membership) {
    return { valid: false, reason: 'NOT_FOUND', message: 'No membership found for this gym' };
  }

  if (membership.status !== 'ACTIVE') {
    return { valid: false, reason: 'NOT_ACTIVE', message: 'Membership is not active' };
  }

  if (new Date() > membership.endDate) {
    return { valid: false, reason: 'EXPIRED', message: 'Membership has expired' };
  }

  if (membership.frozenUntil && new Date() < membership.frozenUntil) {
    return { valid: false, reason: 'FROZEN', message: 'Membership is currently frozen' };
  }

  return { valid: true };
}

/**
 * Throw if membership is not valid. Convenience wrapper for services that throw on denial.
 */
export function assertMembershipAccess(
  membership: MembershipLike | null | undefined,
  ErrorClass: new (msg: string) => Error = Error
): void {
  const result = validateMembershipAccess(membership);
  if (!result.valid) {
    throw new ErrorClass(result.message!);
  }
}

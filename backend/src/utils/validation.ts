/**
 * Input validation utilities
 * Simple validation without external dependencies
 */

export interface ValidationResult {
  valid: boolean;
  errors: { field: string; message: string }[];
}

// Email regex (RFC 5322 simplified)
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Password requirements
const PASSWORD_MIN_LENGTH = 8;
const PASSWORD_REGEX = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).+$/;

export function validateEmail(email: unknown): ValidationResult {
  const errors: { field: string; message: string }[] = [];

  if (typeof email !== 'string') {
    errors.push({ field: 'email', message: 'Email must be a string' });
  } else if (!email.trim()) {
    errors.push({ field: 'email', message: 'Email is required' });
  } else if (!EMAIL_REGEX.test(email)) {
    errors.push({ field: 'email', message: 'Invalid email format' });
  } else if (email.length > 255) {
    errors.push({ field: 'email', message: 'Email must be less than 255 characters' });
  }

  return { valid: errors.length === 0, errors };
}

export function validatePassword(password: unknown): ValidationResult {
  const errors: { field: string; message: string }[] = [];

  if (typeof password !== 'string') {
    errors.push({ field: 'password', message: 'Password must be a string' });
  } else if (password.length < PASSWORD_MIN_LENGTH) {
    errors.push({
      field: 'password',
      message: `Password must be at least ${PASSWORD_MIN_LENGTH} characters`
    });
  } else if (!PASSWORD_REGEX.test(password)) {
    errors.push({
      field: 'password',
      message: 'Password must contain uppercase, lowercase, and a number'
    });
  } else if (password.length > 128) {
    errors.push({ field: 'password', message: 'Password must be less than 128 characters' });
  }

  return { valid: errors.length === 0, errors };
}

export function validateRequired(
  value: unknown,
  field: string,
  options?: { maxLength?: number; minLength?: number }
): ValidationResult {
  const errors: { field: string; message: string }[] = [];

  if (typeof value !== 'string') {
    errors.push({ field, message: `${field} must be a string` });
  } else if (!value.trim()) {
    errors.push({ field, message: `${field} is required` });
  } else {
    if (options?.minLength && value.length < options.minLength) {
      errors.push({ field, message: `${field} must be at least ${options.minLength} characters` });
    }
    if (options?.maxLength && value.length > options.maxLength) {
      errors.push({ field, message: `${field} must be less than ${options.maxLength} characters` });
    }
  }

  return { valid: errors.length === 0, errors };
}

export function combineValidations(...results: ValidationResult[]): ValidationResult {
  const allErrors = results.flatMap(r => r.errors);
  return {
    valid: allErrors.length === 0,
    errors: allErrors,
  };
}

// Sanitize string input
export function sanitize(input: string): string {
  return input
    .trim()
    .replace(/[<>]/g, '') // Remove potential HTML tags
    .slice(0, 10000); // Prevent extremely long strings
}

// Validate role is valid for self-registration
export function validateSelfRegisterRole(role: unknown): ValidationResult {
  const errors: { field: string; message: string }[] = [];
  const allowedRoles = ['GYM_MEMBER', 'HOME_USER'];

  if (role && typeof role === 'string' && !allowedRoles.includes(role)) {
    errors.push({
      field: 'role',
      message: 'Only GYM_MEMBER and HOME_USER can self-register'
    });
  }

  return { valid: errors.length === 0, errors };
}

import { Response } from 'express';
import { randomUUID } from 'crypto';
import logger from '../lib/logger';

/**
 * Standardized API response utilities
 */

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: { field: string; message: string }[];
  };
  meta?: {
    timestamp: string;
    requestId?: string;
  };
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    total: number;
    page: number;
    limit: number;
    pages: number;
  };
}

// Success response
export function success<T>(res: Response, data: T, message?: string, statusCode = 200): void {
  const response: ApiResponse<T> = {
    success: true,
    data,
    meta: {
      timestamp: new Date().toISOString(),
      ...(message && { message }),
    },
  };
  res.status(statusCode).json(response);
}

// Created response (201)
export function created<T>(res: Response, data: T): void {
  success(res, data, undefined, 201);
}

// No content response (204)
export function noContent(res: Response): void {
  res.status(204).send();
}

// Paginated response
export function paginated<T>(
  res: Response,
  data: T[],
  pagination: { total: number; page: number; limit: number }
): void {
  const response: PaginatedResponse<T> = {
    success: true,
    data,
    pagination: {
      ...pagination,
      pages: Math.ceil(pagination.total / pagination.limit),
    },
    meta: {
      timestamp: new Date().toISOString(),
    },
  };
  res.status(200).json(response);
}

// Error codes
export const ErrorCodes = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  BAD_REQUEST: 'BAD_REQUEST',
  RATE_LIMITED: 'RATE_LIMITED',
} as const;

type ErrorCode = typeof ErrorCodes[keyof typeof ErrorCodes];

// Error response
export function error(
  res: Response,
  statusCode: number,
  code: ErrorCode,
  message: string,
  details?: { field: string; message: string }[]
): void {
  const response: ApiResponse = {
    success: false,
    error: {
      code,
      message,
      details,
    },
    meta: {
      timestamp: new Date().toISOString(),
    },
  };
  res.status(statusCode).json(response);
}

// Specific error helpers
export function badRequest(
  res: Response,
  message: string,
  details?: { field: string; message: string }[]
): void {
  error(res, 400, ErrorCodes.BAD_REQUEST, message, details);
}

export function validationError(
  res: Response,
  details: { field: string; message: string }[]
): void {
  error(res, 422, ErrorCodes.VALIDATION_ERROR, 'Validation failed', details);
}

export function unauthorized(res: Response, message = 'Unauthorized'): void {
  error(res, 401, ErrorCodes.UNAUTHORIZED, message);
}

export function forbidden(res: Response, message = 'Access denied'): void {
  error(res, 403, ErrorCodes.FORBIDDEN, message);
}

export function notFound(res: Response, resource = 'Resource'): void {
  error(res, 404, ErrorCodes.NOT_FOUND, `${resource} not found`);
}

export function conflict(res: Response, message: string): void {
  error(res, 409, ErrorCodes.CONFLICT, message);
}

export function internalError(res: Response, message = 'Internal server error'): void {
  error(res, 500, ErrorCodes.INTERNAL_ERROR, message);
}

export function rateLimited(res: Response): void {
  error(res, 429, ErrorCodes.RATE_LIMITED, 'Too many requests. Please try again later.');
}

// Logs the error internally with a UUID ref, returns opaque 500 to the client.
// Use this instead of internalError when you have an Error object to log.
export function serverError(res: Response, err: unknown): void {
  const ref = randomUUID();
  logger.error('Unhandled server error', { ref, err });
  error(res, 500, ErrorCodes.INTERNAL_ERROR, `Internal server error (ref: ${ref})`);
}


import winston from 'winston';
import config from '../config/env';

const { combine, timestamp, json, colorize, simple, errors } = winston.format;

// ─── Logger ───────────────────────────────────────────────────────────────────

const logger = winston.createLogger({
  level: config.nodeEnv === 'production' ? 'info' : 'debug',
  defaultMeta: { service: 'amirani-api' },
  format: combine(
    errors({ stack: true }),
    timestamp(),
    json(),
  ),
  transports: [
    new winston.transports.Console({
      format: config.nodeEnv === 'production'
        ? combine(errors({ stack: true }), timestamp(), json())
        : combine(colorize(), simple()),
    }),
  ],
  exitOnError: false,
});

export default logger;

// ─── HTTP request logger middleware ──────────────────────────────────────────

import { Request, Response, NextFunction } from 'express';

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  res.on('finish', () => {
    const ms = Date.now() - start;
    const level = res.statusCode >= 500 ? 'error'
      : res.statusCode >= 400 ? 'warn'
      : 'info';
    logger[level]({
      message: 'HTTP',
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      ms,
      ip: req.ip,
    });
  });
  next();
}

import '../loadEnv';
/**
 * Environment configuration with validation
 * Fails fast if required variables are missing
 */

const requiredVars = [
  'DATABASE_URL',
  'JWT_SECRET',
] as const;

const optionalVars = [
  'PORT',
  'NODE_ENV',
  'REDIS_URL',
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
  'ALLOWED_ORIGINS',
  'DB_ENCRYPTION_KEY',
] as const;

// Validate required environment variables at startup
function validateEnv(): void {
  const missing: string[] = [];

  for (const varName of requiredVars) {
    if (!process.env[varName]) {
      missing.push(varName);
    }
  }

  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(', ')}\n` +
      `Please check your .env file or environment configuration.`
    );
  }

  // Validate JWT_SECRET strength
  const jwtSecret = process.env.JWT_SECRET!;
  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error(
      'JWT_SECRET must be at least 32 characters long for security.'
    );
  }
}

export const config = {
  port: parseInt(process.env.PORT || '3085', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  isDevelopment: process.env.NODE_ENV !== 'production',
  isProduction: process.env.NODE_ENV === 'production',

  database: {
    url: process.env.DATABASE_URL!,
  },

  jwt: {
    secret: process.env.JWT_SECRET!,
    expiresIn: '7d',
    refreshExpiresIn: '30d',
  },

  redis: {
    url: process.env.REDIS_URL || 'redis://localhost:6379',
  },

  cors: {
    // In development: allow all localhost origins plus any ALLOWED_ORIGINS value.
    // In production: only the explicit ALLOWED_ORIGINS list is accepted.
    allowedOrigins: process.env.ALLOWED_ORIGINS
      ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
      : ['http://localhost:3002'],
  },

  stripe: {
    secretKey: process.env.STRIPE_SECRET_KEY,
    webhookSecret: process.env.STRIPE_WEBHOOK_SECRET,
  },
};

// Run validation
validateEnv();

export default config;

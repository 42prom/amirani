import './loadEnv';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import { createServer } from 'http';

import logger, { requestLogger } from './lib/logger';

// Route imports
import authRoutes from './modules/auth/auth.controller';
import adminRoutes from './modules/admin/admin.controller';
import gymRoutes from './modules/gym-management/gym.controller';
import membershipRoutes from './modules/memberships/membership.controller';
import { internalError } from './lib/response';
import equipmentCatalogRoutes from './modules/equipment/equipment-catalog.controller';
import attendanceRoutes from './modules/attendance/attendance.controller';
import doorAccessRoutes from './modules/door-access/door-access.controller';
import notificationRoutes from './modules/notifications/notification.controller';
import paymentRoutes from './modules/payments/payment.controller';
import trainerRoutes from './modules/trainers/trainer.controller';
import platformRoutes from './modules/platform/platform-config.controller';
import gymOwnerRoutes from './modules/gym-management/gym-owner.controller';
import invitationRoutes from './modules/admin/invitation.controller';
import uploadRoutes from './modules/upload/upload.controller';
import depositRoutes from './modules/deposits/deposit.routes';
import marketingRoutes from './modules/marketing/marketing.controller';
import analyticsRoutes from './modules/analytics/analytics.controller';
import automationRoutes from './modules/automations/automation.controller';
import { AutomationService } from './modules/automations/automation.service';
import { PaymentService } from './modules/payments/payment.service';
import { NotificationService } from './modules/notifications/notification.service';
import announcementRoutes from './modules/announcements/announcement.controller';
import sessionRoutes from './modules/sessions/session.controller';
import supportRoutes from './modules/support/support.controller';
import assignmentRoutes from './modules/assignment/assignment.controller';
import { FreezeService } from './modules/memberships/freeze.service';
import auditRoutes from './modules/audit/audit.controller';
import { SchedulerService } from './modules/notifications/scheduler.service';
import webhookRoutes from './modules/webhooks/webhook.controller';
import roomRoutes from './modules/rooms/room.controller';
import userRoutes from './modules/users/user.controller';
import { syncRoutes } from './modules/mobile-sync/sync.routes';
import gymEntryRoutes from './modules/gym-entry/gym-entry.controller';
import hardwareRoutes from './modules/hardware/hardware-gateway.controller';
import foodRoutes from './modules/food/food.controller';
import nutritionStatsRoutes from './modules/food/nutrition-stats.controller';
import workoutRoutes from './modules/workouts/workout.controller';
import aiRoutes from './modules/ai/ai.controller';
import { initSocket } from './lib/socket';
import { startAiWorkers } from './lib/queue';
import config from './config/env';

const app = express();
app.set('trust proxy', 1); // Trust first proxy (cloudflared tunnel)
const httpServer = createServer(app);
const port = config.port;

// Initialize WebSockets (for hardware gateways & admin dash)
initSocket(httpServer);

// ─── Rate Limiters ────────────────────────────────────────────────────────────
import { globalLimiter } from './lib/rate-limiters';

// Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' }, // allow API to be called cross-origin
  contentSecurityPolicy: false,                           // CSP not needed on API server
}));
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);
    
    // In development: automatically allow any localhost origin (any port)
    if (config.isDevelopment && origin.startsWith('http://localhost')) {
      return callback(null, true);
    }

    if (config.cors.allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error(`CORS: origin '${origin}' not allowed`));
  },
  credentials: true,
}));
// Stripe webhook needs raw body for signature verification — mount before express.json()
app.use('/api/payments/webhook', express.raw({ type: 'application/json' }));
app.use(express.json());
app.use(requestLogger);
app.use('/api/', globalLimiter);

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

// ─── API Routes ──────────────────────────────────────────────────────────────

// Auth routes — per-route limiters applied inside auth.controller.ts
app.use('/api/auth', authRoutes);

// Admin routes (Super Admin & Gym Owner)
app.use('/api/admin', adminRoutes);

// Invitation routes (Super Admin only)
app.use('/api/admin/invitations', invitationRoutes);

// Gym management routes
app.use('/api/gym-management', gymRoutes);

// Membership & Subscription routes
app.use('/api/memberships', membershipRoutes);

// Equipment Catalog routes (Super Admin only)
app.use('/api/equipment-catalog', equipmentCatalogRoutes);

// Attendance routes
app.use('/api/attendance', attendanceRoutes);

// Door Access routes
app.use('/api/door-access', doorAccessRoutes);

// Notification routes
app.use('/api/notifications', notificationRoutes);

// Payment routes
app.use('/api/payments', paymentRoutes);

// Deposit Routes
app.use('/api/deposits', depositRoutes);

// Trainer routes
app.use('/api/trainers', trainerRoutes);

// Platform config routes (Super Admin only)
app.use('/api/platform', platformRoutes);

// Gym Owner routes (Stripe Connect, Plans, Equipment)
app.use('/api/gym-owner', gymOwnerRoutes);

// File upload routes
app.use('/api/upload', uploadRoutes);

// Mobile App Sync Routes
app.use('/api/sync', syncRoutes);

// Gym Entry Routes (QR check-in, check-out, live occupancy)
app.use('/api/gym-entry', gymEntryRoutes);

// Hardware Gateway Routes (card scan validation, command queue, gateway management)
app.use('/api/hardware', hardwareRoutes);

// Marketing campaign routes (Gym Owner / Branch Admin)
app.use('/api/marketing', marketingRoutes);

// Analytics routes (Churn Risk, Revenue Intelligence)
app.use('/api/analytics', analyticsRoutes);

// Automation rules routes (Gym Owner / Branch Admin)
app.use('/api/automations', automationRoutes);

// Gym Announcements (Gym Owner / Branch Admin)
app.use('/api/announcements', announcementRoutes);

// Training Sessions & Bookings
app.use('/api/sessions', sessionRoutes);

// Support Tickets
app.use('/api/support', supportRoutes);

// Trainer Assignment Requests
app.use('/api/assignment', assignmentRoutes);

// Audit Log
app.use('/api/audit', auditRoutes);

// Webhooks
app.use('/api/webhooks', webhookRoutes);

// Progress Rooms
app.use('/api/rooms', roomRoutes);

// User self-service (display name update, etc.)
app.use('/api/users', userRoutes);
app.use('/api/user', userRoutes); // handle singular requests from mobile

// Food database + logging (nutrition tracking)
app.use('/api/food', foodRoutes);

// Nutrition analytics: rolling averages for AI context + today's macro widget
app.use('/api/nutrition', nutritionStatsRoutes);

// Workout history + progressive overload
app.use('/api/workouts', workoutRoutes);

// AI plan generation (workout + diet) — triggers BullMQ workers
app.use('/api/ai', aiRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'amirani-backend-v2',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// Root route
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Amirani Backend API',
    documentation: 'https://amirani.esme.ge/health',
    status: 'online'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Global error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error', { message: err.message, stack: err.stack });
  return internalError(res);
});
// ─── Hourly Automation Processing ────────────────────────────────────────────
const AUTOMATION_INTERVAL_MS = 60 * 60 * 1000; // 1 hour
const automationInterval = setInterval(() => {
  AutomationService.processAll().catch((err) =>
    logger.error('[Automations] Hourly processing error', { err })
  );
  FreezeService.processAutoUnfreeze().catch((err) =>
    logger.error('[Freeze] Auto-unfreeze error', { err })
  );
  PaymentService.processExpiringSubscriptions().catch((err) =>
    logger.error('[Memberships] Auto-expiry processing error', { err })
  );
}, AUTOMATION_INTERVAL_MS);

// ─── Scheduled Notification Processing ──────────────────────────────────────
const NOTIFICATION_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const notificationInterval = setInterval(() => {
  NotificationService.processScheduledNotifications().catch((err) =>
    logger.error('[Notifications] Scheduled processing error', { err })
  );
}, NOTIFICATION_INTERVAL_MS);

// ─── QR Nonce Cleanup Cron (daily at 3am) ────────────────────────────────────
const QR_CLEANUP_INTERVAL_MS = 24 * 60 * 60 * 1000;
const qrCleanupInterval = setInterval(async () => {
  const { GymQrService } = await import('./modules/gym-entry/gym-qr.service');
  const deleted = await GymQrService.cleanupExpiredNonces().catch(() => 0);
  if (deleted > 0) logger.info(`[QR] Cleaned up ${deleted} expired nonces`);
}, QR_CLEANUP_INTERVAL_MS);

// ─── Start Queue Workers ──────────────────────────────────────────────────────
const workers = startAiWorkers();
SchedulerService.start();

// ─── Graceful Shutdown ────────────────────────────────────────────────────────
const shutdown = async (signal: string) => {
  logger.info(`Received ${signal}, shutting down gracefully...`, { service: 'amirani-api' });
  
  // Safety timeout to prevent hanging process
  const forceExitTimeout = setTimeout(() => {
    logger.warn('Cleanup took too long, forcing exit.', { signal });
    process.exit(1);
  }, 10000); // 10s safety margin

  try {
    // 0. Stop all background intervals and timers
    clearInterval(automationInterval);
    clearInterval(notificationInterval);
    clearInterval(qrCleanupInterval);
    SchedulerService.stop();

    // 1. Stop AI Workers (BullMQ) gracefully
    if (workers) {
      await Promise.all([
        workers.workoutWorker.close(),
        workers.dietWorker.close(),
        workers.pushWorker.close()
      ]).catch(err => logger.error('Error closing AI workers', { err }));
      logger.info('BullMQ workers stopped');
    }

    // 2. Stop accepting new connections and forcefully drop existing WebSockets
    const { getIO } = await import('./lib/socket');
    try {
      // io.close() automatically closes the underlying httpServer and drops all connected clients
      getIO().close();
      logger.info('WebSockets and HTTP server closed');
    } catch (err) {
      if (httpServer.listening) {
        if ('closeAllConnections' in httpServer) {
          (httpServer as any).closeAllConnections();
        }
        httpServer.close();
      }
    }

    // 3. Disconnect Prisma
    const prisma = await import('./lib/prisma').then(m => m.default);
    await prisma.$disconnect();
    logger.info('Prisma disconnected');

  } catch (err) {
    logger.error('Error during graceful shutdown', { err, signal });
  } finally {
    clearTimeout(forceExitTimeout);
    logger.info('Graceful shutdown complete', { signal });
    process.exit(0);
  }
};

// Handle termination signals
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));

// Handle nodemon/ts-node-dev restarts
process.on('SIGUSR2', () => shutdown('SIGUSR2'));

httpServer.listen(port, () => {
  const addr = httpServer.address();
  logger.info('Amirani Backend started', { port, env: config.nodeEnv, address: addr });
});

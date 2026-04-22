import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import config from '../config/env';
import prisma from './prisma';
import logger from './logger';

let io: Server;

export const initSocket = (server: HttpServer) => {
  io = new Server(server, {
    cors: {
      origin: '*', // For development. Update in production.
      methods: ['GET', 'POST']
    }
  });

  // ── Member / Admin Socket Auth ───────────────────────────────────────────
  io.use((socket: Socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.headers['authorization']?.split(' ')[1];

    // Mock token support — development only. Never accepted in production.
    if (config.isDevelopment && ['mock-admin-token', 'mock-owner-token', 'mock-branch-token', 'mock-branch-admin-token'].includes(token)) {
      socket.data.user = { userId: 'mocked-socket-user' };
      return next();
    }

    if (!token) {
      return next(new Error('Authentication error: No token provided'));
    }

    try {
      const decoded = jwt.verify(token, config.jwt.secret) as any;
      socket.data.user = {
        userId: decoded.userId,
        role: decoded.role,
        managedGymId: decoded.managedGymId
      };
      next();
    } catch (err) {
      next(new Error('Authentication error: Invalid token'));
    }
  });

  // ── Hardware Gateway Namespace: /gateway ─────────────────────────────────
  // Hardware devices (Raspberry Pi, ESP32, etc.) connect here with their apiKey.
  // They join room `gateway:<gatewayId>` to receive UNLOCK commands in real time.
  const gwNs = io.of('/gateway');

  gwNs.use(async (socket, next) => {
    const apiKey = socket.handshake.auth?.apiKey as string;
    if (!apiKey) return next(new Error('X-Gateway-Key required'));

    const gateway = await prisma.hardwareGateway.findUnique({ where: { apiKey } });
    if (!gateway) return next(new Error('Unknown gateway'));

    socket.data.gateway = gateway;
    next();
  });

  gwNs.on('connection', async (socket) => {
    const gateway = socket.data.gateway;
    logger.info('[WS/gateway] connected', { gatewayId: gateway.id, name: gateway.name });

    // Join private room so commands can be targeted
    socket.join(`gateway:${gateway.id}`);

    // Mark online
    await prisma.hardwareGateway.update({
      where: { id: gateway.id },
      data: { isOnline: true, lastSeenAt: new Date() },
    });

    // Gateway reports command execution result
    socket.on('ack', async ({ commandId, success: ok }: { commandId: string; success: boolean }) => {
      try {
        await prisma.gatewayCommand.update({
          where: { id: commandId, gatewayId: gateway.id },
          data: {
            status: ok ? 'EXECUTED' : 'FAILED',
            executedAt: new Date(),
          },
        });
      } catch { /* ignore stale acks */ }
    });

    socket.on('disconnect', async () => {
      logger.info('[WS/gateway] disconnected', { gatewayId: gateway.id });
      await prisma.hardwareGateway.update({
        where: { id: gateway.id },
        data: { isOnline: false },
      }).catch(() => {});
    });
  });

  // ── METERING / LIVE TELEMETRY Namespace: /telemetry ──────────────────────
  // Used by the Mobile App's Live Workout Tracker to stream exact durations
  // and RPE data for ultra-precise Caloric computations and Phase 4 Self-Training.
  const telemetryNs = io.of('/telemetry');
  
  telemetryNs.use((socket, next) => {
    // Re-use standard JWT auth logic
    const token = socket.handshake.auth?.token || socket.handshake.headers['authorization']?.split(' ')[1];
    if (!token) return next(new Error('Authentication error'));
    
    try {
      const decoded = jwt.verify(token, config.jwt.secret) as any;
      socket.data.user = { userId: decoded.userId };
      next();
    } catch {
      next(new Error('Authentication error'));
    }
  });

  telemetryNs.on('connection', (socket) => {
    const userId = socket.data.user.userId;
    logger.info(`[WS/telemetry] User ${userId} connected to Live Tracker`);

    // The user connects to their own secure channel
    socket.join(`telemetry:${userId}`);

    // Receive live SET completions exactly as they happen
    socket.on('log_set', async (data: {
       routineId: string, 
       exerciseLibraryId?: string, 
       durationSeconds: number, 
       weightKg: number, 
       reps: number, 
       rpe?: number 
    }) => {
       logger.info(`[WS/telemetry] User ${userId} logged a set`, data);
       
       // Note: Currently we don't save the set directly to DB upon websocket 'log_set' 
       // because workout.controller.ts bulk-saves the entire workout at the end.
       // However, receiving it live allows us to broadcast leaderboard changes,
       // trigger motivational Push Notifications, or track Heart-Rate in future phases.
       
       // We bounce an AK back to the flutter client
       socket.emit('set_synced', { success: true, timestamp: Date.now() });
    });

    socket.on('disconnect', () => {
       logger.info(`[WS/telemetry] User ${userId} disconnected from Live Tracker`);
    });
  });

  return io;
};

export const getIO = () => {
  if (!io) {
    throw new Error('Socket.io not initialized!');
  }
  return io;
};

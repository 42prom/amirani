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
      origin: config.isDevelopment ? '*' : (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean),
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

  // ── CHALLENGE ROOMS Namespace: /challenge-rooms ───────────────────────────
  const roomsNs = io.of('/challenge-rooms');

  roomsNs.use((socket, next) => {
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

  roomsNs.on('connection', (socket) => {
    const userId = socket.data.user.userId;

    // Verify DB membership before joining the socket room — prevents eavesdropping.
    socket.on('join_room', async (roomId: string) => {
      try {
        const member = await prisma.roomMembership.findUnique({
          where: { roomId_userId: { roomId, userId } },
          select: { id: true },
        });
        if (!member) {
          socket.emit('error', { message: 'Not a member of this room' });
          return;
        }
        socket.join(`room:${roomId}`);
        logger.info(`[WS/rooms] User ${userId} joined room ${roomId}`);
      } catch (err) {
        socket.emit('error', { message: 'Failed to join room' });
      }
    });

    socket.on('leave_room', (roomId: string) => {
      socket.leave(`room:${roomId}`);
      logger.info(`[WS/rooms] User ${userId} left room ${roomId}`);
    });

    socket.on('send_message', async (data: { roomId: string, body: string, imageUrl?: string }) => {
      try {
        const { RoomService } = require('../modules/rooms/room.service');
        // RoomService.sendMessage already emits 'new_message' via Socket.IO — do not re-emit.
        await RoomService.sendMessage(data.roomId, userId, data.body, data.imageUrl);
      } catch (err) {
        socket.emit('error', { message: (err as Error).message });
      }
    });

    socket.on('disconnect', () => {
      logger.info(`[WS/rooms] User ${userId} disconnected`);
    });
  });

  // ── TRAINER CHAT Namespace: /trainer-chat ─────────────────────────────────
  const trainerChatNs = io.of('/trainer-chat');

  trainerChatNs.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.headers['authorization']?.split(' ')[1];
    if (!token) return next(new Error('Authentication error'));
    try {
      const decoded = jwt.verify(token, config.jwt.secret) as any;
      socket.data.user = { userId: decoded.userId, role: decoded.role };
      next();
    } catch {
      next(new Error('Authentication error'));
    }
  });

  trainerChatNs.on('connection', (socket) => {
    const { userId } = socket.data.user;

    socket.on('join_ticket', (ticketId: string) => {
      socket.join(`ticket:${ticketId}`);
      logger.info(`[WS/trainer-chat] User ${userId} joined ticket ${ticketId}`);
    });

    socket.on('leave_ticket', (ticketId: string) => {
      socket.leave(`ticket:${ticketId}`);
    });

    socket.on('send_message', async (data: { ticketId: string; gymId: string; body: string }) => {
      try {
        // Verify the user is a participant in this ticket before processing.
        // Prevents any authenticated user from injecting messages into foreign tickets.
        const ticket = await prisma.supportTicket.findUnique({
          where: { id: data.ticketId },
          select: { userId: true, trainerId: true, gymId: true },
        });
        if (!ticket || ticket.gymId !== data.gymId) {
          socket.emit('error', { message: 'Ticket not found' });
          return;
        }
        const isOwner = ticket.userId === userId;
        let isAssignedTrainer = false;
        if (!isOwner && ticket.trainerId) {
          const profile = await prisma.trainerProfile.findUnique({
            where: { id: ticket.trainerId },
            select: { userId: true },
          });
          isAssignedTrainer = profile?.userId === userId;
        }
        if (!isOwner && !isAssignedTrainer) {
          socket.emit('error', { message: 'Access denied' });
          return;
        }

        const { SupportService } = require('../modules/support/support.service');
        const message = await SupportService.replyToTicket(
          data.ticketId, data.gymId, userId, socket.data.user.role, null, data.body
        );
        trainerChatNs.to(`ticket:${data.ticketId}`).emit('new_message', message);
      } catch (err) {
        socket.emit('error', { message: (err as Error).message });
      }
    });

    socket.on('disconnect', () => {
      logger.info(`[WS/trainer-chat] User ${userId} disconnected`);
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

import prisma from '../../utils/prisma';
import { AccessControlService } from '../door-access/access-control.service';
import { awardPoints, POINTS } from '../../lib/leaderboard.service';
import logger from '../../utils/logger';
import { getIO } from '../../utils/socket';
import { GatewayCmd, CommandStatus } from '@prisma/client';

// ─── Gateway Registration ─────────────────────────────────────────────────────

// Map gateway protocol → door system type
const PROTOCOL_TO_DOOR_TYPE: Record<string, string> = {
  RELAY_HTTP: 'NFC',
  WIEGAND:    'NFC',
  OSDP_V2:   'NFC',
  ZKTECO_TCP: 'NFC',
  MQTT:       'NFC',
};

export async function registerGateway(params: {
  gymId: string;
  name: string;
  location?: string;
  protocol: string;
  config?: Record<string, unknown>;
}) {
  // 1. Create the physical gateway record
  const gateway = await prisma.hardwareGateway.create({
    data: {
      gymId: params.gymId,
      name: params.name,
      location: params.location,
      protocol: params.protocol as any,
      config: params.config as any,
    },
  });

  // 2. Auto-create the linked logical door system (so gym owners
  //    don't need to manually create one in Access Points).
  //    Uses upsert keyed on gatewayId stored in config to avoid
  //    duplicates on re-registration.
  const doorType = PROTOCOL_TO_DOOR_TYPE[params.protocol] ?? 'NFC';
  await prisma.doorSystem.create({
    data: {
      gymId: params.gymId,
      name: params.name,
      type: doorType as any,
      location: params.location,
      isActive: true,
      vendorConfig: { gatewayId: gateway.id } as any,
    },
  });

  logger.info('[HW] Gateway registered + door system created', {
    gatewayId: gateway.id,
    name: gateway.name,
  });
  return gateway;
}

export async function getGatewaysForGym(gymId: string) {
  return prisma.hardwareGateway.findMany({
    where: { gymId },
    include: { _count: { select: { commands: true } } },
    orderBy: { createdAt: 'desc' },
  });
}

// Gateway heartbeat — called periodically by the hardware device
export async function gatewayHeartbeat(apiKey: string) {
  const gateway = await prisma.hardwareGateway.update({
    where: { apiKey },
    data: { isOnline: true, lastSeenAt: new Date() },
  });
  return gateway;
}

export async function markGatewayOffline(apiKey: string) {
  await prisma.hardwareGateway.update({
    where: { apiKey },
    data: { isOnline: false },
  });
}

// ─── Card Credential Management ───────────────────────────────────────────────

export async function enrollCard(params: {
  gymId: string;
  userId: string;
  cardUid: string;
  cardType: string;
  facilityCode?: number;
  cardNumber?: number;
  label?: string;
}) {
  // Normalize UID: uppercase, no spaces/colons
  const normalized = params.cardUid.replace(/[:\s-]/g, '').toUpperCase();

  // Check for conflict in gym
  const existing = await prisma.cardCredential.findUnique({
    where: { gymId_cardUid: { gymId: params.gymId, cardUid: normalized } },
  });
  if (existing && existing.userId !== params.userId) {
    throw Object.assign(new Error('Card already assigned to another member'), { status: 409 });
  }

  return prisma.cardCredential.upsert({
    where: { gymId_cardUid: { gymId: params.gymId, cardUid: normalized } },
    update: {
      userId: params.userId,
      cardType: params.cardType as any,
      facilityCode: params.facilityCode,
      cardNumber: params.cardNumber,
      label: params.label,
      isActive: true,
    },
    create: {
      gymId: params.gymId,
      userId: params.userId,
      cardUid: normalized,
      cardType: params.cardType as any,
      facilityCode: params.facilityCode,
      cardNumber: params.cardNumber,
      label: params.label,
    },
  });
}

export async function getCardsForUser(userId: string, gymId: string) {
  return prisma.cardCredential.findMany({
    where: { userId, gymId, isActive: true },
    orderBy: { createdAt: 'desc' },
  });
}

export async function getCardsForGym(gymId: string) {
  return prisma.cardCredential.findMany({
    where: { gymId, isActive: true },
    include: { user: { select: { id: true, fullName: true, avatarUrl: true } } },
    orderBy: { createdAt: 'desc' },
  });
}

export async function revokeCard(id: string, gymId: string) {
  return prisma.cardCredential.update({
    where: { id },
    data: { isActive: false },
  });
}

/**
 * Returns the active, non-expired membership for a user in a gym, or null.
 * Used by the card enrollment endpoint to gate credential creation.
 */
export async function getActiveMembership(userId: string, gymId: string) {
  return prisma.gymMembership.findFirst({
    where: {
      userId,
      gymId,
      status: 'ACTIVE',
      endDate: { gte: new Date() },
    },
    select: { id: true, endDate: true },
  });
}

// ─── Core: Card Scan Validation ───────────────────────────────────────────────
//
// Called by the hardware gateway when a physical card or phone (HCE) is tapped.
// Returns grant/deny + pushes UNLOCK command to gateway via WebSocket.

export async function validateCardScan(params: {
  apiKey: string;        // gateway identifies itself
  cardUid: string;       // raw UID from reader
  doorId?: string;       // optional door identifier on this gateway
  readerLocation?: string;
  deviceInfo?: string;
}): Promise<{
  granted: boolean;
  reason?: string;
  userId?: string;
  memberName?: string;
  planName?: string;
  daysRemaining?: number;
}> {
  const normalized = params.cardUid.replace(/[:\s-]/g, '').toUpperCase();

  // 1. Resolve gateway
  const gateway = await prisma.hardwareGateway.findUnique({
    where: { apiKey: params.apiKey },
    include: { gym: { select: { id: true, name: true } } },
  });
  if (!gateway) {
    return { granted: false, reason: 'Unknown gateway' };
  }

  // 2. Keep gateway online
  await prisma.hardwareGateway.update({
    where: { id: gateway.id },
    data: { isOnline: true, lastSeenAt: new Date() },
  });

  const gymId = gateway.gymId;

  // 3. Look up card credential
  const credential = await prisma.cardCredential.findUnique({
    where: { gymId_cardUid: { gymId, cardUid: normalized } },
  });
  if (!credential || !credential.isActive) {
    await _logAccess(gymId, null, gateway.id, false, params.deviceInfo);
    return { granted: false, reason: 'Card not recognized or deactivated' };
  }

  const userId = credential.userId;

  // 4. Find the door system specifically linked to this gateway (set in vendorConfig.gatewayId
  //    when registerGateway auto-creates it). Fall back to any active NFC system, then any active system.
  let doorSystem = await prisma.doorSystem.findFirst({
    where: {
      gymId,
      isActive: true,
      vendorConfig: { path: ['gatewayId'], equals: gateway.id },
    },
  });
  if (!doorSystem) {
    doorSystem = await prisma.doorSystem.findFirst({ where: { gymId, type: 'NFC', isActive: true } });
  }
  if (!doorSystem) {
    doorSystem = await prisma.doorSystem.findFirst({ where: { gymId, isActive: true } });
  }

  let accessResult: { allowed: boolean; reason?: string; membership?: any } = { allowed: true, membership: null };
  if (doorSystem) {
    const raw = await AccessControlService.validateAndLogAccess(
      userId, gymId, doorSystem.id, params.deviceInfo
    );
    accessResult = { allowed: raw.allowed, reason: raw.reason, membership: raw.membership };
  } else {
    // No door system configured — still check membership
    const membership = await prisma.gymMembership.findFirst({
      where: { userId, gymId, status: 'ACTIVE' },
      include: { plan: { select: { name: true } } },
    });
    if (!membership) {
      await _logAccess(gymId, userId, gateway.id, false, params.deviceInfo);
      return { granted: false, reason: 'No active membership' };
    }
    accessResult.membership = membership;
  }

  if (!accessResult.allowed) {
    await _logAccess(gymId, userId, gateway.id, false, params.deviceInfo);
    return { granted: false, reason: accessResult.reason || 'Access denied' };
  }

  // 5. Anti-passback: check existing session
  const existingSession = await prisma.attendance.findFirst({
    where: { userId, gymId, checkOut: null },
  });

  if (!existingSession) {
    // Create attendance record
    const attendance = await prisma.attendance.create({ data: { userId, gymId } });

    // Award leaderboard points (fire-and-forget)
    awardPoints({
      userId,
      sourceId: attendance.id,
      sourceType: 'CHECKIN',
      delta: POINTS.CHECKIN,
      reason: `Card check-in at ${gateway.gym.name}`,
    }).catch((err) => logger.error('[HW] awardPoints error', { err }));
  }

  await _logAccess(gymId, userId, gateway.id, true, params.deviceInfo);

  // 6. Push UNLOCK command to gateway via WebSocket
  await pushUnlockCommand(gateway.id, params.doorId, userId);

  // 7. Build response
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { fullName: true },
  });

  const membership = accessResult.membership;
  const now = new Date();
  const daysRemaining = membership?.endDate
    ? Math.max(0, Math.ceil((new Date(membership.endDate).getTime() - now.getTime()) / 86400000))
    : undefined;

  return {
    granted: true,
    userId,
    memberName: user?.fullName ?? 'Member',
    planName: membership?.plan?.name ?? membership?.planName ?? 'Member',
    daysRemaining,
  };
}

// ─── Command Queue ────────────────────────────────────────────────────────────

export async function pushUnlockCommand(
  gatewayId: string,
  doorId?: string,
  triggeredBy?: string,
  durationMs = 3000,
) {
  const expiresAt = new Date(Date.now() + 15_000); // 15s to pick up

  const cmd = await prisma.gatewayCommand.create({
    data: {
      gatewayId,
      doorId,
      command: GatewayCmd.UNLOCK,
      payload: { durationMs },
      triggeredBy,
      expiresAt,
      status: CommandStatus.PENDING,
    },
  });

  // Try real-time WebSocket push to the gateway's private room
  try {
    const io = getIO();
    io.to(`gateway:${gatewayId}`).emit('command', {
      id: cmd.id,
      command: 'UNLOCK',
      doorId,
      payload: { durationMs },
    });
    await prisma.gatewayCommand.update({
      where: { id: cmd.id },
      data: { status: CommandStatus.SENT },
    });
  } catch {
    // Gateway not connected via WS — it will poll via REST
  }

  return cmd;
}

// Gateway acknowledges command execution
export async function acknowledgeCommand(commandId: string, apiKey: string, success: boolean) {
  const gateway = await prisma.hardwareGateway.findUnique({ where: { apiKey } });
  if (!gateway) throw Object.assign(new Error('Unknown gateway'), { status: 401 });

  return prisma.gatewayCommand.update({
    where: { id: commandId, gatewayId: gateway.id },
    data: {
      status: success ? CommandStatus.EXECUTED : CommandStatus.FAILED,
      executedAt: new Date(),
    },
  });
}

// Gateway polls for pending commands
export async function pollCommands(apiKey: string) {
  const gateway = await prisma.hardwareGateway.findUnique({ where: { apiKey } });
  if (!gateway) throw Object.assign(new Error('Unknown gateway'), { status: 401 });

  await prisma.hardwareGateway.update({
    where: { id: gateway.id },
    data: { isOnline: true, lastSeenAt: new Date() },
  });

  const now = new Date();

  // Expire stale commands
  await prisma.gatewayCommand.updateMany({
    where: { gatewayId: gateway.id, status: CommandStatus.PENDING, expiresAt: { lt: now } },
    data: { status: CommandStatus.EXPIRED },
  });

  // Return pending commands
  const commands = await prisma.gatewayCommand.findMany({
    where: { gatewayId: gateway.id, status: { in: [CommandStatus.PENDING, CommandStatus.SENT] } },
    orderBy: { createdAt: 'asc' },
  });

  // Mark as sent
  if (commands.length > 0) {
    await prisma.gatewayCommand.updateMany({
      where: { id: { in: commands.map((c) => c.id) } },
      data: { status: CommandStatus.SENT },
    });
  }

  return commands;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function _logAccess(
  gymId: string,
  userId: string | null,
  gatewayId: string,
  granted: boolean,
  deviceInfo?: string,
) {
  if (!userId) return;
  // Prefer the door system linked to this exact gateway, then any active system
  let ds = await prisma.doorSystem.findFirst({
    where: { gymId, isActive: true, vendorConfig: { path: ['gatewayId'], equals: gatewayId } },
  });
  if (!ds) ds = await prisma.doorSystem.findFirst({ where: { gymId } });
  if (!ds) return;

  await prisma.doorAccessLog.create({
    data: {
      userId,
      doorSystemId: ds.id,
      accessGranted: granted,
      method: 'NFC',
      deviceInfo: deviceInfo ?? `gateway:${gatewayId}`,
    },
  });
}

// ─── Access Statistics ────────────────────────────────────────────────────────

export async function getAccessStats(gymId: string) {
  const now = new Date();
  const startOf30Days = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

  // All logs in the last 30 days for this gym's door systems
  const logs = await prisma.doorAccessLog.findMany({
    where: {
      doorSystem: { gymId },
      accessTime: { gte: startOf30Days },
    },
    select: {
      id: true,
      accessGranted: true,
      accessTime: true,
      method: true,
      user: { select: { id: true, fullName: true, avatarUrl: true } },
    },
    orderBy: { accessTime: 'desc' },
  });

  const total = logs.length;
  const granted = logs.filter((l) => l.accessGranted).length;
  const denied = total - granted;
  const today = logs.filter((l) => l.accessTime >= startOfToday).length;
  const week = logs.filter((l) => l.accessTime >= startOfWeek).length;

  // Peak hours: count by hour-of-day (0-23)
  const hourBuckets: number[] = new Array(24).fill(0);
  logs.forEach((l) => { if (l.accessGranted) hourBuckets[l.accessTime.getHours()]++; });

  // Daily trend: last 14 days
  const dailyBuckets: Record<string, { date: string; granted: number; denied: number }> = {};
  for (let i = 13; i >= 0; i--) {
    const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
    const key = d.toISOString().slice(0, 10);
    dailyBuckets[key] = { date: key, granted: 0, denied: 0 };
  }
  logs.forEach((l) => {
    const key = l.accessTime.toISOString().slice(0, 10);
    if (dailyBuckets[key]) {
      l.accessGranted ? dailyBuckets[key].granted++ : dailyBuckets[key].denied++;
    }
  });

  // Top members (by granted scans, last 30 days)
  const memberMap: Record<string, { userId: string; fullName: string; avatarUrl?: string; count: number }> = {};
  logs.filter((l) => l.accessGranted && l.user).forEach((l) => {
    const uid = l.user!.id;
    if (!memberMap[uid]) memberMap[uid] = { userId: uid, fullName: l.user!.fullName, avatarUrl: l.user?.avatarUrl ?? undefined, count: 0 };
    memberMap[uid].count++;
  });
  const topMembers = Object.values(memberMap).sort((a, b) => b.count - a.count).slice(0, 10);

  return {
    total,
    granted,
    denied,
    grantRate: total > 0 ? Math.round((granted / total) * 100) : 0,
    today,
    week,
    peakHours: hourBuckets.map((count, hour) => ({ hour, count })),
    dailyTrend: Object.values(dailyBuckets),
    topMembers,
  };
}

// ─── Gateway Deletion ─────────────────────────────────────────────────────────

export async function deleteGateway(gatewayId: string, gymId: string) {
  // Also deactivate the linked door system so it no longer appears in Access Points
  await prisma.doorSystem.updateMany({
    where: {
      gymId,
      vendorConfig: { path: ['gatewayId'], equals: gatewayId },
    },
    data: { isActive: false },
  });

  return prisma.hardwareGateway.delete({ where: { id: gatewayId } });
}


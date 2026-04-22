import {
  INotificationProvider,
  NotificationPayload,
  NotificationResult,
} from './notification-provider.interface';
import prisma from '../../../lib/prisma';
import { decryptField } from '../../../lib/db-crypto';
import logger from '../../../lib/logger';

// ─── Firebase Admin SDK (lazy init) ──────────────────────────────────────────

let firebaseApp: any = null;
let firebaseCredKey = '';

async function getFirebaseMessaging(): Promise<any | null> {
  try {
    const cfg = await prisma.pushNotificationConfig.findUnique({ where: { id: 'singleton' } });
    const projectId   = cfg?.fcmProjectId   || process.env.FIREBASE_PROJECT_ID;
    const privateKey  = decryptField(cfg?.fcmPrivateKey)  || process.env.FIREBASE_PRIVATE_KEY;
    const clientEmail = cfg?.fcmClientEmail || process.env.FIREBASE_CLIENT_EMAIL;
    const enabled     = cfg?.fcmEnabled ?? (!!projectId);

    if (!enabled || !projectId || !privateKey || !clientEmail) return null;

    const credKey = `${projectId}:${clientEmail}`;
    if (!firebaseApp || firebaseCredKey !== credKey) {
      const admin = await import('firebase-admin');
      if (firebaseApp) {
        try { await firebaseApp.delete(); } catch {}
      }
      const appName = `amirani_${Date.now()}`;
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          privateKey: privateKey.replace(/\\n/g, '\n'),
          clientEmail,
        }),
      }, appName);
      firebaseCredKey = credKey;
    }

    const admin = await import('firebase-admin');
    return admin.messaging(firebaseApp);
  } catch (e) {
    logger.error('[FCM] Failed to initialise Firebase Admin SDK', { e });
    return null;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

export class PushNotificationProvider implements INotificationProvider {
  readonly type = 'PUSH' as const;

  async send(payload: NotificationPayload, fcmToken?: string): Promise<NotificationResult> {
    if (!fcmToken) {
      return { success: false, error: 'FCM token not provided' };
    }

    const messaging = await getFirebaseMessaging();

    if (!messaging) {
      // Dev fallback — log and simulate success
      logger.debug(`[Push:dev] ${payload.userId}: ${payload.title}`);
      return { success: true, messageId: `dev_${Date.now()}` };
    }

    try {
      const messageId = await messaging.send({
        notification: { title: payload.title, body: payload.body },
        data: Object.fromEntries(
          Object.entries(payload.data || {}).map(([k, v]) => [k, String(v)])
        ),
        token: fcmToken,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } },
      });
      return { success: true, messageId };
    } catch (error: any) {
      logger.error('[FCM] send error', { error });
      return { success: false, error: error.message };
    }
  }

  async sendBatch(payloads: NotificationPayload[], fcmTokens?: string[]): Promise<NotificationResult[]> {
    if (!fcmTokens || fcmTokens.length !== payloads.length) {
      return payloads.map(() => ({ success: false, error: 'Token count mismatch' }));
    }

    const messaging = await getFirebaseMessaging();
    if (!messaging) {
      return payloads.map((p) => {
        logger.debug(`[Push:dev] ${p.userId}: ${p.title}`);
        return { success: true, messageId: `dev_${Date.now()}` };
      });
    }

    try {
      const response = await messaging.sendEach(
        payloads.map((p, i) => ({
          notification: { title: p.title, body: p.body },
          data: Object.fromEntries(Object.entries(p.data || {}).map(([k, v]) => [k, String(v)])),
          token: fcmTokens[i],
        }))
      );
      return response.responses.map((r: any) => ({
        success: r.success,
        messageId: r.messageId,
        error: r.error?.message,
      }));
    } catch (error: any) {
      return payloads.map(() => ({ success: false, error: error.message }));
    }
  }

  async isAvailable(): Promise<boolean> {
    const m = await getFirebaseMessaging();
    return m !== null;
  }
}

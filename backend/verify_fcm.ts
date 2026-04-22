import prisma from './src/lib/prisma';
import * as admin from 'firebase-admin';

async function checkFirebase() {
  console.log('--- Firebase Connectivity Audit ---');
  try {
    const cfg = await (prisma as any).pushNotificationConfig.findUnique({ where: { id: 'singleton' } });
    
    if (!cfg) {
      console.error('❌ No configuration found in push_notification_configs (id=singleton)');
      return;
    }

    const { fcmProjectId, fcmClientEmail, fcmPrivateKey, fcmEnabled } = cfg;

    console.log('Project ID:', fcmProjectId || 'MISSING');
    console.log('Client Email:', fcmClientEmail || 'MISSING');
    console.log('Private Key:', fcmPrivateKey ? 'PRESENT (HIDDEN)' : 'MISSING');
    console.log('Enabled:', fcmEnabled);

    if (!fcmProjectId || !fcmClientEmail || !fcmPrivateKey) {
      console.error('❌ Credentials incomplete.');
      return;
    }

    // Attempt dry-run init
    try {
      const app = admin.initializeApp({
        credential: admin.credential.cert({
          projectId: fcmProjectId,
          clientEmail: fcmClientEmail,
          privateKey: fcmPrivateKey.replace(/\\n/g, '\n'),
        }),
      }, 'audit_app');
      
      console.log('✅ Firebase Admin SDK Initialized successfully with provided credentials.');
      await app.delete();
    } catch (err: any) {
      console.error('❌ Firebase Initialization Failed:', err.message);
    }

  } catch (err: any) {
    console.error('❌ Database Query Failed:', err.message);
  } finally {
    await prisma.$disconnect();
  }
}

checkFirebase();

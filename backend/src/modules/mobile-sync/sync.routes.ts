// src/modules/mobile-sync/sync.routes.ts
import { Router } from 'express';
import { SyncController } from './sync.controller';
import { AIController } from './ai.controller';
import { MobileController } from './mobile.controller';
import { authenticate } from '../../middleware/auth.middleware';

const router = Router();

// Apply Authentication middleware immediately
router.use(authenticate);

// Explicit mobile data fetch endpoints
router.get('/workout/plan', MobileController.getActiveWorkoutPlan);
router.get('/diet/plan', MobileController.getActiveDietPlan);
router.patch('/diet/meals/:refId/log', MobileController.logMeal);
router.get('/diet/macros', MobileController.getDailyMacros);
router.get('/equipment', MobileController.getEquipment);
router.get('/tier-limits', MobileController.getTierLimits);
router.post('/recovery', MobileController.logRecovery);
router.get('/recovery/today', MobileController.getTodayRecovery);
router.post('/workout-history', MobileController.logWorkoutHistory);
router.post('/weight', MobileController.logWeightEntry);
router.get('/progress', MobileController.getProgressSummary);

// Offline State Delta Sync
router.post('/up', SyncController.syncUp);
router.get('/down', SyncController.syncDown);

// AI Generation (async — returns jobId immediately)
router.post('/ai/generate-plan', AIController.generatePlan);
// AI Job Status (client polls this or waits for push notification)
router.get('/ai/status/:jobId', AIController.getJobStatus);

export { router as syncRoutes };

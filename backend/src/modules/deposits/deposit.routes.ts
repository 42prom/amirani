import { Router } from 'express';
import { DepositController } from './deposit.controller';
import { authenticate, authorize } from '../../middleware/auth.middleware';
import { Role } from '@prisma/client';

const router = Router();

// Apply auth middleware to all routes
router.use(authenticate);

// Super Admin Only: Get all deposits globally
router.get(
  '/admin/all',
  authorize(Role.SUPER_ADMIN),
  DepositController.getAllDeposits
);

// Super Admin Only: Update deposit status
router.patch(
  '/admin/:depositId/status',
  authorize(Role.SUPER_ADMIN),
  DepositController.updateDepositStatus
);

// Gym Owners and Branch Managers: Submit a new deposit for a gym
router.post(
  '/gym/:gymId',
  authorize(Role.SUPER_ADMIN, Role.GYM_OWNER, Role.BRANCH_ADMIN),
  DepositController.submitDeposit
);

// Gym Owners and Branch Managers: Get deposits for a specific gym
router.get(
  '/gym/:gymId',
  authorize(Role.SUPER_ADMIN, Role.GYM_OWNER, Role.BRANCH_ADMIN),
  DepositController.getGymDeposits
);

export default router;

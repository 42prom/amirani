import { Router, Response } from 'express';
import { randomBytes } from 'crypto';
import prisma from '../../lib/prisma';
import logger from '../../lib/logger';
import { authenticate, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { success, internalError } from '../../utils/response';

const router = Router();
router.use(authenticate);

function generateCode(): string {
  return randomBytes(4).toString('hex').toUpperCase(); // e.g. "A3F7C2B1"
}

// GET /referrals/my-code — get (or auto-create) the caller's referral code
router.get('/my-code', async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.userId;
  try {
    let record = await prisma.referralCode.findUnique({ where: { ownerId: userId } });

    if (!record) {
      // Generate a unique code (retry on collision — extremely rare)
      let code = generateCode();
      let attempts = 0;
      while (attempts < 5) {
        const exists = await prisma.referralCode.findUnique({ where: { code } });
        if (!exists) break;
        code = generateCode();
        attempts++;
      }
      record = await prisma.referralCode.create({
        data: { id: crypto.randomUUID(), code, ownerId: userId },
      });
    }

    return success(res, {
      code: record.code,
      usedCount: record.usedCount,
      pointsEarned: record.pointsEarned,
      shareLink: `amirani://join?ref=${record.code}`,
    });
  } catch (err) {
    logger.error('[Referral] my-code error', { err });
    internalError(res);
  }
});

export default router;

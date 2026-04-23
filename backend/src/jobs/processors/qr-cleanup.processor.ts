import { GymQrService } from '../../modules/gym-entry/gym-qr.service';
import logger from '../../lib/logger';

export async function processQrCleanup() {
  const deleted = await GymQrService.cleanupExpiredNonces().catch(() => 0);
  if (deleted > 0) logger.info(`[QR] Cleaned up ${deleted} expired nonces`);
}

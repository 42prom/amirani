import { AutomationService } from '../../modules/automations/automation.service';
import { FreezeService } from '../../modules/memberships/freeze.service';
import { PaymentService } from '../../modules/payments/payment.service';
import { SaaSService } from '../../modules/platform/saas.service';
import logger from '../../lib/logger';

export async function processAutomationHourly() {
  logger.info('[CRON] Running hourly automation batch');
  await Promise.allSettled([
    AutomationService.processAll().catch((err) =>
      logger.error('[Automations] processAll error', { err })),
    FreezeService.processAutoUnfreeze().catch((err) =>
      logger.error('[Freeze] processAutoUnfreeze error', { err })),
    PaymentService.processExpiringSubscriptions().catch((err) =>
      logger.error('[Memberships] processExpiringSubscriptions error', { err })),
    SaaSService.processSaaSTrialExpiry().catch((err) =>
      logger.error('[SaaS] processSaaSTrialExpiry error', { err })),
  ]);
}

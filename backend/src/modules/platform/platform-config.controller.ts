import { Router, Response } from 'express';
import { AuthenticatedRequest, authenticate, superAdminOnly } from '../../middleware/auth.middleware';
import { PlatformConfigService, PlatformConfigError } from './platform-config.service';
import { success, badRequest, serverError } from '../../utils/response';
import logger from '../../utils/logger';
import { AIProvider, UserTier } from '@prisma/client';

const router = Router();

// ─── SaaS Status (Gym Owner & Super Admin) ──────────────────────────────────
import { SaaSService } from './saas.service';

/**
 * GET /platform/saas/status
 * Get the SaaS subscription status for the current owner
 */
router.get('/saas/status', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const status = await SaaSService.getOwnerSaaSStatus(req.user!.userId);
    return success(res, status);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /platform/saas/invoices
 * Get billing history for the current owner
 */
router.get('/saas/invoices', authenticate, async (req: AuthenticatedRequest, res: Response) => {
  try {
    const invoices = await SaaSService.getOwnerInvoices(req.user!.userId);
    return success(res, invoices);
  } catch (error: any) {
    return serverError(res, error);
  }
});

// All following routes require Super Admin access
router.use(authenticate, superAdminOnly);

/**
 * GET /platform/saas/subscriptions
 * Get all SaaS subscriptions for the platform (Super Admin only)
 */
router.get('/saas/subscriptions', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const subscriptions = await SaaSService.getAllSubscriptions();
    return success(res, subscriptions);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /platform/saas/subscriptions/:ownerId/extend
 * Manually extend a Gym Owner's SaaS subscription (Super Admin only)
 */
router.post('/saas/subscriptions/:ownerId/extend', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { ownerId } = req.params;
    const { days, amount, paymentMethod, notes } = req.body;

    if (!days || !amount || !paymentMethod) {
      return badRequest(res, 'Missing required fields: days, amount, paymentMethod');
    }

    const result = await SaaSService.extendSaaSSubscription(ownerId, {
      days: Number(days),
      amount: Number(amount),
      paymentMethod,
      notes,
    });

    return success(res, result, 'SaaS subscription extended successfully');
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/saas/subscriptions/:ownerId/pricing
 * Update a Gym Owner's SaaS pricing overrides (Super Admin only)
 */
router.patch('/saas/subscriptions/:ownerId/pricing', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { ownerId } = req.params;
    const { isLifetimeFree, customPricePerBranch, customPlatformFeePercent } = req.body;

    const result = await SaaSService.updateSaaSPricing(ownerId, {
      isLifetimeFree: isLifetimeFree !== undefined ? Boolean(isLifetimeFree) : undefined,
      customPricePerBranch: customPricePerBranch !== undefined ? (customPricePerBranch === null ? null : Number(customPricePerBranch)) : undefined,
      customPlatformFeePercent: customPlatformFeePercent !== undefined ? (customPlatformFeePercent === null ? null : Number(customPlatformFeePercent)) : undefined,
    });

    return success(res, result, 'SaaS pricing overrides updated successfully');
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── Platform Config ──────────────────────────────────────────────────────────

/**
 * GET /platform/config
 * Get platform configuration
 */
router.get('/config', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const config = await PlatformConfigService.getPlatformConfig();
    return success(res, config);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/config
 * Update platform configuration
 */
router.patch('/config', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { 
      platformName, 
      platformLogoUrl, 
      supportEmail, 
      privacyPolicyUrl, 
      termsOfServiceUrl, 
      maintenanceMode,
      pricePerBranch,
      defaultTrialDays,
      currency,
    } = req.body;

    const config = await PlatformConfigService.updatePlatformConfig({
      platformName,
      platformLogoUrl,
      supportEmail,
      privacyPolicyUrl,
      termsOfServiceUrl,
      maintenanceMode,
      pricePerBranch,
      defaultTrialDays,
      currency,
    });

    return success(res, config, 'Platform config updated');
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── AI Config ────────────────────────────────────────────────────────────────

/**
 * GET /platform/ai
 * Get AI configuration (keys masked)
 */
router.get('/ai', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const config = await PlatformConfigService.getAIConfig();
    return success(res, config);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/ai
 * Update AI configuration
 */
router.patch('/ai', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const {
      activeProvider,
      openaiApiKey,
      openaiModel,
      openaiOrgId,
      anthropicApiKey,
      anthropicModel,
      googleApiKey,
      googleModel,
      azureApiKey,
      azureEndpoint,
      azureDeploymentName,
      deepseekApiKey,
      deepseekModel,
      deepseekBaseUrl,
      maxTokensPerRequest,
      temperature,
      isEnabled,
    } = req.body;

    // Validate provider if provided
    if (activeProvider && !['OPENAI', 'ANTHROPIC', 'GOOGLE_GEMINI', 'AZURE_OPENAI', 'DEEPSEEK'].includes(activeProvider)) {
      return badRequest(res, 'Invalid AI provider');
    }

    // Guard: providers accepted in DB schema but not yet implemented in the generation worker
    if (activeProvider && ['AZURE_OPENAI', 'GOOGLE_GEMINI'].includes(activeProvider)) {
      return badRequest(res, `Provider ${activeProvider} is not yet implemented. Use OPENAI, ANTHROPIC, or DEEPSEEK.`);
    }

    const config = await PlatformConfigService.updateAIConfig({
      activeProvider,
      openaiApiKey,
      openaiModel,
      openaiOrgId,
      anthropicApiKey,
      anthropicModel,
      googleApiKey,
      googleModel,
      azureApiKey,
      azureEndpoint,
      azureDeploymentName,
      deepseekApiKey,
      deepseekModel,
      deepseekBaseUrl,
      maxTokensPerRequest,
      temperature,
      isEnabled,
      actorId: req.user!.userId,
    });

    // Return masked version
    const maskedConfig = await PlatformConfigService.getAIConfig();
    return success(res, maskedConfig, 'AI config updated');
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /platform/ai/test
 * Test AI provider connection
 */
router.post('/ai/test', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { provider } = req.body;

    if (!provider || !['OPENAI', 'ANTHROPIC', 'GOOGLE_GEMINI', 'AZURE_OPENAI', 'DEEPSEEK'].includes(provider)) {
      return badRequest(res, 'Invalid or missing AI provider');
    }

    const result = await PlatformConfigService.testAIConnection(provider as AIProvider);
    return success(res, result);
  } catch (error: any) {
    if (error instanceof PlatformConfigError) {
      return badRequest(res, error.message);
    }
    return serverError(res, error);
  }
});

// ─── Push Notification Config ─────────────────────────────────────────────────

/**
 * GET /platform/notifications
 * Get push notification configuration
 */
router.get('/notifications', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const config = await PlatformConfigService.getPushNotificationConfig();
    return success(res, config);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/notifications
 * Update push notification configuration
 */
router.patch('/notifications', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const {
      fcmEnabled,
      fcmProjectId,
      fcmPrivateKey,
      fcmClientEmail,
      apnsEnabled,
      apnsKeyId,
      apnsTeamId,
      apnsPrivateKey,
      apnsBundleId,
      apnsProduction,
      emailEnabled,
      emailProvider,
      sendgridApiKey,
      smtpHost,
      smtpPort,
      smtpUser,
      smtpPassword,
      fromEmail,
      fromName,
    } = req.body;

    const config = await PlatformConfigService.updatePushNotificationConfig({
      fcmEnabled,
      fcmProjectId,
      fcmPrivateKey,
      fcmClientEmail,
      apnsEnabled,
      apnsKeyId,
      apnsTeamId,
      apnsPrivateKey,
      apnsBundleId,
      apnsProduction,
      emailEnabled,
      emailProvider,
      sendgridApiKey,
      smtpHost,
      smtpPort,
      smtpUser,
      smtpPassword,
      fromEmail,
      fromName,
    });

    // Return masked version
    const maskedConfig = await PlatformConfigService.getPushNotificationConfig();
    return success(res, maskedConfig, 'Notification config updated');
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── OAuth Config ─────────────────────────────────────────────────────────────

/**
 * GET /platform/oauth
 * Get OAuth (Google / Apple) configuration
 */
router.get('/oauth', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const config = await PlatformConfigService.getOAuthConfig();
    return success(res, config);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/oauth
 * Update OAuth configuration
 */
router.patch('/oauth', async (req: AuthenticatedRequest, res: Response) => {
  try {
    let {
      googleEnabled, googleClientId, googleClientSecret,
      appleEnabled, appleClientId, appleTeamId, appleKeyId, applePrivateKey,
    } = req.body;

    // Helper to extract from Google JSON if pasted
    const tryExtractGoogleJson = (val: string) => {
      try {
        if (!val || !val.trim().startsWith('{')) return null;
        const parsed = JSON.parse(val);
        const web = parsed.web || parsed.installed;
        if (web && web.client_id) {
          return { clientId: web.client_id, clientSecret: web.client_secret };
        }
      } catch (e) {}
      return null;
    };

    const updateData: any = {
      googleEnabled,
      appleEnabled, appleClientId, appleTeamId, appleKeyId,
    };

    // Process Google Credentials
    const extracted = tryExtractGoogleJson(googleClientId) || tryExtractGoogleJson(googleClientSecret);
    if (extracted) {
      updateData.googleClientId = extracted.clientId;
      updateData.googleClientSecret = extracted.clientSecret;
    } else {
      if (googleClientId) updateData.googleClientId = googleClientId;
      if (googleClientSecret && googleClientSecret !== '••••••••') {
        updateData.googleClientSecret = googleClientSecret;
      }
    }

    if (applePrivateKey && applePrivateKey !== '••••••••') {
      updateData.applePrivateKey = applePrivateKey;
    }

    await PlatformConfigService.updateOAuthConfig(updateData);

    const maskedConfig = await PlatformConfigService.getOAuthConfig();
    return success(res, maskedConfig, 'OAuth config updated');
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── Stripe Config ────────────────────────────────────────────────────────────

/**
 * GET /platform/stripe
 * Get Stripe configuration
 */
router.get('/stripe', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const config = await PlatformConfigService.getStripeConfig();
    return success(res, config);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/stripe
 * Update Stripe configuration
 */
router.patch('/stripe', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const {
      publishableKey,
      secretKey,
      webhookSecret,
      connectEnabled,
      platformFeePercent,
      defaultCurrency,
      testMode,
    } = req.body;

    const config = await PlatformConfigService.updateStripeConfig({
      publishableKey,
      secretKey,
      webhookSecret,
      connectEnabled,
      platformFeePercent,
      defaultCurrency,
      testMode,
    });

    // Return masked version
    const maskedConfig = await PlatformConfigService.getStripeConfig();
    return success(res, maskedConfig, 'Stripe config updated');
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── User Tier Limits ─────────────────────────────────────────────────────────

/**
 * GET /platform/tiers
 * Get all tier limits
 */
router.get('/tiers', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const tiers = await PlatformConfigService.getAllTierLimits();
    return success(res, tiers);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * GET /platform/tiers/:tier
 * Get limits for specific tier
 */
router.get('/tiers/:tier', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { tier } = req.params;

    if (!['FREE', 'GYM_MEMBER', 'HOME_PREMIUM'].includes(tier)) {
      return badRequest(res, 'Invalid tier');
    }

    const limits = await PlatformConfigService.getTierLimits(tier as UserTier);
    return success(res, limits);
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * PATCH /platform/tiers/:tier
 * Update tier limits
 */
router.patch('/tiers/:tier', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { tier } = req.params;

    if (!['FREE', 'GYM_MEMBER', 'HOME_PREMIUM'].includes(tier)) {
      return badRequest(res, 'Invalid tier');
    }

    const {
      aiTokensPerMonth,
      aiRequestsPerDay,
      workoutPlansPerMonth,
      dietPlansPerMonth,
      canAccessAICoach,
      canAccessDietPlanner,
      canAccessAdvancedStats,
      canExportData,
      maxProgressPhotos,
      description,
    } = req.body;

    const limits = await PlatformConfigService.updateTierLimits(tier as UserTier, {
      aiTokensPerMonth,
      aiRequestsPerDay,
      workoutPlansPerMonth,
      dietPlansPerMonth,
      canAccessAICoach,
      canAccessDietPlanner,
      canAccessAdvancedStats,
      canExportData,
      maxProgressPhotos,
      description,
    });

    return success(res, limits, 'Tier limits updated');
  } catch (error: any) {
    return serverError(res, error);
  }
});

/**
 * POST /platform/tiers/initialize
 * Initialize default tier limits
 */
router.post('/tiers/initialize', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const tiers = await PlatformConfigService.initializeDefaultTierLimits();
    return success(res, tiers, 'Default tier limits initialized');
  } catch (error: any) {
    return serverError(res, error);
  }
});

// ─── AI Usage Stats ───────────────────────────────────────────────────────────

/**
 * GET /platform/ai/usage
 * Get AI usage statistics
 */
router.get('/ai/usage', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const { startDate, endDate } = req.query;

    const stats = await PlatformConfigService.getAIUsageStats({
      startDate: startDate ? new Date(startDate as string) : undefined,
      endDate: endDate ? new Date(endDate as string) : undefined,
    });

    return success(res, stats);
  } catch (error: any) {
    return serverError(res, error);
  }
});

export default router;

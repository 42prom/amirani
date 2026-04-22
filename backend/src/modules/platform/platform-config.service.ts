import prisma from '../../utils/prisma';
import { AIProvider, UserTier } from '@prisma/client';
import { encryptField, decryptField } from '../../utils/crypto';
import logger from '../../utils/logger';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class PlatformConfigError extends Error {
  public statusCode: number;
  constructor(message: string, statusCode: number = 400) {
    super(message);
    this.name = 'PlatformConfigError';
    this.statusCode = statusCode;
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class PlatformConfigService {
  // ─── Platform Config ─────────────────────────────────────────────────────────

  /**
   * Get or create platform config
   */
  static async getPlatformConfig() {
    let config = await prisma.platformConfig.findUnique({
      where: { id: 'singleton' },
    });

    if (!config) {
      config = await prisma.platformConfig.create({
        data: { id: 'singleton' },
      });
    }

    return config;
  }

  /**
   * Update platform config
   */
  static async updatePlatformConfig(data: {
    platformName?: string;
    platformLogoUrl?: string;
    supportEmail?: string;
    privacyPolicyUrl?: string;
    termsOfServiceUrl?: string;
    maintenanceMode?: boolean;
    pricePerBranch?: number;
    defaultTrialDays?: number;
    currency?: string;
  }) {
    return prisma.platformConfig.upsert({
      where: { id: 'singleton' },
      update: data,
      create: { id: 'singleton', ...data },
    });
  }

  // ─── AI Config ───────────────────────────────────────────────────────────────

  /**
   * Get AI configuration
   */
  static async getAIConfig() {
    let config = await prisma.aIConfig.findUnique({
      where: { id: 'singleton' },
    });

    if (!config) {
      config = await prisma.aIConfig.create({
        data: { id: 'singleton' },
      });
    }

    // Mask sensitive keys for response
    const mask = (key: string | null) => key ? '••••••••' + key.slice(-4) : null;
    
    return {
      ...config,
      openaiApiKey: mask(config.openaiApiKey),
      anthropicApiKey: mask(config.anthropicApiKey),
      googleApiKey: mask(config.googleApiKey),
      azureApiKey: mask(config.azureApiKey),
      deepseekApiKey: mask(config.deepseekApiKey),
    };
  }

  /**
   * Get AI configuration with actual keys (for internal use)
   */
  static async getAIConfigInternal() {
    let config = await prisma.aIConfig.findUnique({
      where: { id: 'singleton' },
    });

    if (!config) {
      config = await prisma.aIConfig.create({
        data: { id: 'singleton' },
      });
    }

    return {
      ...config,
      openaiApiKey:    decryptField(config.openaiApiKey),
      anthropicApiKey: decryptField(config.anthropicApiKey),
      googleApiKey:    decryptField(config.googleApiKey),
      azureApiKey:     decryptField(config.azureApiKey),
      deepseekApiKey:  decryptField(config.deepseekApiKey),
    };
  }

  /**
   * Update AI configuration
   */
  static async updateAIConfig(data: {
    activeProvider?: AIProvider;
    openaiApiKey?: string;
    openaiModel?: string;
    openaiOrgId?: string;
    anthropicApiKey?: string;
    anthropicModel?: string;
    googleApiKey?: string;
    googleModel?: string;
    azureApiKey?: string;
    azureEndpoint?: string;
    azureDeploymentName?: string;
    deepseekApiKey?: string;
    deepseekModel?: string;
    deepseekBaseUrl?: string;
    maxTokensPerRequest?: number;
    temperature?: number;
    isEnabled?: boolean;
    /** The userId of the super admin making the change — used for audit logging. */
    actorId?: string;
  }) {
    const { actorId, ...rest } = data;
    const updateData: any = { ...rest };
    const secretFields = ['openaiApiKey', 'anthropicApiKey', 'googleApiKey', 'azureApiKey', 'deepseekApiKey'];

    // Pattern to catch various mask styles (e.g. ••••••, *****, or mixed)
    const maskRegex = /^[\u2022\u002A]{4,}/;

    for (const field of secretFields) {
      if (updateData[field] && (updateData[field].startsWith('••••••••') || maskRegex.test(updateData[field]))) {
        delete updateData[field];
      } else if (updateData[field]) {
        updateData[field] = encryptField(updateData[field]);
      }
    }

    const result = await prisma.aIConfig.upsert({
      where: { id: 'singleton' },
      update: updateData,
      create: { id: 'singleton', ...updateData },
    });

    // Audit log — only if something actually changed
    if (Object.keys(updateData).length > 0) {
      try {
        // Resolve actor: use the authenticated requester if provided, else fall back to first super admin.
        const [actor, firstGym] = await Promise.all([
          actorId
            ? prisma.user.findUnique({ where: { id: actorId } })
            : prisma.user.findFirst({ where: { role: 'SUPER_ADMIN' } }),
          prisma.gym.findFirst(),
        ]);

        if (actor && firstGym) {
          await prisma.auditLog.create({
            data: {
              gymId: firstGym.id,
              actorId: actor.id,
              action: 'AI_CONFIG_UPDATE',
              entity: 'AIConfig',
              entityId: 'singleton',
              label: `Updated AI Configuration fields: ${Object.keys(updateData).join(', ')}`,
              metadata: updateData,
            }
          });
        }
      } catch (logErr) {
        logger.warn('Failed to create AIConfig audit log', { logErr });
      }
    }

    return result;
  }

  /**
   * Test AI connection (REAL PING)
   */
  static async testAIConnection(provider: AIProvider) {
    const config = await this.getAIConfigInternal();
    const axios = (await import('axios')).default;

    try {
      switch (provider) {
        case 'OPENAI':
          if (!config.openaiApiKey) throw new PlatformConfigError('OpenAI API key not configured');
          await axios.get('https://api.openai.com/v1/models', {
            headers: { Authorization: `Bearer ${config.openaiApiKey}` },
            timeout: 10000
          });
          break;
          
        case 'ANTHROPIC':
          if (!config.anthropicApiKey) throw new PlatformConfigError('Anthropic API key not configured');
          // Simple message request as a ping
          await axios.post('https://api.anthropic.com/v1/messages', {
            model: config.anthropicModel || 'claude-3-haiku-20240307',
            max_tokens: 1,
            messages: [{ role: 'user', content: 'ping' }]
          }, {
            headers: { 'x-api-key': config.anthropicApiKey, 'anthropic-version': '2023-06-01' },
            timeout: 10000
          });
          break;

        case 'DEEPSEEK':
          if (!config.deepseekApiKey) throw new PlatformConfigError('DeepSeek API key not configured');
          // DeepSeek follows OpenAI format for models list
          await axios.get(`${config.deepseekBaseUrl}/models`, {
            headers: { Authorization: `Bearer ${config.deepseekApiKey}` },
            timeout: 10000
          });
          break;

        case 'GOOGLE_GEMINI':
          if (!config.googleApiKey) throw new PlatformConfigError('Google API key not configured');
          await axios.get(`https://generativelanguage.googleapis.com/v1beta/models?key=${config.googleApiKey}`, {
            timeout: 10000
          });
          break;

        default:
          throw new PlatformConfigError(`Testing not yet implemented for ${provider}`);
      }
    } catch (err: any) {
      const errorMsg = err.response?.data?.error?.message || err.response?.data?.message || err.message;
      throw new PlatformConfigError(`Connection failed: ${errorMsg}`);
    }

    return { success: true, provider, message: 'Connection verified successfully' };
  }

  // ─── Push Notification Config ────────────────────────────────────────────────

  /**
   * Get push notification configuration
   */
  static async getPushNotificationConfig() {
    let config = await prisma.pushNotificationConfig.findUnique({
      where: { id: 'singleton' },
    });

    if (!config) {
      config = await prisma.pushNotificationConfig.create({
        data: { id: 'singleton' },
      });
    }

    // Mask sensitive keys
    return {
      ...config,
      fcmPrivateKey: config.fcmPrivateKey ? '••••••••' : null,
      apnsPrivateKey: config.apnsPrivateKey ? '••••••••' : null,
      sendgridApiKey: config.sendgridApiKey ? '••••••••' + config.sendgridApiKey.slice(-4) : null,
      smtpPassword: config.smtpPassword ? '••••••••' : null,
    };
  }

  /**
   * Update push notification configuration
   */
  static async updatePushNotificationConfig(data: {
    fcmEnabled?: boolean;
    fcmProjectId?: string;
    fcmPrivateKey?: string;
    fcmClientEmail?: string;
    apnsEnabled?: boolean;
    apnsKeyId?: string;
    apnsTeamId?: string;
    apnsPrivateKey?: string;
    apnsBundleId?: string;
    apnsProduction?: boolean;
    emailEnabled?: boolean;
    emailProvider?: string;
    sendgridApiKey?: string;
    smtpHost?: string;
    smtpPort?: number;
    smtpUser?: string;
    smtpPassword?: string;
    fromEmail?: string;
    fromName?: string;
  }) {
    const updateData: any = { ...data };
    const secretFields = ['fcmPrivateKey', 'apnsPrivateKey', 'sendgridApiKey', 'smtpPassword'];

    for (const field of secretFields) {
      if (updateData[field] && updateData[field].startsWith('••••••••')) {
        delete updateData[field];
      } else if (updateData[field]) {
        updateData[field] = encryptField(updateData[field]);
      }
    }

    return prisma.pushNotificationConfig.upsert({
      where: { id: 'singleton' },
      update: updateData,
      create: { id: 'singleton', ...updateData },
    });
  }

  // ─── OAuth Config ────────────────────────────────────────────────────────────

  static async getOAuthConfig() {
    const prismaAny = prisma as any;
    let config = await prismaAny.oAuthConfig.findUnique({ where: { id: 'singleton' } });
    if (!config) config = await prismaAny.oAuthConfig.create({ data: { id: 'singleton' } });
    return {
      ...config,
      googleClientSecret: config.googleClientSecret ? '••••••••' : null,
      applePrivateKey:    config.applePrivateKey    ? '••••••••' : null,
    };
  }

  static async getOAuthConfigInternal() {
    const prismaAny = prisma as any;
    let config = await prismaAny.oAuthConfig.findUnique({ where: { id: 'singleton' } });
    if (!config) config = await prismaAny.oAuthConfig.create({ data: { id: 'singleton' } });
    return config;
  }

  static async updateOAuthConfig(data: {
    googleEnabled?: boolean;
    googleClientId?: string;
    googleClientSecret?: string;
    appleEnabled?: boolean;
    appleClientId?: string;
    appleTeamId?: string;
    appleKeyId?: string;
    applePrivateKey?: string;
  }) {
    const updateData: any = { ...data };
    const secretFields = ['googleClientSecret', 'applePrivateKey'];
    
    for (const field of secretFields) {
      if (updateData[field] && updateData[field].startsWith('••••••••')) {
        delete updateData[field];
      }
    }

    const prismaAny = prisma as any;
    return prismaAny.oAuthConfig.upsert({
      where: { id: 'singleton' },
      update: updateData,
      create: { id: 'singleton', ...updateData },
    });
  }

  // ─── Stripe Config ───────────────────────────────────────────────────────────

  /**
   * Get Stripe configuration
   */
  static async getStripeConfig() {
    let config = await prisma.stripeConfig.findUnique({
      where: { id: 'singleton' },
    });

    if (!config) {
      config = await prisma.stripeConfig.create({
        data: { id: 'singleton' },
      });
    }

    // Mask sensitive keys
    return {
      ...config,
      secretKey: config.secretKey ? '••••••••' + config.secretKey.slice(-4) : null,
      webhookSecret: config.webhookSecret ? '••••••••' : null,
    };
  }

  /**
   * Update Stripe configuration
   */
  static async updateStripeConfig(data: {
    publishableKey?: string;
    secretKey?: string;
    webhookSecret?: string;
    connectEnabled?: boolean;
    platformFeePercent?: number;
    defaultCurrency?: string;
    testMode?: boolean;
  }) {
    const updateData: any = { ...data };
    const secretFields = ['secretKey', 'webhookSecret'];

    for (const field of secretFields) {
      if (updateData[field] && updateData[field].startsWith('••••••••')) {
        delete updateData[field];
      } else if (updateData[field]) {
        updateData[field] = encryptField(updateData[field]);
      }
    }

    return prisma.stripeConfig.upsert({
      where: { id: 'singleton' },
      update: updateData,
      create: { id: 'singleton', ...updateData },
    });
  }

  // ─── User Tier Limits ────────────────────────────────────────────────────────

  /**
   * Get all tier limits
   */
  static async getAllTierLimits() {
    return prisma.userTierLimits.findMany({
      orderBy: { tier: 'asc' },
    });
  }

  /**
   * Get limits for a specific tier
   */
  static async getTierLimits(tier: UserTier) {
    let limits = await prisma.userTierLimits.findUnique({
      where: { tier },
    });

    if (!limits) {
      // Create default limits
      limits = await prisma.userTierLimits.create({
        data: this.getDefaultLimits(tier),
      });
    }

    return limits;
  }

  /**
   * Update tier limits
   */
  static async updateTierLimits(
    tier: UserTier,
    data: {
      aiTokensPerMonth?: number;
      aiRequestsPerDay?: number;
      workoutPlansPerMonth?: number;
      dietPlansPerMonth?: number;
      canAccessAICoach?: boolean;
      canAccessDietPlanner?: boolean;
      canAccessAdvancedStats?: boolean;
      canExportData?: boolean;
      maxProgressPhotos?: number;
      description?: string;
    }
  ) {
    return prisma.userTierLimits.upsert({
      where: { tier },
      update: data,
      create: { tier, ...data },
    });
  }

  /**
   * Initialize all default tier limits
   */
  static async initializeDefaultTierLimits() {
    const tiers: UserTier[] = ['FREE', 'GYM_MEMBER', 'HOME_PREMIUM'];

    for (const tier of tiers) {
      await prisma.userTierLimits.upsert({
        where: { tier },
        update: {},
        create: this.getDefaultLimits(tier),
      });
    }

    return this.getAllTierLimits();
  }

  private static getDefaultLimits(tier: UserTier) {
    switch (tier) {
      case 'FREE':
        return {
          tier,
          aiTokensPerMonth: 5000,
          aiRequestsPerDay: 5,
          workoutPlansPerMonth: 1,
          dietPlansPerMonth: 0,
          canAccessAICoach: true,
          canAccessDietPlanner: false,
          canAccessAdvancedStats: false,
          canExportData: false,
          maxProgressPhotos: 5,
          description: 'Free tier with limited AI access',
        };
      case 'GYM_MEMBER':
        return {
          tier,
          aiTokensPerMonth: 50000,
          aiRequestsPerDay: 50,
          workoutPlansPerMonth: 10,
          dietPlansPerMonth: 5,
          canAccessAICoach: true,
          canAccessDietPlanner: true,
          canAccessAdvancedStats: true,
          canExportData: true,
          maxProgressPhotos: 100,
          description: 'Full access for gym members',
        };
      case 'HOME_PREMIUM':
        return {
          tier,
          aiTokensPerMonth: 30000,
          aiRequestsPerDay: 30,
          workoutPlansPerMonth: 8,
          dietPlansPerMonth: 4,
          canAccessAICoach: true,
          canAccessDietPlanner: true,
          canAccessAdvancedStats: true,
          canExportData: true,
          maxProgressPhotos: 50,
          description: 'Premium home user subscription',
        };
    }
  }

  // ─── AI Usage Tracking ───────────────────────────────────────────────────────

  /**
   * Log AI usage
   */
  static async logAIUsage(data: {
    userId: string;
    provider: AIProvider;
    model: string;
    promptTokens: number;
    completionTokens: number;
    requestType: string;
  }) {
    const totalTokens = data.promptTokens + data.completionTokens;

    // Estimate cost based on provider (simplified)
    let costPer1kTokens = 0;
    switch (data.provider) {
      case 'OPENAI':
        costPer1kTokens = 0.01; // ~$0.01 per 1k tokens for GPT-4
        break;
      case 'ANTHROPIC':
        costPer1kTokens = 0.008; // ~$0.008 per 1k tokens for Claude
        break;
      case 'GOOGLE_GEMINI':
        costPer1kTokens = 0.0005; // Very low for Gemini
        break;
      case 'DEEPSEEK':
        costPer1kTokens = 0.00014; // $0.14 per 1M tokens -> $0.00014 per 1k
        break;
      case 'AZURE_OPENAI':
        costPer1kTokens = 0.01; // Same as OpenAI
        break;
    }

    const cost = (totalTokens / 1000) * costPer1kTokens;

    return prisma.aIUsageLog.create({
      data: {
        userId: data.userId,
        provider: data.provider,
        model: data.model,
        promptTokens: data.promptTokens,
        completionTokens: data.completionTokens,
        totalTokens,
        requestType: data.requestType,
        cost,
      },
    });
  }

  /**
   * Get AI usage stats
   */
  static async getAIUsageStats(options?: {
    startDate?: Date;
    endDate?: Date;
  }) {
    const where: any = {};
    if (options?.startDate || options?.endDate) {
      where.createdAt = {};
      if (options.startDate) where.createdAt.gte = options.startDate;
      if (options.endDate) where.createdAt.lte = options.endDate;
    }

    const [totalUsage, byProvider, byType, totalCost] = await Promise.all([
      prisma.aIUsageLog.aggregate({
        where,
        _sum: { totalTokens: true, promptTokens: true, completionTokens: true },
        _count: true,
      }),
      prisma.aIUsageLog.groupBy({
        by: ['provider'],
        where,
        _sum: { totalTokens: true },
        _count: true,
      }),
      prisma.aIUsageLog.groupBy({
        by: ['requestType'],
        where,
        _sum: { totalTokens: true },
        _count: true,
      }),
      prisma.aIUsageLog.aggregate({
        where,
        _sum: { cost: true },
      }),
    ]);

    return {
      totalRequests: totalUsage._count,
      totalTokens: totalUsage._sum.totalTokens || 0,
      promptTokens: totalUsage._sum.promptTokens || 0,
      completionTokens: totalUsage._sum.completionTokens || 0,
      estimatedCost: Number(totalCost._sum.cost || 0).toFixed(4),
      byProvider,
      byType,
    };
  }

  /**
   * Check if user has exceeded their AI limits
   */
  static async checkUserAILimits(userId: string, tier: UserTier) {
    const limits = await this.getTierLimits(tier);

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfDay = new Date(now.setHours(0, 0, 0, 0));

    const [monthlyUsage, dailyUsage] = await Promise.all([
      prisma.aIUsageLog.aggregate({
        where: {
          userId,
          createdAt: { gte: startOfMonth },
        },
        _sum: { totalTokens: true },
      }),
      prisma.aIUsageLog.count({
        where: {
          userId,
          createdAt: { gte: startOfDay },
        },
      }),
    ]);

    const monthlyTokens = monthlyUsage._sum.totalTokens || 0;
    const monthlyLimitReached = limits.aiTokensPerMonth !== 0 && monthlyTokens >= limits.aiTokensPerMonth;
    const dailyLimitReached = limits.aiRequestsPerDay !== 0 && dailyUsage >= limits.aiRequestsPerDay;

    return {
      canMakeRequest: !monthlyLimitReached && !dailyLimitReached,
      monthlyLimitReached,
      dailyLimitReached,
      monthlyTokensUsed: monthlyTokens,
      monthlyTokensLimit: limits.aiTokensPerMonth,
      dailyRequestsUsed: dailyUsage,
      dailyRequestsLimit: limits.aiRequestsPerDay,
    };
  }
}

import prisma from '../../lib/prisma';
import { PlatformConfigService } from '../platform/platform-config.service';
import logger from '../../lib/logger';

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class StripeConnectError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'StripeConnectError';
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class StripeConnectService {
  /**
   * Create Stripe Connect account for a gym
   * This creates an Express account that allows the gym to receive payments
   */
  static async createConnectAccount(gymId: string) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
      include: { owner: true },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    if (gym.stripeAccountId) {
      throw new StripeConnectError('Gym already has a Stripe account');
    }

    // In production, create actual Stripe Connect account
    // const stripe = new Stripe(config.stripeSecretKey);
    // const account = await stripe.accounts.create({
    //   type: 'express',
    //   country: gym.country,
    //   email: gym.owner.email,
    //   capabilities: {
    //     card_payments: { requested: true },
    //     transfers: { requested: true },
    //   },
    //   business_type: 'company',
    //   business_profile: {
    //     name: gym.name,
    //     url: `https://amirani.app/gyms/${gym.id}`,
    //   },
    // });

    // Mock account creation
    const mockAccountId = `acct_mock_${gymId.slice(0, 8)}`;

    await prisma.gym.update({
      where: { id: gymId },
      data: {
        stripeAccountId: mockAccountId,
        stripeAccountStatus: 'pending',
        stripeOnboardingComplete: false,
        stripePayoutsEnabled: false,
      },
    });

    return {
      accountId: mockAccountId,
      status: 'pending',
    };
  }

  /**
   * Generate onboarding link for gym to complete Stripe Connect setup
   */
  static async createOnboardingLink(gymId: string, returnUrl: string, refreshUrl: string) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    if (!gym.stripeAccountId) {
      // Create account first
      await this.createConnectAccount(gymId);
    }

    // In production:
    // const accountLink = await stripe.accountLinks.create({
    //   account: gym.stripeAccountId,
    //   refresh_url: refreshUrl,
    //   return_url: returnUrl,
    //   type: 'account_onboarding',
    // });

    // Mock onboarding link
    return {
      url: `https://connect.stripe.com/setup/mock?account=${gym.stripeAccountId}&return=${encodeURIComponent(returnUrl)}`,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    };
  }

  /**
   * Create login link for gym owner to access their Stripe Express Dashboard
   */
  static async createDashboardLink(gymId: string) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    if (!gym.stripeAccountId) {
      throw new StripeConnectError('Gym has no Stripe account');
    }

    if (!gym.stripeOnboardingComplete) {
      throw new StripeConnectError('Stripe onboarding not complete');
    }

    // In production:
    // const loginLink = await stripe.accounts.createLoginLink(gym.stripeAccountId);

    // Mock dashboard link
    return {
      url: `https://dashboard.stripe.com/express/${gym.stripeAccountId}`,
    };
  }

  /**
   * Get Stripe Connect account status
   */
  static async getAccountStatus(gymId: string) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
      select: {
        id: true,
        name: true,
        stripeAccountId: true,
        stripeAccountStatus: true,
        stripeOnboardingComplete: true,
        stripePayoutsEnabled: true,
        stripeCurrency: true,
      },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    // In production, fetch actual account status from Stripe
    // const account = await stripe.accounts.retrieve(gym.stripeAccountId);

    return {
      hasAccount: !!gym.stripeAccountId,
      accountId: gym.stripeAccountId,
      status: gym.stripeAccountStatus || 'not_created',
      onboardingComplete: gym.stripeOnboardingComplete,
      payoutsEnabled: gym.stripePayoutsEnabled,
      currency: gym.stripeCurrency,
    };
  }

  /**
   * Handle Stripe Connect webhook for account updates
   */
  static async handleAccountUpdate(stripeAccountId: string, data: {
    chargesEnabled?: boolean;
    payoutsEnabled?: boolean;
    detailsSubmitted?: boolean;
  }) {
    const gym = await prisma.gym.findFirst({
      where: { stripeAccountId },
    });

    if (!gym) {
      logger.error('[Stripe Connect] No gym found for account', { stripeAccountId });
      return;
    }

    let status = 'pending';
    if (data.detailsSubmitted && data.chargesEnabled && data.payoutsEnabled) {
      status = 'active';
    } else if (data.detailsSubmitted && (!data.chargesEnabled || !data.payoutsEnabled)) {
      status = 'restricted';
    }

    await prisma.gym.update({
      where: { id: gym.id },
      data: {
        stripeAccountStatus: status,
        stripeOnboardingComplete: data.detailsSubmitted || false,
        stripePayoutsEnabled: data.payoutsEnabled || false,
      },
    });

    logger.info('[Stripe Connect] Updated gym status', { gymId: gym.id, status });
  }

  /**
   * Create payment intent for gym subscription with platform fee
   * The gym receives the payment minus the platform fee
   */
  static async createPaymentIntent(gymId: string, amount: number, currency: string, metadata?: Record<string, string>) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    if (!gym.stripeAccountId || !gym.stripePayoutsEnabled) {
      throw new StripeConnectError('Gym payment processing not set up');
    }

    // Get platform fee percentage
    const stripeConfig = await prisma.stripeConfig.findUnique({
      where: { id: 'singleton' },
    });

    const platformFeePercent = stripeConfig?.platformFeePercent || 10;
    const platformFeeAmount = Math.round(amount * (platformFeePercent / 100));

    // In production:
    // const paymentIntent = await stripe.paymentIntents.create({
    //   amount,
    //   currency,
    //   application_fee_amount: platformFeeAmount,
    //   transfer_data: {
    //     destination: gym.stripeAccountId,
    //   },
    //   metadata,
    // });

    // Mock payment intent
    return {
      id: `pi_mock_${Date.now()}`,
      amount,
      currency,
      platformFee: platformFeeAmount,
      gymReceives: amount - platformFeeAmount,
      clientSecret: `pi_mock_${Date.now()}_secret_mock`,
      status: 'requires_payment_method',
    };
  }

  /**
   * Get gym earnings/payout history
   */
  static async getGymEarnings(gymId: string, options?: { startDate?: Date; endDate?: Date }) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    // Get payments for this gym
    const where: any = { gymId };
    if (options?.startDate || options?.endDate) {
      where.createdAt = {};
      if (options.startDate) where.createdAt.gte = options.startDate;
      if (options.endDate) where.createdAt.lte = options.endDate;
    }

    const payments = await prisma.payment.findMany({
      where: {
        ...where,
        status: 'SUCCEEDED',
      },
      orderBy: { createdAt: 'desc' },
    });

    // Get platform fee percentage
    const stripeConfig = await prisma.stripeConfig.findUnique({
      where: { id: 'singleton' },
    });
    const platformFeePercent = stripeConfig?.platformFeePercent || 10;

    const totalRevenue = payments.reduce((sum, p) => sum + Number(p.amount), 0);
    const platformFees = totalRevenue * (platformFeePercent / 100);
    const netEarnings = totalRevenue - platformFees;

    return {
      totalRevenue,
      platformFees,
      netEarnings,
      platformFeePercent,
      paymentCount: payments.length,
      currency: gym.stripeCurrency,
      payments: payments.slice(0, 10), // Last 10 payments
    };
  }

  /**
   * Update gym payment settings
   */
  static async updatePaymentSettings(gymId: string, data: { currency?: string }) {
    const gym = await prisma.gym.findUnique({
      where: { id: gymId },
    });

    if (!gym) {
      throw new StripeConnectError('Gym not found');
    }

    return prisma.gym.update({
      where: { id: gymId },
      data: {
        stripeCurrency: data.currency,
      },
    });
  }
}

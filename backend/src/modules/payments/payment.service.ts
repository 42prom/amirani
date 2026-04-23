import Stripe from 'stripe';
import config from '../../config/env';
import prisma from '../../lib/prisma';
import { PaymentStatus, PaymentMethod, SubscriptionStatus } from '@prisma/client';
import { NotificationService } from '../notifications/notification.service';
import { NotificationType } from '@prisma/client';
import { calcMembershipEndDate } from '../memberships/membership-utils';
import logger from '../../lib/logger';

const stripe = new Stripe(config.stripe.secretKey || 'sk_test_placeholder', {
  apiVersion: '2024-04-10' as any,
});

// ─── Custom Errors ───────────────────────────────────────────────────────────

export class PaymentError extends Error {
  constructor(message: string, public code?: string) {
    super(message);
    this.name = 'PaymentError';
  }
}

export class PaymentNotFoundError extends Error {
  constructor(public resource: string = 'Payment') {
    super(`${resource} not found`);
    this.name = 'PaymentNotFoundError';
  }
}

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreatePaymentIntentOptions {
  userId: string;
  amount: number;
  currency?: string;
  membershipId?: string;
  gymId?: string;
  method: PaymentMethod;
  description?: string;
}

export interface SubscriptionPurchaseOptions {
  userId: string;
  planId: string;
  gymId: string;
  paymentMethodId: string;
  autoRenew?: boolean;
}

// ─── Service ─────────────────────────────────────────────────────────────────

export class PaymentService {
  private static isProcessingExpiring = false;

  /**
   * Create or get Stripe customer for a user
   */
  static async getOrCreateStripeCustomer(userId: string): Promise<string> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
    });

    if (!user) {
      throw new PaymentNotFoundError('User');
    }

    if (user.stripeCustomerId) {
      // Basic verification: does customer exist in Stripe?
      try {
        await stripe.customers.retrieve(user.stripeCustomerId);
        return user.stripeCustomerId;
      } catch (err) {
        logger.warn('[Stripe] Customer ID in DB not found in Stripe, creating new one', { userId, customerId: user.stripeCustomerId });
      }
    }

    const customer = await stripe.customers.create({
      email: user.email,
      name: user.fullName,
      metadata: { userId: user.id },
    });

    await prisma.user.update({
      where: { id: userId },
      data: { stripeCustomerId: customer.id },
    });

    return customer.id;
  }

  /**
   * Create a payment intent for a one-time payment
   */
  static async createPaymentIntent(options: CreatePaymentIntentOptions) {
    const {
      userId,
      amount,
      currency = 'usd',
      membershipId,
      gymId,
      method,
      description,
    } = options;

    const customerId = await this.getOrCreateStripeCustomer(userId);

    // Create Stripe PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Convert to cents
      currency,
      customer: customerId,
      payment_method_types: this.getPaymentMethodTypes(method),
      metadata: { 
        userId, 
        membershipId: membershipId || '', 
        gymId: gymId || '' 
      },
      description,
    });

    const payment = await prisma.payment.create({
      data: {
        userId,
        amount,
        currency,
        status: PaymentStatus.PENDING,
        method,
        description,
        stripePaymentId: paymentIntent.id,
        membershipId,
        gymId,
        metadata: { customerId, clientSecret: paymentIntent.client_secret },
      },
    });

    return {
      paymentId: payment.id,
      clientSecret: paymentIntent.client_secret,
      stripePaymentId: paymentIntent.id,
    };
  }

  /**
   * Purchase a gym subscription
   */
  static async purchaseSubscription(options: SubscriptionPurchaseOptions) {
    const { userId, planId, gymId, paymentMethodId, autoRenew = false } = options;

    // Get the subscription plan
    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: planId },
      include: { gym: true },
    });

    if (!plan) {
      throw new PaymentNotFoundError('Subscription Plan');
    }

    if (plan.gymId !== gymId) {
      throw new PaymentError('Plan does not belong to this gym');
    }

    // Check for existing membership
    const existingMembership = await prisma.gymMembership.findUnique({
      where: { userId_gymId: { userId, gymId } },
    });

    if (existingMembership && existingMembership.status === 'ACTIVE') {
      throw new PaymentError('Already have an active membership at this gym');
    }

    const customerId = await this.getOrCreateStripeCustomer(userId);
    const amount = Number(plan.price);

    // Create Stripe subscription with a payment intent attached (Setup Intent or first Payment Intent)
    // We'll use Payment Intent for immediate collection
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2024-04-10' as any }
    );

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ plan: plan.id }], // This assumes plan.id is a Stripe Price ID
      payment_behavior: 'default_incomplete',
      payment_settings: { save_default_payment_method: 'on_subscription' },
      expand: ['latest_invoice.payment_intent'],
      metadata: { userId, planId, gymId },
    });

    const invoice = subscription.latest_invoice as any;
    const paymentIntent = invoice?.payment_intent as any;

    // Create payment record
    const payment = await prisma.payment.create({
      data: {
        userId,
        amount,
        currency: 'usd',
        status: PaymentStatus.PROCESSING,
        method: PaymentMethod.CARD,
        description: `${plan.name} subscription at ${plan.gym.name}`,
        stripePaymentId: paymentIntent?.id || subscription.id,
        membershipId: existingMembership?.id,
        gymId,
      },
    });

    // Calculate end date
    const startDate = new Date();
    const endDate = calcMembershipEndDate(startDate, plan.durationValue, plan.durationUnit);

    // Create or update membership in PENDING state until webhook confirms
    let membership;
    if (existingMembership) {
      membership = await prisma.gymMembership.update({
        where: { id: existingMembership.id },
        data: {
          planId,
          startDate,
          endDate,
          status: SubscriptionStatus.PENDING,
          stripeSubId: subscription.id,
          autoRenew,
        },
      });
    } else {
      membership = await prisma.gymMembership.create({
        data: {
          userId,
          gymId,
          planId,
          startDate,
          endDate,
          status: SubscriptionStatus.PENDING,
          stripeSubId: subscription.id,
          autoRenew,
        },
      });
    }

    return {
      subscriptionId: subscription.id,
      clientSecret: paymentIntent?.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customerId,
      paymentId: payment.id,
      membership,
    };
  }

  /**
   * Get user's payment history
   */
  static async getUserPayments(
    userId: string,
    options?: {
      status?: PaymentStatus;
      limit?: number;
      offset?: number;
    }
  ) {
    const where: any = { userId };
    if (options?.status) {
      where.status = options.status;
    }

    const [payments, total] = await Promise.all([
      prisma.payment.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: options?.limit || 50,
        skip: options?.offset || 0,
      }),
      prisma.payment.count({ where }),
    ]);

    return { payments, total };
  }

  /**
   * Get gym's revenue statistics
   */
  static async getGymRevenueStats(gymId: string) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const monthAgo = new Date(today);
    monthAgo.setDate(monthAgo.getDate() - 30);

    const yearAgo = new Date(today);
    yearAgo.setFullYear(yearAgo.getFullYear() - 1);

    const [
      todayRevenue,
      monthRevenue,
      yearRevenue,
      totalRevenue,
      recentPayments,
    ] = await Promise.all([
      prisma.payment.aggregate({
        where: {
          gymId,
          status: PaymentStatus.SUCCEEDED,
          createdAt: { gte: today },
        },
        _sum: { amount: true },
      }),
      prisma.payment.aggregate({
        where: {
          gymId,
          status: PaymentStatus.SUCCEEDED,
          createdAt: { gte: monthAgo },
        },
        _sum: { amount: true },
      }),
      prisma.payment.aggregate({
        where: {
          gymId,
          status: PaymentStatus.SUCCEEDED,
          createdAt: { gte: yearAgo },
        },
        _sum: { amount: true },
      }),
      prisma.payment.aggregate({
        where: {
          gymId,
          status: PaymentStatus.SUCCEEDED,
        },
        _sum: { amount: true },
      }),
      prisma.payment.findMany({
        where: { gymId, status: PaymentStatus.SUCCEEDED },
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: {
          user: {
            select: { id: true, fullName: true, email: true },
          },
        },
      }),
    ]);

    return {
      today: Number(todayRevenue._sum.amount || 0),
      month: Number(monthRevenue._sum.amount || 0),
      year: Number(yearRevenue._sum.amount || 0),
      total: Number(totalRevenue._sum.amount || 0),
      recentPayments,
    };
  }

  /**
   * Handle payment webhook (called by Stripe)
   */
  static async handleWebhook(event: { type: string; data: { object: any } }) {
    const { type, data } = event;

    switch (type) {
      case 'payment_intent.succeeded':
        await this.handlePaymentSucceeded(data.object);
        break;

      case 'payment_intent.payment_failed':
        await this.handlePaymentFailed(data.object);
        break;

      case 'invoice.payment_failed':
        await this.handleInvoicePaymentFailed(data.object);
        break;

      case 'customer.subscription.deleted':
        await this.handleSubscriptionCancelled(data.object);
        break;

      default:
        logger.info('[Stripe] Unhandled webhook event', { type });
    }

    return { received: true };
  }

  /**
   * Cancel a subscription
   */
  static async cancelSubscription(membershipId: string, userId: string) {
    const membership = await prisma.gymMembership.findFirst({
      where: { id: membershipId, userId },
    });

    if (!membership) {
      throw new PaymentNotFoundError('Membership');
    }

    // Cancel Stripe subscription
    if (membership.stripeSubId && membership.stripeSubId.startsWith('sub_')) {
      await stripe.subscriptions.cancel(membership.stripeSubId);
    }

    return prisma.gymMembership.update({
      where: { id: membershipId },
      data: {
        status: SubscriptionStatus.CANCELLED,
        autoRenew: false,
      },
    });
  }

  /**
   * Process expiring subscriptions (called by cron job)
   */
  static async processExpiringSubscriptions() {
    if (this.isProcessingExpiring) {
      logger.warn('[PaymentService] processExpiringSubscriptions already running, skipping');
      return { expiringNotified: 0, expired: 0, skipped: true };
    }
    this.isProcessingExpiring = true;
    try {
      const twoDaysFromNow = new Date();
      twoDaysFromNow.setDate(twoDaysFromNow.getDate() + 2);

      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);

      // Find memberships expiring in 2 days
      const expiringMemberships = await prisma.gymMembership.findMany({
        where: {
          status: SubscriptionStatus.ACTIVE,
          endDate: {
            gte: tomorrow,
            lte: twoDaysFromNow,
          },
        },
      });

      for (const membership of expiringMemberships) {
        await NotificationService.sendSubscriptionExpiringReminder(membership.id);
      }

      // Find expired memberships
      const expiredMemberships = await prisma.gymMembership.findMany({
        where: {
          status: SubscriptionStatus.ACTIVE,
          endDate: { lt: new Date() },
        },
      });

      for (const membership of expiredMemberships) {
        await prisma.gymMembership.update({
          where: { id: membership.id },
          data: { status: SubscriptionStatus.EXPIRED },
        });
        await NotificationService.sendSubscriptionExpiredNotification(membership.id);
      }

      return {
        expiringNotified: expiringMemberships.length,
        expired: expiredMemberships.length,
      };
    } finally {
      this.isProcessingExpiring = false;
    }
  }

  // ─── Private Webhook Handlers ────────────────────────────────────────────────

  private static async handlePaymentSucceeded(paymentIntent: any) {
    const payment = await prisma.payment.findUnique({
      where: { stripePaymentId: paymentIntent.id },
    });

    if (payment) {
      await prisma.payment.update({
        where: { id: payment.id },
        data: { status: PaymentStatus.SUCCEEDED },
      });

      // Activate membership if applicable
      if (payment.membershipId) {
        await prisma.gymMembership.update({
          where: { id: payment.membershipId },
          data: { status: SubscriptionStatus.ACTIVE },
        });
      }
    }
  }

  private static async handlePaymentFailed(paymentIntent: any) {
    const payment = await prisma.payment.findUnique({
      where: { stripePaymentId: paymentIntent.id },
    });

    if (payment) {
      await prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: PaymentStatus.FAILED,
          failureReason: paymentIntent.last_payment_error?.message,
        },
      });

      // Send notification
      await NotificationService.send({
        userId: payment.userId,
        type: NotificationType.PAYMENT_REMINDER,
        title: 'Payment Failed',
        body: 'Your payment could not be processed. Please update your payment method.',
        channels: ['PUSH', 'EMAIL', 'IN_APP'],
      });
    }
  }

  private static async handleInvoicePaymentFailed(invoice: any) {
    const membership = await prisma.gymMembership.findFirst({
      where: { stripeSubId: invoice.subscription },
    });

    if (membership) {
      await NotificationService.send({
        userId: membership.userId,
        type: NotificationType.PAYMENT_REMINDER,
        title: 'Subscription Payment Failed',
        body: 'Your subscription renewal payment failed. Please update your payment method to maintain access.',
        channels: ['PUSH', 'EMAIL', 'IN_APP'],
      });
    }
  }

  private static async handleSubscriptionCancelled(subscription: any) {
    const membership = await prisma.gymMembership.findFirst({
      where: { stripeSubId: subscription.id },
    });

    if (membership) {
      await prisma.gymMembership.update({
        where: { id: membership.id },
        data: { status: SubscriptionStatus.CANCELLED },
      });

      await NotificationService.send({
        userId: membership.userId,
        type: NotificationType.SUBSCRIPTION_EXPIRED,
        title: 'Subscription Cancelled',
        body: 'Your gym subscription has been cancelled.',
        channels: ['IN_APP', 'EMAIL'],
      });
    }
  }

  private static getPaymentMethodTypes(method: PaymentMethod): string[] {
    switch (method) {
      case PaymentMethod.GOOGLE_PAY:
        return ['card'];
      case PaymentMethod.APPLE_PAY:
        return ['card'];
      default:
        return ['card'];
    }
  }
}


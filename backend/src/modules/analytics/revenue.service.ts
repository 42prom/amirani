import prisma from '../../lib/prisma';
import { ChurnService } from './churn.service';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface MonthlyRevenue {
  month: string;   // "Jan 25"
  year: number;
  monthNum: number;
  realized: number;  // Actual payments collected
  projected: number; // MRR from active memberships that month
}

export interface PlanRevenue {
  planId: string;
  planName: string;
  price: number;
  activeMembers: number;
  monthlyValue: number; // price * activeMembers (normalized to /month)
  percentage: number;
}

export interface RevenueKPIs {
  mrr: number;           // Projected MRR from all active memberships
  arr: number;           // MRR × 12
  revenueAtRisk: number; // MRR from AT_RISK + HIGH_RISK + CHURNING members
  revenueAtRiskPct: number;
  avgRevenuePerMember: number;
  activeMembers: number;
  newMembersThisMonth: number;
  realizedThisMonth: number;   // Actual payments this calendar month
  realizedLastMonth: number;
  momGrowthPct: number;       // Month-over-month growth
}

export interface PeakHourBucket {
  hour: number; // 0–23
  count: number;
}

export interface RecentPayment {
  id: string;
  amount: number;
  description: string | null;
  createdAt: Date;
  userFullName: string;
  userEmail: string;
}

export interface RevenueIntelligence {
  kpis: RevenueKPIs;
  monthlyTrend: MonthlyRevenue[];  // Last 6 months
  planBreakdown: PlanRevenue[];
  peakHours: PeakHourBucket[];
  recentPayments: RecentPayment[];
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class RevenueService {

  static async getIntelligence(gymId: string): Promise<RevenueIntelligence> {
    const [kpis, monthlyTrend, planBreakdown, peakHours, recentPayments] = await Promise.all([
      this.getKPIs(gymId),
      this.getMonthlyTrend(gymId, 6),
      this.getPlanBreakdown(gymId),
      this.getPeakHours(gymId),
      this.getRecentPayments(gymId, 10),
    ]);
    return { kpis, monthlyTrend, planBreakdown, peakHours, recentPayments };
  }

  // ─── KPIs ──────────────────────────────────────────────────────────────────

  static async getKPIs(gymId: string): Promise<RevenueKPIs> {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const endOfLastMonth = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);

    // Active memberships with plan prices
    const activeMemberships = await prisma.gymMembership.findMany({
      where: { gymId, status: 'ACTIVE' },
      include: { plan: { select: { id: true, price: true, durationValue: true, durationUnit: true } } },
    });

    // Normalize each plan price to monthly
    const toMonthly = (price: number, durationValue: number, durationUnit: string): number => {
      if (durationUnit === 'months') return price / durationValue;
      return price / (durationValue / 30);
    };

    const mrr = activeMemberships.reduce((sum, m) => {
      const monthly = toMonthly(Number(m.plan.price), m.plan.durationValue, m.plan.durationUnit);
      return sum + monthly;
    }, 0);

    // Revenue at risk: churn score ≥ 35
    const churnData = await ChurnService.getAtRisk(gymId);
    const atRiskUserIds = new Set(churnData.map((c) => c.userId));
    const revenueAtRisk = activeMemberships
      .filter((m) => atRiskUserIds.has(m.userId))
      .reduce((sum, m) => {
        return sum + toMonthly(Number(m.plan.price), m.plan.durationValue, m.plan.durationUnit);
      }, 0);

    // Payments this month & last month
    const [thisMonthAgg, lastMonthAgg] = await Promise.all([
      prisma.payment.aggregate({
        where: { gymId, status: 'SUCCEEDED', createdAt: { gte: startOfMonth } },
        _sum: { amount: true },
      }),
      prisma.payment.aggregate({
        where: { gymId, status: 'SUCCEEDED', createdAt: { gte: startOfLastMonth, lte: endOfLastMonth } },
        _sum: { amount: true },
      }),
    ]);

    const realizedThisMonth = Number(thisMonthAgg._sum.amount ?? 0);
    const realizedLastMonth = Number(lastMonthAgg._sum.amount ?? 0);
    const momGrowthPct = realizedLastMonth > 0
      ? ((realizedThisMonth - realizedLastMonth) / realizedLastMonth) * 100
      : 0;

    // New members this month
    const newMembersThisMonth = await prisma.gymMembership.count({
      where: { gymId, startDate: { gte: startOfMonth } },
    });

    const activeMembers = activeMemberships.length;
    const avgRevenuePerMember = activeMembers > 0 ? mrr / activeMembers : 0;

    return {
      mrr: Math.round(mrr * 100) / 100,
      arr: Math.round(mrr * 12 * 100) / 100,
      revenueAtRisk: Math.round(revenueAtRisk * 100) / 100,
      revenueAtRiskPct: mrr > 0 ? Math.round((revenueAtRisk / mrr) * 100) : 0,
      avgRevenuePerMember: Math.round(avgRevenuePerMember * 100) / 100,
      activeMembers,
      newMembersThisMonth,
      realizedThisMonth: Math.round(realizedThisMonth * 100) / 100,
      realizedLastMonth: Math.round(realizedLastMonth * 100) / 100,
      momGrowthPct: Math.round(momGrowthPct * 10) / 10,
    };
  }

  // ─── Monthly trend ────────────────────────────────────────────────────────

  static async getMonthlyTrend(gymId: string, months: number): Promise<MonthlyRevenue[]> {
    const now = new Date();
    const results: MonthlyRevenue[] = [];

    for (let i = months - 1; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const start = new Date(d.getFullYear(), d.getMonth(), 1);
      const end   = new Date(d.getFullYear(), d.getMonth() + 1, 0, 23, 59, 59);

      const agg = await prisma.payment.aggregate({
        where: { gymId, status: 'SUCCEEDED', createdAt: { gte: start, lte: end } },
        _sum: { amount: true },
      });

      // Active memberships at mid-month snapshot
      const midMonth = new Date(d.getFullYear(), d.getMonth(), 15);
      const activeAtTime = await prisma.gymMembership.findMany({
        where: {
          gymId,
          startDate: { lte: midMonth },
          endDate: { gte: midMonth },
          status: 'ACTIVE',
        },
        include: { plan: { select: { price: true, durationValue: true, durationUnit: true } } },
      });

      const projected = activeAtTime.reduce((sum, m) => {
        const monthly = Number(m.plan.price) / (m.plan.durationUnit === 'months'
          ? m.plan.durationValue
          : m.plan.durationValue / 30);
        return sum + monthly;
      }, 0);

      results.push({
        month: d.toLocaleString('en-US', { month: 'short', year: '2-digit' }),
        year: d.getFullYear(),
        monthNum: d.getMonth() + 1,
        realized: Math.round(Number(agg._sum.amount ?? 0) * 100) / 100,
        projected: Math.round(projected * 100) / 100,
      });
    }

    return results;
  }

  // ─── Plan breakdown ───────────────────────────────────────────────────────

  static async getPlanBreakdown(gymId: string): Promise<PlanRevenue[]> {
    const activeMemberships = await prisma.gymMembership.findMany({
      where: { gymId, status: 'ACTIVE' },
      include: { plan: { select: { id: true, name: true, price: true, durationValue: true, durationUnit: true } } },
    });

    const planMap = new Map<string, { planName: string; price: number; durationValue: number; durationUnit: string; count: number }>();

    for (const m of activeMemberships) {
      const existing = planMap.get(m.planId);
      if (existing) {
        existing.count++;
      } else {
        planMap.set(m.planId, {
          planName: m.plan.name,
          price: Number(m.plan.price),
          durationValue: m.plan.durationValue,
          durationUnit: m.plan.durationUnit,
          count: 1,
        });
      }
    }

    const entries = Array.from(planMap.entries()).map(([planId, v]) => {
      const monthly = v.durationUnit === 'months'
        ? v.price / v.durationValue
        : v.price / (v.durationValue / 30);
      return {
        planId,
        planName: v.planName,
        price: v.price,
        activeMembers: v.count,
        monthlyValue: Math.round(monthly * v.count * 100) / 100,
        percentage: 0,
      };
    });

    const total = entries.reduce((s, e) => s + e.monthlyValue, 0);
    entries.forEach((e) => {
      e.percentage = total > 0 ? Math.round((e.monthlyValue / total) * 100) : 0;
    });

    return entries.sort((a, b) => b.monthlyValue - a.monthlyValue);
  }

  // ─── Peak hours ───────────────────────────────────────────────────────────

  static async getPeakHours(gymId: string): Promise<PeakHourBucket[]> {
    const ago30 = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const records = await prisma.attendance.findMany({
      where: { gymId, checkIn: { gte: ago30 } },
      select: { checkIn: true },
    });

    const buckets = Array.from({ length: 24 }, (_, h) => ({ hour: h, count: 0 }));
    for (const r of records) {
      buckets[r.checkIn.getHours()].count++;
    }

    return buckets;
  }

  // ─── Recent payments ──────────────────────────────────────────────────────

  static async getRecentPayments(gymId: string, limit: number): Promise<RecentPayment[]> {
    const payments = await prisma.payment.findMany({
      where: { gymId, status: 'SUCCEEDED' },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: { user: { select: { fullName: true, email: true } } },
    });

    return payments.map((p) => ({
      id: p.id,
      amount: Number(p.amount),
      description: p.description,
      createdAt: p.createdAt,
      userFullName: p.user.fullName,
      userEmail: p.user.email,
    }));
  }
}

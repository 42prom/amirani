import prisma from '../../utils/prisma';

// ─── Types ────────────────────────────────────────────────────────────────────

export type RiskLevel = 'SAFE' | 'AT_RISK' | 'HIGH_RISK' | 'CHURNING';

export interface MemberChurnScore {
  userId: string;
  membershipId: string;
  fullName: string;
  email: string;
  avatarUrl: string | null;
  planName: string;
  membershipEndDate: Date;
  status: string;
  score: number;           // 0–100
  riskLevel: RiskLevel;
  daysSinceLastCheckIn: number | null;
  checkInsLast30Days: number;
  checkInsPrev30Days: number;
  daysUntilExpiry: number;
}

// ─── Scoring Weights ──────────────────────────────────────────────────────────

function scoreFromDaysSinceCheckIn(days: number | null): number {
  if (days === null) return 70;   // Never checked in = high risk
  if (days <= 7)    return 0;
  if (days <= 14)   return 20;
  if (days <= 21)   return 40;
  if (days <= 30)   return 60;
  if (days <= 60)   return 80;
  return 100;
}

function scoreFromFrequencyTrend(recent: number, previous: number): number {
  if (recent === 0 && previous === 0) return 30;
  if (previous === 0) return 0;  // First-time activity is good
  const dropRatio = (previous - recent) / previous;
  if (dropRatio >= 0.8)  return 40;  // Dropped 80%+
  if (dropRatio >= 0.5)  return 25;  // Dropped 50%+
  if (dropRatio >= 0.25) return 10;  // Dropped 25%+
  if (dropRatio <= -0.2) return -15; // Improved 20%+ (bonus)
  return 0;
}

function scoreFromExpiry(daysUntilExpiry: number): number {
  if (daysUntilExpiry < 0)  return 50;  // Already expired
  if (daysUntilExpiry <= 3) return 40;
  if (daysUntilExpiry <= 7) return 25;
  if (daysUntilExpiry <= 14) return 15;
  if (daysUntilExpiry <= 30) return 5;
  return 0;
}

function riskLevel(score: number): RiskLevel {
  if (score >= 75) return 'CHURNING';
  if (score >= 55) return 'HIGH_RISK';
  if (score >= 35) return 'AT_RISK';
  return 'SAFE';
}

// ─── Service ──────────────────────────────────────────────────────────────────

export class ChurnService {

  /**
   * Compute churn risk scores for all ACTIVE members of a gym.
   * Returns results sorted by score descending (highest risk first).
   */
  static async computeForGym(gymId: string): Promise<MemberChurnScore[]> {
    const now = new Date();
    const ago30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const ago60 = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);

    // Fetch all active memberships with user + plan data
    const memberships = await prisma.gymMembership.findMany({
      where: { gymId, status: 'ACTIVE' },
      include: {
        user: { select: { id: true, fullName: true, email: true, avatarUrl: true } },
        plan: { select: { name: true } },
      },
    });

    if (memberships.length === 0) return [];

    const userIds = memberships.map((m) => m.userId);

    // Fetch last check-in per user
    const lastCheckIns = await prisma.attendance.findMany({
      where: { gymId, userId: { in: userIds } },
      orderBy: { checkIn: 'desc' },
      distinct: ['userId'],
      select: { userId: true, checkIn: true },
    });
    const lastCheckInMap = new Map(lastCheckIns.map((a) => [a.userId, a.checkIn]));

    // Fetch check-in counts for recent 30 days
    const recentCheckins = await prisma.attendance.groupBy({
      by: ['userId'],
      where: { gymId, userId: { in: userIds }, checkIn: { gte: ago30 } },
      _count: { id: true },
    });
    const recentMap = new Map(recentCheckins.map((r) => [r.userId, r._count.id]));

    // Fetch check-in counts for previous 30 days (30–60 days ago)
    const prevCheckins = await prisma.attendance.groupBy({
      by: ['userId'],
      where: { gymId, userId: { in: userIds }, checkIn: { gte: ago60, lt: ago30 } },
      _count: { id: true },
    });
    const prevMap = new Map(prevCheckins.map((r) => [r.userId, r._count.id]));

    // Build scores
    const results: MemberChurnScore[] = memberships.map((m) => {
      const lastCheckIn = lastCheckInMap.get(m.userId) ?? null;
      const daysSince = lastCheckIn
        ? Math.floor((now.getTime() - lastCheckIn.getTime()) / (1000 * 60 * 60 * 24))
        : null;
      const recentCount = recentMap.get(m.userId) ?? 0;
      const prevCount = prevMap.get(m.userId) ?? 0;
      const daysUntilExpiry = Math.floor((m.endDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

      // Weighted composite score
      const s1 = scoreFromDaysSinceCheckIn(daysSince) * 0.50;
      const s2 = scoreFromFrequencyTrend(recentCount, prevCount) * 0.30;
      const s3 = scoreFromExpiry(daysUntilExpiry) * 0.20;

      const rawScore = Math.round(s1 + s2 + s3);
      const score = Math.max(0, Math.min(100, rawScore));

      return {
        userId: m.userId,
        membershipId: m.id,
        fullName: m.user.fullName,
        email: m.user.email,
        avatarUrl: m.user.avatarUrl,
        planName: m.plan.name,
        membershipEndDate: m.endDate,
        status: m.status,
        score,
        riskLevel: riskLevel(score),
        daysSinceLastCheckIn: daysSince,
        checkInsLast30Days: recentCount,
        checkInsPrev30Days: prevCount,
        daysUntilExpiry,
      };
    });

    return results.sort((a, b) => b.score - a.score);
  }

  /**
   * Get only at-risk members (score >= 35) for a gym.
   */
  static async getAtRisk(gymId: string): Promise<MemberChurnScore[]> {
    const all = await this.computeForGym(gymId);
    return all.filter((m) => m.score >= 35);
  }

  /**
   * Summary stats for a gym's churn state.
   */
  static async getSummary(gymId: string) {
    const all = await this.computeForGym(gymId);
    return {
      total: all.length,
      safe:      all.filter((m) => m.riskLevel === 'SAFE').length,
      atRisk:    all.filter((m) => m.riskLevel === 'AT_RISK').length,
      highRisk:  all.filter((m) => m.riskLevel === 'HIGH_RISK').length,
      churning:  all.filter((m) => m.riskLevel === 'CHURNING').length,
      avgScore:  all.length ? Math.round(all.reduce((s, m) => s + m.score, 0) / all.length) : 0,
    };
  }
}

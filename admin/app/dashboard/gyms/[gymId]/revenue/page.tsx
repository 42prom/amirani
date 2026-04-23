"use client";

import { useParams } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import {
  revenueApi,
  RevenueIntelligence,
  MonthlyRevenue,
  PlanRevenue,
  PeakHourBucket,
  RecentPayment,
} from "@/lib/api";
import {
  TrendingUp,
  TrendingDown,
  DollarSign,
  AlertTriangle,
  Users,
  UserPlus,
  ArrowUpRight,
  ArrowDownRight,
  Minus,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import clsx from "clsx";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const fmt = (n: number) =>
  n >= 1000 ? `$${(n / 1000).toFixed(1)}k` : `$${n.toFixed(0)}`;

const fmtFull = (n: number) =>
  `$${n.toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

// ─── KPI Card ─────────────────────────────────────────────────────────────────

function KpiCard({
  label,
  value,
  sub,
  icon: Icon,
  trend,
  trendLabel,
  accent = false,
  danger = false,
}: {
  label: string;
  value: string;
  sub?: string;
  icon: React.ElementType;
  trend?: number;
  trendLabel?: string;
  accent?: boolean;
  danger?: boolean;
}) {
  const TrendIcon =
    trend === undefined ? null : trend > 0 ? ArrowUpRight : trend < 0 ? ArrowDownRight : Minus;
  const trendColor =
    trend === undefined ? "" : trend > 0 ? "text-green-400" : trend < 0 ? "text-red-400" : "text-zinc-500";

  return (
    <div className={clsx(
      "bg-zinc-900 border rounded-xl p-5 flex flex-col gap-3",
      danger ? "border-red-500/30" : accent ? "border-[#F1C40F]/20" : "border-zinc-800"
    )}>
      <div className="flex items-center justify-between">
        <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500">{label}</p>
        <div className={clsx(
          "p-2 rounded-lg",
          danger ? "bg-red-500/10" : accent ? "bg-[#F1C40F]/10" : "bg-zinc-800"
        )}>
          <Icon size={14} className={danger ? "text-red-400" : accent ? "text-[#F1C40F]" : "text-zinc-400"} />
        </div>
      </div>
      <div>
        <p className={clsx(
          "text-2xl font-bold",
          danger ? "text-red-400" : accent ? "text-[#F1C40F]" : "text-white"
        )}>
          {value}
        </p>
        {sub && <p className="text-xs text-zinc-500 mt-0.5">{sub}</p>}
      </div>
      {TrendIcon && trend !== undefined && (
        <div className={clsx("flex items-center gap-1 text-xs font-medium", trendColor)}>
          <TrendIcon size={12} />
          <span>{Math.abs(trend).toFixed(1)}% {trendLabel}</span>
        </div>
      )}
    </div>
  );
}

// ─── MRR Bar Chart (pure SVG) ─────────────────────────────────────────────────

function MRRChart({ data }: { data: MonthlyRevenue[] }) {
  const maxVal = Math.max(...data.map((d) => Math.max(d.realized, d.projected)), 1);
  const H = 120;
  const BAR_W = 20;
  const GAP = 8;
  const SLOT = BAR_W * 2 + GAP + 12;
  const W = data.length * SLOT + 20;

  return (
    <div className="overflow-x-auto">
      <svg width={W} height={H + 40} className="block">
        {/* Grid lines */}
        {[0, 0.25, 0.5, 0.75, 1].map((pct) => (
          <line
            key={pct}
            x1={0} x2={W}
            y1={H - pct * H} y2={H - pct * H}
            stroke="#27272a" strokeWidth={1}
          />
        ))}
        {data.map((d, i) => {
          const x = i * SLOT + 10;
          const rH = (d.realized / maxVal) * H;
          const pH = (d.projected / maxVal) * H;
          return (
            <g key={i}>
              {/* Projected (lighter) */}
              <rect
                x={x} y={H - pH}
                width={BAR_W} height={pH}
                rx={3}
                fill="#F1C40F"
                opacity={0.25}
              />
              {/* Realized (solid) */}
              <rect
                x={x + BAR_W + 4} y={H - rH}
                width={BAR_W} height={rH}
                rx={3}
                fill="#F1C40F"
                opacity={0.9}
              />
              {/* Month label */}
              <text
                x={x + BAR_W + 2} y={H + 18}
                textAnchor="middle"
                fontSize={10}
                fill="#71717a"
              >
                {d.month}
              </text>
            </g>
          );
        })}
      </svg>
      {/* Legend */}
      <div className="flex items-center gap-4 mt-2">
        <div className="flex items-center gap-1.5 text-[11px] text-zinc-400">
          <div className="w-3 h-3 rounded-sm bg-[#F1C40F]/25" />
          Projected MRR
        </div>
        <div className="flex items-center gap-1.5 text-[11px] text-zinc-400">
          <div className="w-3 h-3 rounded-sm bg-[#F1C40F]/90" />
          Realized
        </div>
      </div>
    </div>
  );
}

// ─── Plan Breakdown ───────────────────────────────────────────────────────────

function PlanBreakdown({ plans }: { plans: PlanRevenue[] }) {
  const COLORS = ["#F1C40F", "#3b82f6", "#10b981", "#f97316", "#a855f7", "#ec4899"];

  return (
    <div className="space-y-3">
      {plans.map((p, i) => (
        <div key={p.planId} className="space-y-1.5">
          <div className="flex items-center justify-between text-sm">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: COLORS[i % COLORS.length] }} />
              <span className="text-white font-medium truncate max-w-[160px]">{p.planName}</span>
              <span className="text-zinc-500 text-xs">{p.activeMembers} members</span>
            </div>
            <div className="text-right">
              <span className="text-white font-mono text-sm">{fmt(p.monthlyValue)}</span>
              <span className="text-zinc-500 text-xs ml-1.5">{p.percentage}%</span>
            </div>
          </div>
          <div className="w-full bg-zinc-800 h-1.5 rounded-full overflow-hidden">
            <div
              className="h-full rounded-full transition-all duration-700"
              style={{
                width: `${p.percentage}%`,
                backgroundColor: COLORS[i % COLORS.length],
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Peak Hours Chart ─────────────────────────────────────────────────────────

function PeakHoursChart({ data }: { data: PeakHourBucket[] }) {
  const maxCount = Math.max(...data.map((d) => d.count), 1);
  const businessHours = data.filter((d) => d.hour >= 5 && d.hour <= 22);

  return (
    <div className="space-y-1">
      <div className="flex items-end gap-1 h-16">
        {businessHours.map((d) => {
          const pct = (d.count / maxCount) * 100;
          const isPeak = pct >= 70;
          const isMid = pct >= 35;
          return (
            <div key={d.hour} className="flex-1 flex flex-col items-center gap-1" title={`${d.hour}:00 — ${d.count} visits`}>
              <div
                className={clsx(
                  "w-full rounded-t transition-all",
                  isPeak ? "bg-[#F1C40F]" : isMid ? "bg-[#F1C40F]/50" : "bg-zinc-700"
                )}
                style={{ height: `${Math.max(2, pct * 0.56)}px` }}
              />
            </div>
          );
        })}
      </div>
      <div className="flex justify-between text-[10px] text-zinc-600 px-0.5">
        <span>5am</span>
        <span>9am</span>
        <span>1pm</span>
        <span>5pm</span>
        <span>9pm</span>
        <span>10pm</span>
      </div>
      <div className="flex items-center gap-4 mt-2">
        {[
          { color: "bg-[#F1C40F]", label: "Peak (70%+)" },
          { color: "bg-[#F1C40F]/50", label: "Mid (35%+)" },
          { color: "bg-zinc-700", label: "Low" },
        ].map((l) => (
          <div key={l.label} className="flex items-center gap-1.5 text-[11px] text-zinc-400">
            <div className={`w-2.5 h-2.5 rounded-sm ${l.color}`} />
            {l.label}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Recent Payments ──────────────────────────────────────────────────────────

function RecentPayments({ payments }: { payments: RecentPayment[] }) {
  if (payments.length === 0) {
    return <p className="text-zinc-500 text-sm text-center py-6">No payments yet.</p>;
  }
  return (
    <div className="space-y-1">
      {payments.map((p) => (
        <div key={p.id} className="flex items-center justify-between px-3 py-2.5 rounded-lg hover:bg-zinc-800/50 transition-colors">
          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-white truncate">{p.userFullName}</p>
            <p className="text-xs text-zinc-500 truncate">
              {p.description ?? "Subscription payment"} · {new Date(p.createdAt).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
            </p>
          </div>
          <p className="text-sm font-mono font-semibold text-green-400 shrink-0 ml-3">
            +{fmtFull(p.amount)}
          </p>
        </div>
      ))}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function RevenuePage() {
  const { gymId } = useParams<{ gymId: string }>();
  const { token } = useAuthStore();

  const { data, isLoading } = useQuery({
    queryKey: ["revenue-intelligence", gymId],
    queryFn: () => revenueApi.getIntelligence(gymId, token!),
    enabled: !!token,
    staleTime: 5 * 60 * 1000, // 5 min cache
  });

  const intel = (data as { data: RevenueIntelligence })?.data ?? null;
  const kpis = intel?.kpis;

  if (isLoading || !intel || !kpis) {
    return (
      <div className="">
        <PageHeader
          title="Revenue Intelligence"
          description="Financial health, revenue trends, and at-risk revenue in one view."
          icon={<TrendingUp size={24} />}
        />
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 h-28 animate-pulse" />
          ))}
        </div>
        <div className="mt-4 bg-zinc-900 border border-zinc-800 rounded-xl h-64 animate-pulse" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Revenue Intelligence"
        description="Financial health, revenue trends, and at-risk revenue in one view."
        icon={<TrendingUp size={24} />}
      />

      {/* KPI Row */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard
          label="Monthly Recurring Revenue"
          value={fmt(kpis.mrr)}
          sub={`ARR: ${fmt(kpis.arr)}`}
          icon={DollarSign}
          accent
        />
        <KpiCard
          label="Revenue at Risk"
          value={fmt(kpis.revenueAtRisk)}
          sub={`${kpis.revenueAtRiskPct}% of MRR`}
          icon={AlertTriangle}
          danger={kpis.revenueAtRiskPct > 20}
        />
        <KpiCard
          label="Avg Revenue / Member"
          value={fmt(kpis.avgRevenuePerMember)}
          sub={`${kpis.activeMembers} active members`}
          icon={Users}
        />
        <KpiCard
          label="Realized This Month"
          value={fmt(kpis.realizedThisMonth)}
          sub={`vs ${fmt(kpis.realizedLastMonth)} last month`}
          icon={kpis.momGrowthPct >= 0 ? TrendingUp : TrendingDown}
          trend={kpis.momGrowthPct}
          trendLabel="MoM"
        />
      </div>

      {/* Secondary KPIs */}
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-4">
          <p className="text-[10px] font-black uppercase tracking-[0.15em] text-zinc-500">New Members This Month</p>
          <p className="text-3xl font-bold text-white mt-2">{kpis.newMembersThisMonth}</p>
          <div className="flex items-center gap-1 text-xs text-green-400 mt-1">
            <UserPlus size={11} /> joined this month
          </div>
        </div>
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-4">
          <p className="text-[10px] font-black uppercase tracking-[0.15em] text-zinc-500">Annual Recurring Revenue</p>
          <p className="text-3xl font-bold text-[#F1C40F] mt-2">{fmt(kpis.arr)}</p>
          <p className="text-xs text-zinc-500 mt-1">based on current active memberships</p>
        </div>
        <div className={clsx(
          "bg-zinc-900 border rounded-xl p-4",
          kpis.revenueAtRiskPct > 20 ? "border-red-500/30" : "border-zinc-800"
        )}>
          <p className="text-[10px] font-black uppercase tracking-[0.15em] text-zinc-500">At-Risk Revenue</p>
          <p className={clsx("text-3xl font-bold mt-2", kpis.revenueAtRiskPct > 20 ? "text-red-400" : "text-orange-400")}>
            {kpis.revenueAtRiskPct}%
          </p>
          <p className="text-xs text-zinc-500 mt-1">
            {fmtFull(kpis.revenueAtRisk)} in churn-risk memberships
          </p>
        </div>
      </div>

      {/* Main Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* MRR Trend */}
        <div className="lg:col-span-2 bg-zinc-900 border border-zinc-800 rounded-xl p-5">
          <div className="flex items-center justify-between mb-5">
            <div>
              <p className="text-sm font-bold text-white">Revenue Trend</p>
              <p className="text-xs text-zinc-500 mt-0.5">Projected MRR vs realized revenue, last 6 months</p>
            </div>
          </div>
          <MRRChart data={intel.monthlyTrend} />
        </div>

        {/* Plan Breakdown */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
          <div className="mb-5">
            <p className="text-sm font-bold text-white">Revenue by Plan</p>
            <p className="text-xs text-zinc-500 mt-0.5">Monthly value from active memberships</p>
          </div>
          {intel.planBreakdown.length === 0 ? (
            <p className="text-zinc-500 text-sm text-center py-8">No active memberships</p>
          ) : (
            <PlanBreakdown plans={intel.planBreakdown} />
          )}
        </div>
      </div>

      {/* Bottom Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Peak Hours */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
          <div className="mb-4">
            <p className="text-sm font-bold text-white">Peak Visit Hours</p>
            <p className="text-xs text-zinc-500 mt-0.5">Check-in distribution over last 30 days</p>
          </div>
          <PeakHoursChart data={intel.peakHours} />
        </div>

        {/* Recent Payments */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
          <div className="mb-4">
            <p className="text-sm font-bold text-white">Recent Payments</p>
            <p className="text-xs text-zinc-500 mt-0.5">Latest successful transactions</p>
          </div>
          <RecentPayments payments={intel.recentPayments} />
        </div>
      </div>
    </div>
  );
}

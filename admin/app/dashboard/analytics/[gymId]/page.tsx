"use client";

import { useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { analyticsApi } from "@/lib/api";
import {
  Activity,
  TrendingUp,
  Users,
  Trophy,
  BarChart3,
  ArrowLeft,
  RefreshCw,
  Clock,
  Target,
  Star,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";

// ─── Helpers ──────────────────────────────────────────────────────────────────

function SectionCard({ title, icon: Icon, iconColor = "text-[#F1C40F]", children }: {
  title: string;
  icon: React.ElementType;
  iconColor?: string;
  children: React.ReactNode;
}) {
  return (
    <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-6">
      <h2 className="text-white font-bold text-lg mb-6 flex items-center gap-3">
        <Icon size={20} className={iconColor} />
        {title}
      </h2>
      {children}
    </div>
  );
}

function KpiPill({ label, value, sub, color = "text-white" }: { label: string; value: string | number; sub?: string; color?: string }) {
  return (
    <div className="bg-white/[0.03] border border-white/5 rounded-xl p-4">
      <p className="text-[10px] text-zinc-500 uppercase font-black tracking-widest mb-1">{label}</p>
      <p className={`text-2xl font-bold ${color}`}>{value}</p>
      {sub && <p className="text-xs text-zinc-500 mt-0.5">{sub}</p>}
    </div>
  );
}

function HBar({ label, value, max, color = "bg-[#F1C40F]", suffix = "" }: { label: string; value: number; max: number; color?: string; suffix?: string }) {
  const pct = max > 0 ? Math.round((value / max) * 100) : 0;
  return (
    <div className="flex items-center gap-3">
      <span className="text-zinc-400 text-sm w-10 flex-shrink-0">{label}</span>
      <div className="flex-1 bg-zinc-800 rounded-full h-2">
        <div className={`${color} h-2 rounded-full transition-all`} style={{ width: `${pct}%` }} />
      </div>
      <span className="text-white text-sm w-12 text-right font-medium">{value}{suffix}</span>
    </div>
  );
}

// ─── Sections ─────────────────────────────────────────────────────────────────

function MemberPulse({ gymId, token }: { gymId: string; token: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ["gym-pulse", gymId],
    queryFn: () => analyticsApi.getGymPulse(gymId, token),
    refetchInterval: 30_000,
  });

  if (isLoading) return <SectionCard title="Member Pulse" icon={Activity}><Skeleton /></SectionCard>;
  if (!data) return null;

  const peakHour = data.hourlyCheckins.reduce((best, h) => h.count > best.count ? h : best, { hour: 0, count: 0 });
  const maxCount = Math.max(...data.hourlyCheckins.map(h => h.count), 1);

  const fmt = (h: number) => {
    const ampm = h >= 12 ? "PM" : "AM";
    const h12 = h % 12 || 12;
    return `${h12}${ampm}`;
  };

  return (
    <SectionCard title="Member Pulse" icon={Activity}>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
        <KpiPill label="Active Now" value={data.activeNow} color="text-green-400" />
        <KpiPill label="Check-ins Today" value={data.todayTotal} />
        <KpiPill label="Yesterday" value={data.yesterdayTotal} />
        <KpiPill
          label="vs Yesterday"
          value={`${data.vsYesterday > 0 ? "+" : ""}${data.vsYesterday}%`}
          color={data.vsYesterday >= 0 ? "text-green-400" : "text-red-400"}
        />
      </div>
      <div className="mb-3 flex items-center justify-between">
        <p className="text-sm text-zinc-400">Hourly Check-ins (Today)</p>
        {peakHour.count > 0 && (
          <span className="text-xs text-[#F1C40F] font-bold">
            Peak: {fmt(peakHour.hour)} ({peakHour.count})
          </span>
        )}
      </div>
      <div className="flex items-end gap-0.5 h-20">
        {data.hourlyCheckins.map(h => {
          const heightPct = maxCount > 0 ? (h.count / maxCount) * 100 : 0;
          const isNow = h.hour === new Date().getHours();
          return (
            <div key={h.hour} className="flex-1 flex flex-col items-center justify-end gap-1">
              <div
                className={`w-full rounded-t transition-all ${isNow ? "bg-[#F1C40F]" : "bg-zinc-700"}`}
                style={{ height: `${Math.max(heightPct, h.count > 0 ? 8 : 2)}%` }}
                title={`${fmt(h.hour)}: ${h.count}`}
              />
            </div>
          );
        })}
      </div>
      <div className="flex justify-between text-[9px] text-zinc-600 mt-1">
        <span>12AM</span><span>6AM</span><span>12PM</span><span>6PM</span><span>11PM</span>
      </div>
    </SectionCard>
  );
}

function RevenueForecast({ gymId, token }: { gymId: string; token: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ["gym-revenue", gymId],
    queryFn: () => analyticsApi.getGymRevenue(gymId, token),
  });

  if (isLoading) return <SectionCard title="Revenue Forecast" icon={TrendingUp}><Skeleton /></SectionCard>;
  if (!data) return null;

  const { kpis, monthlyTrend } = data;
  const maxRealized = Math.max(...monthlyTrend.map(m => m.realized), 1);
  const forecastNext = Math.round(kpis.mrr * 1.02); // MRR + 2% buffer as 30-day projection

  return (
    <SectionCard title="Revenue Forecast" icon={TrendingUp}>
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-6">
        <KpiPill label="MRR" value={`$${kpis.mrr.toLocaleString()}`} color="text-[#F1C40F]" />
        <KpiPill label="ARR" value={`$${kpis.arr.toLocaleString()}`} />
        <KpiPill
          label="MoM Growth"
          value={`${kpis.momGrowthPct > 0 ? "+" : ""}${kpis.momGrowthPct}%`}
          color={kpis.momGrowthPct >= 0 ? "text-green-400" : "text-red-400"}
        />
        <KpiPill label="Next 30-day Proj." value={`$${forecastNext.toLocaleString()}`} color="text-blue-400" sub="based on MRR" />
      </div>
      <p className="text-sm text-zinc-400 mb-3">6-Month Revenue Trend</p>
      <div className="space-y-2">
        {monthlyTrend.map(m => (
          <HBar key={m.month} label={m.month} value={m.realized} max={maxRealized} suffix="" />
        ))}
      </div>
      {kpis.revenueAtRisk > 0 && (
        <div className="mt-4 p-3 bg-red-500/8 border border-red-500/20 rounded-xl flex items-center gap-3">
          <Target size={16} className="text-red-400 flex-shrink-0" />
          <p className="text-sm text-zinc-300">
            <span className="text-red-400 font-bold">${kpis.revenueAtRisk.toLocaleString()}</span>
            {" "}({kpis.revenueAtRiskPct}%) of MRR at churn risk
          </p>
        </div>
      )}
    </SectionCard>
  );
}

function RetentionHeatmap({ gymId, token }: { gymId: string; token: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ["retention-heatmap", gymId],
    queryFn: () => analyticsApi.getRetentionHeatmap(gymId, token),
  });

  if (isLoading) return <SectionCard title="Retention Heatmap" icon={BarChart3} iconColor="text-purple-400"><Skeleton /></SectionCard>;
  if (!data) return null;

  const weekdayOrder = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  const sorted = weekdayOrder.map(d => data.byDayOfWeek.find(x => x.day === d) ?? { day: d, count: 0, avgPerWeek: 0 });
  const max = Math.max(...sorted.map(d => d.count), 1);
  const weakest = sorted.reduce((a, b) => a.count < b.count ? a : b);

  return (
    <SectionCard title="Retention Heatmap" icon={BarChart3} iconColor="text-purple-400">
      <p className="text-sm text-zinc-500 mb-4">Check-in frequency by day of week (last {data.periodWeeks} weeks)</p>
      <div className="space-y-3">
        {sorted.map(d => {
          const isWeak = d.day === weakest.day;
          return (
            <div key={d.day} className="flex items-center gap-3">
              <span className={`text-sm w-8 flex-shrink-0 font-medium ${isWeak ? "text-red-400" : "text-zinc-400"}`}>{d.day}</span>
              <div className="flex-1 bg-zinc-800 rounded-full h-3">
                <div
                  className={`h-3 rounded-full transition-all ${isWeak ? "bg-red-500/60" : "bg-purple-500"}`}
                  style={{ width: `${Math.round((d.count / max) * 100)}%` }}
                />
              </div>
              <span className="text-white text-sm w-16 text-right">
                {d.count} <span className="text-zinc-600 text-xs">({d.avgPerWeek}/wk)</span>
              </span>
            </div>
          );
        })}
      </div>
      {weakest.count < (data.totalCheckins / 7) * 0.6 && (
        <div className="mt-4 p-3 bg-orange-500/8 border border-orange-500/20 rounded-xl text-sm text-zinc-300">
          <span className="text-orange-400 font-bold">{weakest.day}</span> is your lowest attendance day —
          consider offering a promotion or class to boost {weakest.day} traffic.
        </div>
      )}
    </SectionCard>
  );
}

function TopTrainers({ gymId, token }: { gymId: string; token: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ["top-trainers", gymId],
    queryFn: () => analyticsApi.getTopTrainers(gymId, token),
  });

  if (isLoading) return <SectionCard title="Top Trainers" icon={Trophy}><Skeleton /></SectionCard>;
  if (!data || data.length === 0) {
    return (
      <SectionCard title="Top Trainers" icon={Trophy}>
        <p className="text-zinc-500 text-sm">No trainer data for this gym yet.</p>
      </SectionCard>
    );
  }

  return (
    <SectionCard title="Top Trainers" icon={Trophy}>
      <p className="text-xs text-zinc-500 uppercase tracking-widest font-bold mb-4">Ranked by session completion rate</p>
      <div className="space-y-3">
        {data.map((t, i) => (
          <div key={t.trainerId} className="flex items-center gap-4 p-4 bg-white/[0.02] border border-white/5 rounded-xl">
            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-black flex-shrink-0 ${
              i === 0 ? "bg-[#F1C40F] text-black" :
              i === 1 ? "bg-zinc-400 text-black" :
              i === 2 ? "bg-orange-600 text-white" : "bg-zinc-700 text-white"
            }`}>
              {i + 1}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-white font-semibold text-sm truncate">{t.fullName}</p>
              <p className="text-zinc-500 text-xs mt-0.5">
                {t.assignedMembers} members · {t.sessionsThisMonth} sessions this month
              </p>
            </div>
            <div className="text-right flex-shrink-0">
              <div className={`text-lg font-black ${
                t.completionRate >= 80 ? "text-green-400" :
                t.completionRate >= 50 ? "text-[#F1C40F]" : "text-red-400"
              }`}>
                {t.completionRate}%
              </div>
              <p className="text-[10px] text-zinc-600 uppercase tracking-wide">completion</p>
            </div>
          </div>
        ))}
      </div>
    </SectionCard>
  );
}

function PlanMix({ gymId, token }: { gymId: string; token: string }) {
  const { data, isLoading } = useQuery({
    queryKey: ["plan-mix", gymId],
    queryFn: () => analyticsApi.getPlanMix(gymId, token),
  });

  if (isLoading) return <SectionCard title="Plan Mix" icon={Star} iconColor="text-blue-400"><Skeleton /></SectionCard>;
  if (!data || data.plans.length === 0) {
    return (
      <SectionCard title="Plan Mix" icon={Star} iconColor="text-blue-400">
        <p className="text-zinc-500 text-sm">No membership plan data yet.</p>
      </SectionCard>
    );
  }

  const { plans, totalActiveMembers } = data;

  return (
    <SectionCard title="Plan Mix" icon={Star} iconColor="text-blue-400">
      <div className="grid grid-cols-2 gap-4 mb-6">
        <KpiPill label="Total Active Members" value={totalActiveMembers.toLocaleString()} color="text-[#F1C40F]" />
        <KpiPill label="Distinct Plans" value={plans.length} />
      </div>
      <div className="space-y-4">
        {plans.map(plan => (
          <div key={plan.planId}>
            <div className="flex items-center justify-between mb-1.5">
              <div className="flex items-center gap-2">
                <span className="text-white text-sm font-medium">{plan.name}</span>
                <span className="text-zinc-600 text-xs">${plan.price}/mo</span>
              </div>
              <div className="flex items-center gap-3 text-xs">
                {plan.pendingCount > 0 && <span className="text-yellow-400">{plan.pendingCount} pending</span>}
                {plan.frozenCount > 0 && <span className="text-blue-400">{plan.frozenCount} frozen</span>}
                {plan.cancelledCount > 0 && <span className="text-red-400">{plan.cancelledCount} cancelled</span>}
                <span className="text-white font-bold">{plan.activeCount} active ({plan.percentage}%)</span>
              </div>
            </div>
            <div className="w-full bg-zinc-800 rounded-full h-2.5">
              <div className="bg-blue-500 h-2.5 rounded-full transition-all" style={{ width: `${plan.percentage}%` }} />
            </div>
          </div>
        ))}
      </div>
    </SectionCard>
  );
}

function Skeleton() {
  return (
    <div className="space-y-3">
      {[1, 2, 3].map(i => (
        <div key={i} className="h-8 bg-zinc-800 rounded-lg animate-pulse" />
      ))}
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function GymAnalyticsPage() {
  const { gymId } = useParams<{ gymId: string }>();
  const { token } = useAuthStore();
  const router = useRouter();

  if (!token || !gymId) return null;

  return (
    <div className="space-y-6 animate-in fade-in duration-700">
      <div className="flex items-center gap-4">
        <button
          onClick={() => router.back()}
          className="p-2 bg-white/5 hover:bg-white/10 border border-zinc-800 rounded-xl text-zinc-400 transition-all"
        >
          <ArrowLeft size={18} />
        </button>
        <PageHeader
          title="Analytics Deep Dive"
          description="Member pulse, revenue, retention and trainer performance"
          icon={<BarChart3 size={24} />}
        />
      </div>

      {/* Row 1: Pulse + Revenue */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <MemberPulse gymId={gymId} token={token} />
        <RevenueForecast gymId={gymId} token={token} />
      </div>

      {/* Row 2: Retention heatmap + Plan mix */}
      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <RetentionHeatmap gymId={gymId} token={token} />
        <PlanMix gymId={gymId} token={token} />
      </div>

      {/* Row 3: Top Trainers (full width) */}
      <TopTrainers gymId={gymId} token={token} />
    </div>
  );
}

"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/auth-store";
import { useQuery } from "@tanstack/react-query";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import {
  analyticsApi,
  marketingApi,
  MemberChurnScore,
  RiskLevel,
  CampaignAudience,
} from "@/lib/api";
import {
  AlertTriangle,
  RefreshCw,
  Users,
  TrendingDown,
  Shield,
  Flame,
  Loader2,
  Send,
  ChevronRight,
} from "lucide-react";

// ─── Risk config ──────────────────────────────────────────────────────────────

const RISK_CONFIG: Record<RiskLevel, { label: string; bar: string; badge: string; text: string; icon: typeof Shield }> = {
  SAFE:      { label: "Safe",       bar: "bg-green-500",  badge: "bg-green-500/10 border-green-500/20",  text: "text-green-400",  icon: Shield },
  AT_RISK:   { label: "At Risk",    bar: "bg-yellow-400", badge: "bg-yellow-400/10 border-yellow-400/20", text: "text-yellow-400", icon: AlertTriangle },
  HIGH_RISK: { label: "High Risk",  bar: "bg-orange-500", badge: "bg-orange-500/10 border-orange-500/20", text: "text-orange-400", icon: TrendingDown },
  CHURNING:  { label: "Churning",   bar: "bg-red-500",    badge: "bg-red-500/10 border-red-500/20",       text: "text-red-400",   icon: Flame },
};

// ─── Score Ring ───────────────────────────────────────────────────────────────

function ScoreRing({ score, level }: { score: number; level: RiskLevel }) {
  const cfg = RISK_CONFIG[level];
  const r = 20;
  const circ = 2 * Math.PI * r;
  const dash = (score / 100) * circ;

  return (
    <div className="relative w-14 h-14 shrink-0">
      <svg viewBox="0 0 48 48" className="w-full h-full -rotate-90">
        <circle cx="24" cy="24" r={r} fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="4" />
        <circle
          cx="24" cy="24" r={r} fill="none"
          stroke={level === "SAFE" ? "#22c55e" : level === "AT_RISK" ? "#facc15" : level === "HIGH_RISK" ? "#f97316" : "#ef4444"}
          strokeWidth="4"
          strokeDasharray={`${dash} ${circ - dash}`}
          strokeLinecap="round"
        />
      </svg>
      <span className={`absolute inset-0 flex items-center justify-center text-xs font-black ${cfg.text}`}>
        {score}
      </span>
    </div>
  );
}

// ─── Member Row ───────────────────────────────────────────────────────────────

function MemberRow({ member }: { member: MemberChurnScore }) {
  const cfg = RISK_CONFIG[member.riskLevel];
  const Icon = cfg.icon;

  return (
    <div className="group relative overflow-hidden flex items-center gap-6 p-6 bg-[#121721] border border-white/5 rounded-3xl hover:border-white/10 transition-all shadow-xl">
      <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
      
      {/* Avatar */}
      <div className="relative z-10 w-12 h-12 rounded-2xl bg-white/[0.03] border border-white/5 flex items-center justify-center text-sm font-black text-zinc-400 shrink-0 uppercase group-hover:bg-white/[0.08] transition-colors">
        {member.fullName.charAt(0)}
      </div>

      {/* Info */}
      <div className="flex-1 min-w-0 relative z-10">
        <div className="flex items-center gap-2 mb-1">
          <p className="text-xl font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors truncate">
            {member.fullName}
          </p>
          <span className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md text-[10px] font-black uppercase tracking-[0.1em] border ${cfg.badge} ${cfg.text}`}>
            <Icon size={10} />
            {cfg.label}
          </span>
        </div>
        <div className="flex items-center gap-3 text-xs text-zinc-500 font-medium">
          <span className="truncate">{member.email}</span>
          <span className="w-1 h-1 rounded-full bg-zinc-700" />
          <span className="text-zinc-600 font-black uppercase tracking-widest text-[9px]">{member.planName}</span>
        </div>
      </div>

      {/* Stats */}
      <div className="hidden md:flex items-center gap-8 shrink-0 relative z-10">
        <div className="text-center">
          <p className="text-[10px] text-zinc-600 uppercase tracking-widest font-black mb-1">Last Visit</p>
          <p className={`text-sm font-black ${member.daysSinceLastCheckIn === null ? "text-red-400" : member.daysSinceLastCheckIn > 21 ? "text-orange-400" : "text-white"}`}>
            {member.daysSinceLastCheckIn === null ? "Never" : `${member.daysSinceLastCheckIn}d ago`}
          </p>
        </div>
        <div className="text-center">
          <p className="text-[10px] text-zinc-600 uppercase tracking-widest font-black mb-1">Visits/30d</p>
          <p className="text-sm font-black text-white">{member.checkInsLast30Days}</p>
        </div>
        <div className="text-center">
          <p className="text-[10px] text-zinc-600 uppercase tracking-widest font-black mb-1">Expiry</p>
          <p className={`text-sm font-black ${member.daysUntilExpiry < 0 ? "text-red-400" : member.daysUntilExpiry <= 7 ? "text-orange-400" : "text-white"}`}>
            {member.daysUntilExpiry < 0 ? "Expired" : `${member.daysUntilExpiry}d`}
          </p>
        </div>
      </div>

      {/* Score */}
      <div className="relative z-10">
        <ScoreRing score={member.score} level={member.riskLevel} />
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

const FILTER_OPTIONS: { key: "ALL" | RiskLevel; label: string }[] = [
  { key: "ALL",       label: "All Active" },
  { key: "CHURNING",  label: "Churning" },
  { key: "HIGH_RISK", label: "High Risk" },
  { key: "AT_RISK",   label: "At Risk" },
  { key: "SAFE",      label: "Safe" },
];

export default function ChurnRiskPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const router = useRouter();
  const gymId = selectedGymId as string;
  const { token } = useAuthStore();

  const [filter, setFilter] = useState<"ALL" | RiskLevel>("ALL");
  const [sendingCampaign, setSendingCampaign] = useState<RiskLevel | null>(null);

  const { data, isLoading, isError, refetch, isFetching } = useQuery({
    queryKey: ["churn", gymId],
    queryFn: () => analyticsApi.getChurnAll(gymId, token!),
    enabled: !!token && !!gymId,
    staleTime: 2 * 60 * 1000,
  });

  const members = data?.data ?? [];

  // Summary counts
  const summary = {
    total: members.length,
    safe:     members.filter((m: MemberChurnScore) => m.riskLevel === "SAFE").length,
    atRisk:   members.filter((m: MemberChurnScore) => m.riskLevel === "AT_RISK").length,
    highRisk: members.filter((m: MemberChurnScore) => m.riskLevel === "HIGH_RISK").length,
    churning: members.filter((m: MemberChurnScore) => m.riskLevel === "CHURNING").length,
    avgScore: members.length ? Math.round(members.reduce((s: number, m: MemberChurnScore) => s + m.score, 0) / members.length) : 0,
  };

  const filtered = filter === "ALL" ? members : members.filter((m: MemberChurnScore) => m.riskLevel === filter);

  // Quick-send campaign to a risk segment
  const handleQuickCampaign = async (level: RiskLevel) => {
    const audienceMap: Record<RiskLevel, string> = {
      CHURNING:  "INACTIVE_60D",
      HIGH_RISK: "INACTIVE_30D",
      AT_RISK:   "INACTIVE_30D",
      SAFE:      "ACTIVE",
    };
    setSendingCampaign(level);
    try {
      const campaign = await marketingApi.create(gymId, {
        name: `Quick Win-Back — ${RISK_CONFIG[level].label} Members`,
        subject: "We miss you at the gym!",
        body: "Hey! We noticed you haven't been in lately. Come back and keep your streak going — your progress is waiting.",
        channels: ["PUSH", "IN_APP"],
        targetAudience: audienceMap[level] as CampaignAudience,
      }, token!);
      await marketingApi.send(gymId, campaign.data.id, token!);
      router.push(`/dashboard/gyms/${gymId}/marketing`);
    } catch {
      // fail silently — user can go to marketing page to retry
    } finally {
      setSendingCampaign(null);
    }
  };

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header Section */}
      <PageHeader
        title="Churn Risk"
        description="AI-scored member retention risk — updated on every page load."
        icon={<AlertTriangle size={32} />}
        actions={
          <div className="flex items-center gap-4">
            <button
              onClick={() => refetch()}
              disabled={isFetching}
              className="p-4 bg-white/[0.03] border border-white/10 rounded-2xl text-zinc-400 hover:text-white transition-all group shrink-0"
              title="Refresh Scores"
            >
              <RefreshCw size={20} className={isFetching ? "animate-spin" : "group-hover:rotate-180 transition-transform duration-500"} />
            </button>

            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </div>
        }
      />

      {isLoading ? (
        <div className="flex items-center justify-center h-64">
          <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
        </div>
      ) : isError ? (
        <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-10 text-center">
          <p className="text-red-400 font-bold">Failed to compute churn scores</p>
        </div>
      ) : (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-2 md:grid-cols-5 gap-6">
            {[
              { label: "Total Active", value: summary.total, color: "text-white", icon: Users, bg: "bg-white/5" },
              { label: "Safe",         value: summary.safe,     color: "text-green-400",  icon: Shield, bg: "bg-green-500/10" },
              { label: "At Risk",      value: summary.atRisk,   color: "text-yellow-400", icon: AlertTriangle, bg: "bg-yellow-400/10" },
              { label: "High Risk",    value: summary.highRisk, color: "text-orange-400", icon: TrendingDown, bg: "bg-orange-500/10" },
              { label: "Churning",     value: summary.churning, color: "text-red-400",    icon: Flame, bg: "bg-red-500/10" },
            ].map((stat) => {
              const Icon = stat.icon;
              return (
                <div key={stat.label} className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 hover:border-[#F1C40F]/30 transition-all duration-300 shadow-xl">
                  <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
                  <div className="relative flex items-center gap-4">
                    <div className={`p-3 ${stat.bg} rounded-2xl group-hover:scale-110 transition-transform duration-300`}>
                      <Icon className={stat.color} size={24} />
                    </div>
                    <div>
                      <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em]">{stat.label}</p>
                      <p className="text-3xl font-bold text-white mt-1">{stat.value}</p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Risk breakdown bar */}
          {summary.total > 0 && (
            <div className="bg-[#121721] border border-white/5 rounded-2xl p-5">
              <div className="flex items-center justify-between mb-3">
                <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest">Risk Distribution</p>
                <p className="text-sm font-black text-zinc-400">Avg Score: <span className="text-[#F1C40F]">{summary.avgScore}</span></p>
              </div>
              <div className="flex h-3 rounded-full overflow-hidden gap-0.5">
                {summary.safe > 0     && <div className="bg-green-500  transition-all" style={{ width: `${(summary.safe / summary.total) * 100}%` }} title={`Safe: ${summary.safe}`} />}
                {summary.atRisk > 0   && <div className="bg-yellow-400 transition-all" style={{ width: `${(summary.atRisk / summary.total) * 100}%` }} title={`At Risk: ${summary.atRisk}`} />}
                {summary.highRisk > 0 && <div className="bg-orange-500 transition-all" style={{ width: `${(summary.highRisk / summary.total) * 100}%` }} title={`High Risk: ${summary.highRisk}`} />}
                {summary.churning > 0 && <div className="bg-red-500    transition-all" style={{ width: `${(summary.churning / summary.total) * 100}%` }} title={`Churning: ${summary.churning}`} />}
              </div>
              <div className="flex gap-4 mt-2">
                {(["SAFE","AT_RISK","HIGH_RISK","CHURNING"] as RiskLevel[]).map((lvl) => {
                  const cfg = RISK_CONFIG[lvl];
                  return (
                    <span key={lvl} className="flex items-center gap-1.5 text-[10px] text-zinc-500">
                      <span className={`w-2 h-2 rounded-full ${cfg.bar}`} />
                      {cfg.label}
                    </span>
                  );
                })}
              </div>
            </div>
          )}

          {/* Quick Campaign Actions */}
          {(summary.churning > 0 || summary.highRisk > 0) && (
            <div className="bg-[#121721] border border-white/5 rounded-2xl p-5">
              <p className="text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-3">Quick Actions</p>
              <div className="flex flex-wrap gap-3">
                {summary.churning > 0 && (
                  <button
                    onClick={() => handleQuickCampaign("CHURNING")}
                    disabled={sendingCampaign !== null}
                    className="flex items-center gap-2 px-4 py-3 bg-red-500/10 border border-red-500/20 rounded-xl text-red-400 text-sm font-black hover:bg-red-500/20 transition-all disabled:opacity-50"
                  >
                    {sendingCampaign === "CHURNING" ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
                    Win back {summary.churning} churning members
                    <ChevronRight size={14} />
                  </button>
                )}
                {summary.highRisk > 0 && (
                  <button
                    onClick={() => handleQuickCampaign("HIGH_RISK")}
                    disabled={sendingCampaign !== null}
                    className="flex items-center gap-2 px-4 py-3 bg-orange-500/10 border border-orange-500/20 rounded-xl text-orange-400 text-sm font-black hover:bg-orange-500/20 transition-all disabled:opacity-50"
                  >
                    {sendingCampaign === "HIGH_RISK" ? <Loader2 size={14} className="animate-spin" /> : <Send size={14} />}
                    Re-engage {summary.highRisk} high-risk members
                    <ChevronRight size={14} />
                  </button>
                )}
              </div>
            </div>
          )}

          {/* Filter tabs + member list */}
          <div className="space-y-4">
            <div className="flex gap-2 flex-wrap">
              {FILTER_OPTIONS.map((opt) => {
                const count = opt.key === "ALL" ? members.length : members.filter((m: MemberChurnScore) => m.riskLevel === opt.key).length;
                return (
                  <button
                    key={opt.key}
                    onClick={() => setFilter(opt.key)}
                    className={`px-4 py-2 rounded-xl text-xs font-black uppercase tracking-widest transition-all ${
                      filter === opt.key
                        ? "bg-[#F1C40F] !text-black"
                        : "bg-white/5 text-zinc-500 hover:text-white border border-white/5"
                    }`}
                  >
                    {opt.label} <span className="opacity-60">({count})</span>
                  </button>
                );
              })}
            </div>

            {filtered.length === 0 ? (
              <div className="bg-[#121721] border border-white/5 rounded-2xl p-12 text-center">
                <Shield className="mx-auto text-green-500 mb-3" size={40} />
                <p className="text-white font-bold">No members in this category</p>
                <p className="text-zinc-500 text-sm mt-1">All active members are accounted for.</p>
              </div>
            ) : (
              <div className="space-y-2">
                {filtered.map((member: MemberChurnScore) => (
                  <MemberRow key={member.userId} member={member} />
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}

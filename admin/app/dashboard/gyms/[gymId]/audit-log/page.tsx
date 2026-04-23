"use client";

import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { auditApi, AuditLog } from "@/lib/api";
import {
  Shield,
  ChevronLeft,
  ChevronRight,
  Filter,
  Snowflake,
  Calendar,
  MessageSquare,
  Users,
  Zap,
  Megaphone,
  RefreshCw,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import { ThemedDatePicker } from "@/components/ui/ThemedDatePicker";
import { CustomSelect } from "@/components/ui/Select";
import clsx from "clsx";

// ─── Action metadata ──────────────────────────────────────────────────────────

const ACTION_META: Record<string, { label: string; color: string; bg: string; Icon: React.ElementType }> = {
  MEMBERSHIP_FROZEN:       { label: "Frozen",         color: "text-blue-400",   bg: "bg-blue-500/10",   Icon: Snowflake },
  MEMBERSHIP_UNFROZEN:     { label: "Unfrozen",        color: "text-cyan-400",   bg: "bg-cyan-500/10",   Icon: Snowflake },
  MEMBERSHIP_CREATED:      { label: "Member Added",    color: "text-green-400",  bg: "bg-green-500/10",  Icon: Users },
  MEMBERSHIP_CANCELLED:    { label: "Member Removed",  color: "text-red-400",    bg: "bg-red-500/10",    Icon: Users },
  SESSION_CREATED:         { label: "Session Created", color: "text-yellow-400", bg: "bg-yellow-500/10", Icon: Calendar },
  SESSION_UPDATED:         { label: "Session Updated", color: "text-zinc-400",   bg: "bg-zinc-500/10",   Icon: Calendar },
  SESSION_CANCELLED:       { label: "Session Cancelled", color: "text-orange-400", bg: "bg-orange-500/10", Icon: Calendar },
  SESSION_DELETED:         { label: "Session Deleted", color: "text-red-400",    bg: "bg-red-500/10",    Icon: Calendar },
  ATTENDANCE_MARKED:       { label: "Attendance",      color: "text-green-400",  bg: "bg-green-500/10",  Icon: Users },
  TICKET_CREATED:          { label: "Ticket Created",  color: "text-zinc-400",   bg: "bg-zinc-500/10",   Icon: MessageSquare },
  TICKET_RESOLVED:         { label: "Ticket Resolved", color: "text-green-400",  bg: "bg-green-500/10",  Icon: MessageSquare },
  TICKET_CLOSED:           { label: "Ticket Closed",   color: "text-zinc-400",   bg: "bg-zinc-500/10",   Icon: MessageSquare },
  TICKET_REPLIED:          { label: "Ticket Reply",    color: "text-blue-400",   bg: "bg-blue-500/10",   Icon: MessageSquare },
  TRAINER_ADDED:           { label: "Staff Added",     color: "text-green-400",  bg: "bg-green-500/10",  Icon: Users },
  TRAINER_REMOVED:         { label: "Staff Removed",   color: "text-red-400",    bg: "bg-red-500/10",    Icon: Users },
  MEMBER_ADDED:            { label: "Member Added",    color: "text-green-400",  bg: "bg-green-500/10",  Icon: Users },
  MEMBER_REMOVED:          { label: "Member Removed",  color: "text-red-400",    bg: "bg-red-500/10",    Icon: Users },
  PLAN_CREATED:            { label: "Plan Created",    color: "text-yellow-400", bg: "bg-yellow-500/10", Icon: Zap },
  PLAN_UPDATED:            { label: "Plan Updated",    color: "text-zinc-400",   bg: "bg-zinc-500/10",   Icon: Zap },
  PLAN_DELETED:            { label: "Plan Deleted",    color: "text-red-400",    bg: "bg-red-500/10",    Icon: Zap },
  AUTOMATION_FIRED:        { label: "Automation Fired", color: "text-purple-400", bg: "bg-purple-500/10", Icon: Zap },
  ANNOUNCEMENT_PUBLISHED:  { label: "Announcement",    color: "text-yellow-400", bg: "bg-yellow-500/10", Icon: Megaphone },
};

const FALLBACK_META = { label: "Action", color: "text-zinc-400", bg: "bg-zinc-500/10", Icon: Shield };

const ACTION_CATEGORIES: { label: string; actions: string[] }[] = [
  { label: "Memberships", actions: ["MEMBERSHIP_FROZEN", "MEMBERSHIP_UNFROZEN", "MEMBERSHIP_CREATED", "MEMBERSHIP_CANCELLED"] },
  { label: "Sessions",    actions: ["SESSION_CREATED", "SESSION_UPDATED", "SESSION_CANCELLED", "SESSION_DELETED", "ATTENDANCE_MARKED"] },
  { label: "Support",     actions: ["TICKET_CREATED", "TICKET_RESOLVED", "TICKET_CLOSED", "TICKET_REPLIED"] },
  { label: "Staff",       actions: ["TRAINER_ADDED", "TRAINER_REMOVED"] },
  { label: "Plans",       actions: ["PLAN_CREATED", "PLAN_UPDATED", "PLAN_DELETED"] },
  { label: "Other",       actions: ["AUTOMATION_FIRED", "ANNOUNCEMENT_PUBLISHED"] },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const mins  = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days  = Math.floor(diff / 86400000);
  if (mins < 1)   return "just now";
  if (mins < 60)  return `${mins}m ago`;
  if (hours < 24) return `${hours}h ago`;
  if (days < 7)   return `${days}d ago`;
  return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

function formatFull(iso: string): string {
  return new Date(iso).toLocaleString("en-US", {
    month: "short", day: "numeric", year: "numeric",
    hour: "2-digit", minute: "2-digit",
  });
}

// ─── Log Row ─────────────────────────────────────────────────────────────────

function LogRow({ log }: { log: AuditLog }) {
  const meta = ACTION_META[log.action] ?? FALLBACK_META;
  const { Icon } = meta;

  return (
    <div className="group relative overflow-hidden flex items-start gap-4 px-6 py-5 hover:bg-white/[0.02] transition-colors border-b border-white/5 last:border-0">
      {/* Icon */}
      <div className={clsx("flex-shrink-0 w-10 h-10 rounded-2xl flex items-center justify-center mt-0.5 shadow-lg shadow-black/20 border border-white/5 transition-transform group-hover:scale-110", meta.bg)}>
        <Icon size={18} className={meta.color} />
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0 relative z-10">
        <div className="flex items-center gap-2 flex-wrap mb-1">
          <span className={clsx("text-[10px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-md border border-white/5", meta.bg, meta.color)}>
            {meta.label}
          </span>
          <span className="text-[10px] text-zinc-600 font-black uppercase tracking-widest">{log.entity}</span>
        </div>
        <p className="text-base font-medium text-white tracking-tight leading-snug group-hover:text-[#F1C40F] transition-colors">{log.label}</p>
        <div className="flex items-center gap-3 mt-2">
          <div className="w-5 h-5 rounded-full bg-white/[0.03] border border-white/5 flex items-center justify-center flex-shrink-0">
            <span className="text-[9px] text-zinc-500 font-black uppercase">
              {log.actor.fullName.charAt(0)}
            </span>
          </div>
          <span className="text-[11px] font-bold text-zinc-500">{log.actor.fullName}</span>
          <span className="text-zinc-800">·</span>
          <span className="text-[11px] font-bold text-zinc-600" title={formatFull(log.createdAt)}>
            {timeAgo(log.createdAt)}
          </span>
        </div>
      </div>

      {/* Timestamp */}
      <div className="flex-shrink-0 text-right hidden sm:block relative z-10">
        <p className="text-[11px] font-black text-white uppercase tracking-widest leading-none">
          {new Date(log.createdAt).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false })}
        </p>
        <p className="text-[10px] font-bold text-zinc-600 mt-1 uppercase tracking-widest">
          {new Date(log.createdAt).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
        </p>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function AuditLogPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const { token } = useAuthStore();
  const gymId = selectedGymId as string;
  const [page, setPage] = useState(1);
  const [actionFilter, setActionFilter] = useState<string>("");
  const [fromDate, setFromDate] = useState("");
  const [toDate, setToDate] = useState("");
  const [showFilters, setShowFilters] = useState(false);

  const { data, isLoading, refetch, isFetching } = useQuery({
    queryKey: ["audit-log", gymId, page, actionFilter, fromDate, toDate],
    queryFn: () => auditApi.list(gymId, {
      action: actionFilter || undefined,
      from: fromDate || undefined,
      to: toDate || undefined,
      page,
    }, token!),
    enabled: !!token,
    staleTime: 30000,
  });

  const result = data?.data;
  const logs = result?.logs ?? [];

  function resetFilters() {
    setActionFilter("");
    setFromDate("");
    setToDate("");
    setPage(1);
  }

  const hasFilters = !!(actionFilter || fromDate || toDate);

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header Section */}
      <PageHeader
        title="Audit Log"
        description="Complete record of admin actions at this facility."
        icon={<Shield size={32} />}
        actions={
          <div className="flex items-center gap-4">
            <button
              onClick={() => refetch()}
              disabled={isFetching}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-white/[0.03] text-white font-black rounded-xl hover:bg-white/[0.08] border border-white/5 uppercase text-[10px] tracking-widest shadow-lg transition-all disabled:opacity-50 shrink-0"
            >
              <RefreshCw
                size={14}
                className={isFetching ? "animate-spin" : "group-hover:rotate-180 transition-transform duration-500"}
              />
              REFRESH
            </button>

            <button
              onClick={() => setShowFilters(!showFilters)}
              className={clsx(
                "flex items-center justify-center gap-2 px-6 py-3 rounded-xl font-black uppercase text-[10px] tracking-widest transition-all border shadow-lg shrink-0",
                showFilters || hasFilters
                  ? "bg-[#F1C40F] border-[#F1C40F]/20 text-black shadow-[#F1C40F]/10 hover:bg-[#F4D03F]"
                  : "bg-white/[0.03] border-white/10 text-white hover:bg-white/[0.08]"
              )}
            >
              <Filter size={18} />
              {hasFilters && <span className="w-1.5 h-1.5 rounded-full bg-[#F1C40F]" />}
            </button>

            <GymSwitcher
              gyms={gyms}
              isLoading={gymsLoading}
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </div>
        }
      />

      {/* Filters */}
      {showFilters && (
        <div className="bg-[#121721] border border-white/5 rounded-[2.5rem] p-8 space-y-8 animate-in slide-in-from-top-4 duration-500 shadow-2xl relative overflow-hidden">
          <div className="absolute top-0 right-0 w-32 h-32 bg-white/[0.01] rounded-full -mr-16 -mt-16" />
          
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-8 relative z-10">
            {/* Action filter */}
            <div>
              <CustomSelect
                label="Action Type"
                value={actionFilter}
                onChange={(val) => { setActionFilter(val); setPage(1); }}
                placeholder="All actions"
                options={[
                  { value: "", label: "All actions" },
                  ...ACTION_CATEGORIES.flatMap(cat => 
                    cat.actions.map(a => ({ value: a, label: ACTION_META[a]?.label ?? a }))
                  )
                ]}
              />
            </div>
            {/* From */}
            <div>
              <ThemedDatePicker
                label="From Date"
                value={fromDate}
                onChange={(val) => { setFromDate(val); setPage(1); }}
              />
            </div>
            {/* To */}
            <div>
              <ThemedDatePicker
                label="To Date"
                value={toDate}
                onChange={(val) => { setToDate(val); setPage(1); }}
              />
            </div>
          </div>

          <div className="flex justify-end pt-4 border-t border-white/5 relative z-10">
            <button
              onClick={resetFilters}
              disabled={!hasFilters}
              className="flex items-center gap-2 px-6 py-3 bg-white/[0.03] text-zinc-500 hover:text-white rounded-xl font-black uppercase tracking-widest text-[10px] border border-white/10 disabled:opacity-30 transition-all"
            >
              <RefreshCw size={14} className={isFetching ? "animate-spin" : ""} />
              Clear Filters
            </button>
          </div>
        </div>
      )}

      {/* Log list */}
      <div className="bg-[#121721] border border-white/5 rounded-[2.5rem] overflow-hidden shadow-2xl relative">
        <div className="absolute top-0 right-0 w-64 h-64 bg-white/[0.01] rounded-full -mr-32 -mt-32 pointer-events-none" />
        
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-32 text-zinc-500 gap-4">
            <RefreshCw size={32} className="animate-spin text-[#F1C40F]" />
            <p className="font-black uppercase tracking-widest text-[10px]">Syncing logs...</p>
          </div>
        ) : logs.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-32 text-zinc-500">
            <div className="p-6 bg-white/[0.03] rounded-3xl border border-white/5 mb-6">
              <Shield size={48} className="text-zinc-800" />
            </div>
            <h3 className="text-xl font-black text-white uppercase tracking-tight">No events found</h3>
            <p className="text-zinc-500 mt-2 max-w-xs text-center font-medium text-sm">We couldn&apos;t find any audit logs matching your current filters.</p>
            {hasFilters && (
              <button onClick={resetFilters} className="mt-8 px-6 py-3 bg-[#F1C40F]/10 text-[#F1C40F] border border-[#F1C40F]/20 rounded-xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/20 transition-all">
                Clear all filters
              </button>
            )}
          </div>
        ) : (
          <div className="divide-y divide-white/5">
            {logs.map((log) => <LogRow key={log.id} log={log} />)}
          </div>
        )}
      </div>

      {/* Pagination */}
      {result && result.pages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-xs text-zinc-500">
            {result.total} event{result.total !== 1 ? "s" : ""} · page {result.page} of {result.pages}
          </p>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-1.5 rounded-lg text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            >
              <ChevronLeft size={16} />
            </button>
            {Array.from({ length: Math.min(result.pages, 7) }, (_, i) => {
              const p = i + 1;
              return (
                <button
                  key={p}
                  onClick={() => setPage(p)}
                  className={clsx(
                    "w-7 h-7 rounded-lg text-xs font-medium transition-colors",
                    p === page
                      ? "bg-[#F1C40F] !text-black"
                      : "text-zinc-400 hover:text-white hover:bg-zinc-800"
                  )}
                >
                  {p}
                </button>
              );
            })}
            <button
              onClick={() => setPage((p) => Math.min(result.pages, p + 1))}
              disabled={page === result.pages}
              className="p-1.5 rounded-lg text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
            >
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

/* eslint-disable @next/next/no-img-element */
"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import {
  supportApi,
  SupportTicket,
  TicketMessage,
  TicketStatus,
  TicketPriority,
  TicketStats,
} from "@/lib/api";
import {
  MessageSquare,
  Send,
  AlertTriangle,
  ChevronRight,
  ArrowLeft,
  Loader2,
} from "lucide-react";
import clsx from "clsx";

// ─── Config ───────────────────────────────────────────────────────────────────

const STATUS_CONFIG: Record<TicketStatus, { label: string; dot: string; bg: string; text: string }> = {
  OPEN:        { label: "Open",        dot: "bg-yellow-400",  bg: "bg-yellow-500/10", text: "text-yellow-400" },
  IN_PROGRESS: { label: "In Progress", dot: "bg-blue-400",    bg: "bg-blue-500/10",   text: "text-blue-400" },
  RESOLVED:    { label: "Resolved",    dot: "bg-green-400",   bg: "bg-green-500/10",  text: "text-green-400" },
  CLOSED:      { label: "Closed",      dot: "bg-zinc-500",    bg: "bg-zinc-700/50",   text: "text-zinc-500" },
};

const PRIORITY_CONFIG: Record<TicketPriority, { label: string; text: string; border: string }> = {
  LOW:    { label: "Low",    text: "text-zinc-400",  border: "border-zinc-700" },
  MEDIUM: { label: "Medium", text: "text-blue-400",  border: "border-blue-500/30" },
  HIGH:   { label: "High",   text: "text-orange-400",border: "border-orange-500/30" },
  URGENT: { label: "Urgent", text: "text-red-400",   border: "border-red-500/40" },
};

const STATUS_ORDER: TicketStatus[] = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"];

const fmtTime = (iso: string) =>
  new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });

// ─── Ticket Thread View ───────────────────────────────────────────────────────

function TicketThread({
  ticket,
  gymId,
  token,
  onBack,
}: {
  ticket: SupportTicket;
  gymId: string;
  token: string;
  onBack: () => void;
}) {
  const queryClient = useQueryClient();
  const [reply, setReply] = useState("");

  const { data, isLoading } = useQuery({
    queryKey: ["ticket-thread", ticket.id],
    queryFn: () => supportApi.getTicket(gymId, ticket.id, token),
    refetchInterval: 10000,
  });

  const full: SupportTicket | null = (data as unknown as SupportTicket) ?? null;
  const messages: TicketMessage[] = full?.messages ?? [];

  const replyMutation = useMutation({
    mutationFn: (body: string) => supportApi.reply(gymId, ticket.id, body, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["ticket-thread", ticket.id] });
      queryClient.invalidateQueries({ queryKey: ["support-tickets", gymId] });
      setReply("");
    },
  });

  const statusMutation = useMutation({
    mutationFn: (status: TicketStatus) => supportApi.updateStatus(gymId, ticket.id, status, token),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["ticket-thread", ticket.id] });
      queryClient.invalidateQueries({ queryKey: ["support-tickets", gymId] });
    },
  });

  const priorityCfg = PRIORITY_CONFIG[ticket.priority];
  const isOpen = full?.status !== "CLOSED" && full?.status !== "RESOLVED";

  return (
    <div className="flex flex-col h-full max-h-[calc(100vh-160px)]">
      {/* Thread header */}
      <div className="flex items-start gap-3 mb-5">
        <button
          onClick={onBack}
          className="p-1.5 rounded-lg hover:bg-zinc-800 transition-colors text-zinc-400 hover:text-white shrink-0 mt-0.5"
        >
          <ArrowLeft size={16} />
        </button>
        <div className="flex-1 min-w-0">
          <h2 className="text-base font-bold text-white leading-tight">{ticket.subject}</h2>
          <div className="flex items-center gap-2 mt-1 flex-wrap">
            <span className="text-xs text-zinc-500">{ticket.user.fullName}</span>
            <span className="text-zinc-700">·</span>
            <span className="text-xs text-zinc-500">{fmtTime(ticket.createdAt)}</span>
            <span className={clsx("text-[10px] font-bold border px-1.5 py-0.5 rounded", priorityCfg.text, priorityCfg.border)}>
              {priorityCfg.label}
            </span>
          </div>
        </div>

        {/* Status changer */}
        <div className="flex gap-1.5 shrink-0">
          {STATUS_ORDER.filter((s) => s !== (full?.status ?? ticket.status)).map((s) => {
            const cfg = STATUS_CONFIG[s];
            return (
              <button
                key={s}
                onClick={() => statusMutation.mutate(s)}
                disabled={statusMutation.isPending}
                className={clsx(
                  "text-[10px] font-black uppercase tracking-wider px-2.5 py-1.5 rounded-lg border transition-colors",
                  cfg.bg, cfg.text, "border-transparent hover:opacity-80"
                )}
              >
                {cfg.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto space-y-4 pr-1 min-h-0 amirani-scrollbar p-1">
        {isLoading ? (
          <div className="text-center text-zinc-500 text-sm py-12 flex flex-col items-center gap-4">
             <Loader2 className="animate-spin text-[#F1C40F]" size={24} />
             <p className="font-bold uppercase tracking-widest text-[10px]">Loading thread...</p>
          </div>
        ) : (
          messages.map((msg) => (
            <div
              key={msg.id}
              className={clsx(
                "flex gap-4",
                msg.isStaff ? "flex-row-reverse" : "flex-row"
              )}
            >
              <div className="w-10 h-10 rounded-2xl bg-white/[0.03] border border-white/10 flex items-center justify-center shrink-0 shadow-lg shadow-black/20 overflow-hidden">
                {msg.sender.avatarUrl ? (
                  <img src={msg.sender.avatarUrl} className="w-full h-full object-cover" alt="" />
                ) : (
                  <span className="text-xs font-black text-zinc-400 uppercase">{msg.sender.fullName.charAt(0)}</span>
                )}
              </div>
              <div className={clsx("max-w-[75%]", msg.isStaff ? "items-end" : "items-start", "flex flex-col gap-2")}>
                <div
                  className={clsx(
                    "rounded-[1.5rem] px-5 py-4 text-sm leading-relaxed font-medium shadow-xl relative group transition-all",
                    msg.isStaff
                      ? "bg-[#F1C40F] !text-black rounded-tr-sm"
                      : "bg-[#121721] text-zinc-300 border border-white/5 rounded-tl-sm hover:border-white/10"
                  )}
                >
                  {msg.body}
                </div>
                <p className="text-[10px] font-black text-zinc-600 uppercase tracking-widest px-1">
                  {msg.isStaff ? <span className="text-[#F1C40F]">Gym Staff</span> : msg.sender.fullName} · {fmtTime(msg.createdAt)}
                </p>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Reply box */}
      {isOpen && (
        <div className="mt-4 pt-4 border-t border-zinc-800">
          <div className="flex gap-2">
            <textarea
              value={reply}
              onChange={(e) => setReply(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && (e.metaKey || e.ctrlKey) && reply.trim()) {
                  replyMutation.mutate(reply.trim());
                }
              }}
              rows={2}
              placeholder="Reply as staff... (Ctrl+Enter to send)"
              className="flex-1 bg-zinc-800 border border-zinc-700 rounded-xl px-3 py-2.5 text-sm text-white placeholder-zinc-500 focus:outline-none focus:border-[#F1C40F] resize-none"
            />
            <button
              onClick={() => reply.trim() && replyMutation.mutate(reply.trim())}
              disabled={!reply.trim() || replyMutation.isPending}
              className="px-3 py-2.5 rounded-xl bg-[#F1C40F] !text-black hover:bg-[#F1C40F]/90 disabled:opacity-40 transition-colors shrink-0"
            >
              <Send size={16} />
            </button>
          </div>
        </div>
      )}
      {!isOpen && (
        <div className="mt-4 pt-4 border-t border-zinc-800 text-center text-xs text-zinc-500">
          Ticket is {STATUS_CONFIG[full?.status ?? ticket.status].label.toLowerCase()} — reopen to reply
        </div>
      )}
    </div>
  );
}

// ─── Ticket Row ───────────────────────────────────────────────────────────────

function TicketRow({ ticket, onClick }: { ticket: SupportTicket; onClick: () => void }) {
  const statusCfg   = STATUS_CONFIG[ticket.status];
  const priorityCfg = PRIORITY_CONFIG[ticket.priority];
  const unread = ticket._count?.messages ?? 0;

  return (
    <button
      onClick={onClick}
      className="group relative overflow-hidden w-full flex items-center gap-6 px-6 py-5 bg-[#121721] border border-white/5 rounded-3xl hover:border-white/10 transition-all text-left shadow-xl"
    >
      <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
      
      <div className={clsx("relative z-10 w-2.5 h-2.5 rounded-full shrink-0 shadow-[0_0_10px_rgba(0,0,0,0.5)]", statusCfg.dot)} />

      <div className="flex-1 min-w-0 relative z-10">
        <div className="flex items-center gap-3 mb-1">
          <p className="text-lg font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors truncate">
            {ticket.subject}
          </p>
          {ticket.priority === "URGENT" && (
            <AlertTriangle size={14} className="text-red-400 shrink-0 animate-pulse" />
          )}
        </div>
        <p className="text-xs text-zinc-500 font-medium flex items-center gap-2">
          <span className="text-white font-bold">{ticket.user.fullName}</span>
          <span className="w-1 h-1 rounded-full bg-zinc-700" />
          {fmtTime(ticket.createdAt)}
        </p>
      </div>

      <div className="flex items-center gap-3 shrink-0 relative z-10">
        <span className={clsx("text-[10px] font-black uppercase tracking-[0.1em] px-2.5 py-1 rounded-md border border-white/5 shadow-sm", statusCfg.bg, statusCfg.text)}>
          {statusCfg.label}
        </span>
        <span className={clsx("text-[10px] font-black uppercase tracking-[0.1em] border px-2 py-1 rounded-md", priorityCfg.text, priorityCfg.border, "bg-white/[0.03]")}>
          {priorityCfg.label}
        </span>
        {unread > 0 && (
          <span className="bg-[#F1C40F] !text-black text-[10px] font-black px-2 py-1 rounded-md shadow-lg shadow-[#F1C40F]/10">
            {unread}
          </span>
        )}
        <div className="p-2 bg-white/[0.03] rounded-xl border border-white/5 text-zinc-600 group-hover:text-white group-hover:bg-white/[0.08] transition-all ml-1">
          <ChevronRight size={16} />
        </div>
      </div>
    </button>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function SupportPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const { token } = useAuthStore();
  const queryClient = useQueryClient();
  const gymId = selectedGymId as string;

  const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null);
  const [statusFilter, setStatusFilter] = useState<string>("");

  const { data: statsData, error: statsError } = useQuery({
    queryKey: ["support-stats", gymId],
    queryFn: () => supportApi.getStats(gymId, token!),
    enabled: !!token && !!gymId,
    refetchInterval: 30000,
  });
  const stats = statsData as unknown as TicketStats;

  const { data, isLoading, error } = useQuery({
    queryKey: ["support-tickets", gymId, statusFilter],
    queryFn: () => supportApi.list(gymId, { status: statusFilter || undefined }, token!),
    enabled: !!token && !!gymId,
    refetchInterval: 15000,
  });
  const tickets: SupportTicket[] = (data as unknown as SupportTicket[]) ?? [];

  if (error) {
    return (
      <div className="text-center py-20 bg-red-500/10 border border-red-500/20 rounded-2xl">
        <AlertTriangle size={32} className="text-red-500 mx-auto mb-3" />
        <p className="text-red-400 font-medium tracking-tight">Failed to load support tickets</p>
        <p className="text-red-500/60 text-xs mt-1">{(error as Error).message}</p>
        <button 
          onClick={() => queryClient.invalidateQueries({ queryKey: ["support-tickets"] })}
          className="mt-4 px-4 py-2 bg-red-500 text-white rounded-lg text-xs font-bold hover:bg-red-600 transition-colors"
        >
          Try Again
        </button>
      </div>
    );
  }

  if (selectedTicket) {
    return (
      <div className="">
        <TicketThread
          ticket={selectedTicket}
          gymId={gymId}
          token={token!}
          onBack={() => setSelectedTicket(null)}
        />
      </div>
    );
  }

  const filterTabs = [
    { label: "All",         value: "",            count: stats?.total ?? 0 },
    { label: "Open",        value: "OPEN",        count: stats?.open ?? 0 },
    { label: "In Progress", value: "IN_PROGRESS", count: stats?.inProgress ?? 0 },
    { label: "Resolved",    value: "RESOLVED",    count: stats?.resolved ?? 0 },
    { label: "Closed",      value: "CLOSED",      count: stats?.closed ?? 0 },
  ];

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="Support Tickets"
        description="Member support requests. Reply directly from here."
        icon={<MessageSquare size={32} />}
        actions={
          <GymSwitcher 
            gyms={gyms} 
            isLoading={gymsLoading} 
            disabled={userRole === "BRANCH_ADMIN"}
          />
        }
      />

      {statsError && (
        <div className="p-3 bg-red-500/10 border border-red-500/20 rounded-xl flex items-center gap-3">
          <AlertTriangle size={16} className="text-red-500 shrink-0" />
          <p className="text-xs text-red-400">Failed to load statistics: {(statsError as Error).message}</p>
        </div>
      )}

      {/* Stats row */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
          {[
            { label: "Open",        value: stats.open,       color: "text-yellow-400" },
            { label: "In Progress", value: stats.inProgress, color: "text-blue-400" },
            { label: "Resolved",    value: stats.resolved,   color: "text-green-400" },
            { label: "Urgent",      value: stats.urgent,     color: "text-red-400" },
          ].map((s) => (
            <div key={s.label} className="bg-[#121721] border border-white/5 rounded-3xl p-6 shadow-xl relative overflow-hidden group">
              <div className="absolute top-0 right-0 w-32 h-32 bg-white/[0.02] rounded-full -mr-16 -mt-16 transition-transform group-hover:scale-110" />
              <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2">{s.label}</p>
              <p className={clsx("text-4xl font-black tracking-tighter italic", s.color)}>{s.value}</p>
            </div>
          ))}
        </div>
      )}

      {/* Filter tabs */}
      <div className="flex gap-1 bg-zinc-900 border border-zinc-800 rounded-xl p-1">
        {filterTabs.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={clsx(
              "flex-1 flex items-center justify-center gap-1.5 px-2 py-1.5 rounded-lg text-xs font-bold transition-colors",
              statusFilter === tab.value
                ? "bg-zinc-700 text-white"
                : "text-zinc-500 hover:text-zinc-300"
            )}
          >
            {tab.label}
            {tab.count > 0 && (
              <span className={clsx(
                "text-[10px] font-black px-1 py-0.5 rounded",
                statusFilter === tab.value ? "bg-zinc-600 text-zinc-300" : "bg-zinc-800 text-zinc-500"
              )}>
                {tab.count}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Ticket list */}
      {isLoading ? (
        <div className="space-y-2">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="bg-zinc-900 border border-zinc-800 rounded-xl h-16 animate-pulse" />
          ))}
        </div>
      ) : tickets.length === 0 ? (
        <div className="text-center py-20 bg-zinc-900 border border-zinc-800 border-dashed rounded-2xl">
          <MessageSquare size={32} className="text-zinc-700 mx-auto mb-3" />
          <p className="text-zinc-400 font-medium">No tickets</p>
          <p className="text-zinc-600 text-sm mt-1">
            {statusFilter ? `No ${STATUS_CONFIG[statusFilter as TicketStatus]?.label.toLowerCase()} tickets` : "Members haven't submitted any support requests yet."}
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {tickets.map((t) => (
            <TicketRow key={t.id} ticket={t} onClick={() => setSelectedTicket(t)} />
          ))}
        </div>
      )}
    </div>
  );
}

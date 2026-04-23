"use client";

import { useState } from "react";
import Image from "next/image";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import { ThemedDateTimePicker } from "@/components/ui/ThemedDateTimePicker";
import { CustomSelect } from "@/components/ui/Select";
import {
  sessionsApi,
  TrainingSession,
  SessionBooking,
  TrainerStats,
  CreateSessionData,
  SessionType,
  SessionStatus,
  BookingStatus,
} from "@/lib/api";
import {
  Calendar,
  Plus,
  Users,
  Clock,
  MapPin,
  Edit2,
  Trash2,
  XCircle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  BarChart3,
  X,
  UserCheck,
  UserX,
  Loader2,
} from "lucide-react";
import clsx from "clsx";

// ─── Constants ────────────────────────────────────────────────────────────────

const SESSION_TYPES: { value: SessionType; label: string; color: string }[] = [
  { value: "GROUP_CLASS", label: "Group Class", color: "#F1C40F" },
  { value: "ONE_ON_ONE",  label: "1-on-1",      color: "#3b82f6" },
  { value: "WORKSHOP",    label: "Workshop",    color: "#10b981" },
];

const STATUS_STYLES: Record<SessionStatus, { bg: string; text: string; label: string }> = {
  SCHEDULED:  { bg: "bg-green-500/10",  text: "text-green-400",  label: "Scheduled" },
  CANCELLED:  { bg: "bg-red-500/10",    text: "text-red-400",    label: "Cancelled" },
  COMPLETED:  { bg: "bg-zinc-700",      text: "text-zinc-400",   label: "Completed" },
};

const BOOKING_STATUS_STYLES: Record<BookingStatus, { text: string; label: string }> = {
  CONFIRMED: { text: "text-green-400",  label: "Confirmed" },
  ATTENDED:  { text: "text-blue-400",   label: "Attended" },
  CANCELLED: { text: "text-red-400",    label: "Cancelled" },
  NO_SHOW:   { text: "text-zinc-500",   label: "No Show" },
};

const fmt = (iso: string) =>
  new Date(iso).toLocaleString("en-US", {
    weekday: "short", month: "short", day: "numeric",
    hour: "2-digit", minute: "2-digit",
  });

const fmtTime = (iso: string) =>
  new Date(iso).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" });

const fmtDate = (iso: string) =>
  new Date(iso).toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });

function durMin(start: string, end: string) {
  return Math.round((new Date(end).getTime() - new Date(start).getTime()) / 60000);
}

// ─── Trainer Stats Panel ──────────────────────────────────────────────────────

function TrainerStatsPanel({ gymId, token }: { gymId: string; token: string }) {
  const { data } = useQuery({
    queryKey: ["trainer-stats", gymId],
    queryFn: () => sessionsApi.getTrainerStats(gymId, token),
  });
  const stats: TrainerStats[] = data?.data ?? [];

  if (stats.length === 0) return null;

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5">
      <p className="text-xs font-black uppercase tracking-[0.15em] text-zinc-500 mb-4">Trainer Utilization</p>
      <div className="space-y-3">
        {stats.map((t) => (
          <div key={t.id} className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-zinc-700 flex items-center justify-center shrink-0">
              {t.avatarUrl
                ? <Image src={t.avatarUrl} width={32} height={32} className="w-8 h-8 rounded-full object-cover" alt={t.fullName} />
                : <span className="text-xs font-bold text-zinc-300">{t.fullName.charAt(0)}</span>
              }
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-white truncate">{t.fullName}</p>
              <p className="text-[11px] text-zinc-500">{t.specialization ?? "General"}</p>
            </div>
            <div className="text-right shrink-0">
              <p className="text-sm font-bold text-white">{t.totalBookings}</p>
              <p className="text-[10px] text-zinc-500">bookings</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Bookings Sheet ───────────────────────────────────────────────────────────

function BookingsSheet({
  session,
  gymId,
  token,
  onClose,
}: {
  session: TrainingSession;
  gymId: string;
  token: string;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();

  const { data, isLoading } = useQuery({
    queryKey: ["session-bookings", session.id],
    queryFn: () => sessionsApi.getBookings(gymId, session.id, token),
  });
  const bookings: SessionBooking[] = data?.data ?? [];

  const attendMutation = useMutation({
    mutationFn: ({ memberId, status }: { memberId: string; status: BookingStatus }) =>
      sessionsApi.markAttendance(gymId, session.id, memberId, status, token),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["session-bookings", session.id] }),
  });

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl w-full max-w-lg max-h-[85vh] flex flex-col">
        <div className="p-5 border-b border-zinc-800 flex items-start justify-between gap-3">
          <div>
            <h2 className="text-base font-bold text-white">{session.title}</h2>
            <p className="text-xs text-zinc-500 mt-0.5">{fmt(session.startTime)} · {durMin(session.startTime, session.endTime)}min</p>
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs text-zinc-400 bg-zinc-800 px-2 py-1 rounded-lg">
              {session.bookingCount} / {session.maxCapacity} booked
            </span>
            <button onClick={onClose} className="p-1.5 rounded-lg hover:bg-zinc-800 transition-colors">
              <X size={16} className="text-zinc-400" />
            </button>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {isLoading ? (
            <p className="text-center text-zinc-500 text-sm py-8">Loading...</p>
          ) : bookings.length === 0 ? (
            <p className="text-center text-zinc-500 text-sm py-8">No bookings yet.</p>
          ) : (
            <div className="space-y-1">
              {bookings.map((b) => (
                <div key={b.id} className="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-zinc-800/50 transition-colors">
                  <div className="w-8 h-8 rounded-full bg-zinc-700 flex items-center justify-center shrink-0">
                    {b.user.avatarUrl
                      ? <Image src={b.user.avatarUrl} width={32} height={32} className="w-8 h-8 rounded-full object-cover" alt={b.user.fullName} />
                      : <span className="text-xs font-bold text-zinc-300">{b.user.fullName.charAt(0)}</span>
                    }
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-white truncate">{b.user.fullName}</p>
                    <p className={clsx("text-xs font-medium", BOOKING_STATUS_STYLES[b.status].text)}>
                      {BOOKING_STATUS_STYLES[b.status].label}
                    </p>
                  </div>
                  {b.status === "CONFIRMED" && (
                    <div className="flex gap-1">
                      <button
                        onClick={() => attendMutation.mutate({ memberId: b.userId, status: "ATTENDED" })}
                        title="Mark attended"
                        className="p-1.5 rounded-lg text-zinc-400 hover:text-green-400 hover:bg-green-500/10 transition-colors"
                      >
                        <UserCheck size={14} />
                      </button>
                      <button
                        onClick={() => attendMutation.mutate({ memberId: b.userId, status: "NO_SHOW" })}
                        title="Mark no-show"
                        className="p-1.5 rounded-lg text-zinc-400 hover:text-zinc-300 hover:bg-zinc-700 transition-colors"
                      >
                        <UserX size={14} />
                      </button>
                    </div>
                  )}
                  {b.status === "ATTENDED" && <CheckCircle2 size={16} className="text-green-400 shrink-0" />}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Session Form Modal ───────────────────────────────────────────────────────

function SessionModal({
  gymId,
  token,
  session,
  onClose,
  onSave,
  loading,
}: {
  gymId: string;
  token: string;
  session: TrainingSession | null;
  onClose: () => void;
  onSave: (data: CreateSessionData) => void;
  loading: boolean;
}) {
  const { data: trainersData } = useQuery({
    queryKey: ["trainer-stats", gymId],
    queryFn: () => sessionsApi.getTrainerStats(gymId, token),
  });
  const trainers: TrainerStats[] = trainersData?.data ?? [];

  const toLocal = (iso?: string) => {
    if (!iso) return "";
    const d = new Date(iso);
    const pad = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };

  const [form, setForm] = useState<CreateSessionData>({
    trainerId: session?.trainerId ?? (trainers[0]?.id ?? ""),
    title: session?.title ?? "",
    description: session?.description ?? "",
    type: session?.type ?? "GROUP_CLASS",
    startTime: toLocal(session?.startTime),
    endTime: toLocal(session?.endTime),
    maxCapacity: session?.maxCapacity ?? 20,
    location: session?.location ?? "",
    color: session?.color ?? "",
  });

  const isValid = form.trainerId && form.title.trim() && form.startTime && form.endTime;

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-xl flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
      <div className="bg-[#121721] border border-white/5 rounded-[2.5rem] w-full max-w-lg max-h-[90vh] overflow-y-auto amirani-scrollbar shadow-2xl relative overflow-hidden group">
        <div className="absolute top-0 right-0 w-32 h-32 bg-white/[0.02] rounded-full -mr-16 -mt-16 transition-transform group-hover:scale-110" />
        
        <div className="p-8 border-b border-white/5 flex items-center justify-between relative z-10">
          <h2 className="text-2xl font-black text-white uppercase tracking-tighter italic">
            {session ? "Edit Session" : "Schedule Session"}
          </h2>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-white/5 transition-all text-zinc-500 hover:text-white border border-transparent hover:border-white/10">
            <X size={20} />
          </button>
        </div>

        <div className="p-8 space-y-8 relative z-10">
          {/* Type */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-3 px-1">Session Type *</label>
            <div className="grid grid-cols-3 gap-3">
              {SESSION_TYPES.map((t) => {
                const active = form.type === t.value;
                return (
                  <button
                    key={t.value}
                    type="button"
                    onClick={() => setForm((f) => ({ ...f, type: t.value }))}
                    className={clsx(
                      "flex flex-col items-center gap-2 py-4 rounded-2xl border transition-all font-bold text-sm",
                      active
                        ? "border-transparent text-black"
                        : "bg-white/[0.03] text-zinc-500 border-white/5 hover:border-white/20"
                    )}
                    style={active ? { backgroundColor: t.color } : {}}
                  >
                    <span className="text-[10px] uppercase tracking-widest font-black">{t.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Title */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Session Title *</label>
            <input
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              placeholder="e.g. Morning HIIT, Yoga Flow"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all shadow-sm"
            />
          </div>

            <CustomSelect
              label="Trainer *"
              value={form.trainerId}
              onChange={(val) => setForm((f) => ({ ...f, trainerId: val }))}
              placeholder="Select trainer..."
              options={trainers.map(t => ({ value: t.id, label: t.fullName }))}
            />

          {/* Start / End */}
          <div className="space-y-6">
            <ThemedDateTimePicker
              label="Start Date & Time *"
              value={form.startTime}
              onChange={(val) => setForm((f) => ({ ...f, startTime: val }))}
            />
            <ThemedDateTimePicker
              label="End Date & Time *"
              value={form.endTime}
              onChange={(val) => setForm((f) => ({ ...f, endTime: val }))}
            />
          </div>

          {/* Capacity & Location */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Max Capacity</label>
              <input
                type="number"
                min={1}
                max={200}
                value={form.maxCapacity}
                onChange={(e) => setForm((f) => ({ ...f, maxCapacity: Number(e.target.value) }))}
                className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all font-bold"
              />
            </div>
            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Location</label>
              <input
                value={form.location ?? ""}
                onChange={(e) => setForm((f) => ({ ...f, location: e.target.value }))}
                placeholder="e.g. Studio A"
                className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
              />
            </div>
          </div>

          {/* Description */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">
              Description <span className="text-zinc-600 font-normal">(optional)</span>
            </label>
            <textarea
              value={form.description ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              rows={2}
              placeholder="Brief description for members..."
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all resize-none shadow-sm"
            />
          </div>
        </div>

        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex justify-end gap-3 shrink-0 relative z-10">
          <button onClick={onClose} disabled={loading} className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-all">
            Cancel
          </button>
          <button
            onClick={() => isValid && onSave(form)}
            disabled={!isValid || loading}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-40 disabled:cursor-not-allowed transition-all shadow-lg shadow-[#F1C40F]/5"
          >
            {loading ? <Loader2 className="animate-spin" size={14} /> : (session ? "Save Changes" : "Schedule Now")}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Session Card ─────────────────────────────────────────────────────────────

function SessionCard({
  session,
  onEdit,
  onCancel,
  onDelete,
  onViewBookings,
}: {
  session: TrainingSession;
  onEdit: () => void;
  onCancel: () => void;
  onDelete: () => void;
  onViewBookings: () => void;
}) {
  const typeInfo = SESSION_TYPES.find((t) => t.value === session.type)!;
  const statusStyle = STATUS_STYLES[session.status];
  const fillPct = session.maxCapacity > 0 ? (session.bookingCount / session.maxCapacity) * 100 : 0;
  const isFull = session.availableSpots === 0;

  return (
    <div className={clsx(
      "bg-[#121721] border border-white/5 rounded-3xl p-6 space-y-4 hover:border-white/10 transition-all group overflow-hidden relative shadow-xl",
      session.status === "CANCELLED" ? "opacity-60 grayscale-[0.5]" : ""
    )}>
      <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
      
      {/* Top row */}
      <div className="flex items-start justify-between gap-3 relative z-10">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-2">
            <span
              className="text-[10px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-md text-black"
              style={{ backgroundColor: typeInfo.color }}
            >
              {typeInfo.label}
            </span>
            <span className={clsx("text-[10px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-md border", statusStyle.bg, statusStyle.text, "border-white/5")}>
              {statusStyle.label}
            </span>
            {isFull && session.status === "SCHEDULED" && (
              <span className="text-[10px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-md bg-orange-500/10 text-orange-400 border border-orange-500/10">Full</span>
            )}
          </div>
          <p className="text-xl font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors line-clamp-2">{session.title}</p>
          <p className="text-xs text-zinc-500 mt-2 font-medium flex items-center gap-2">
             <div className="w-5 h-5 rounded-full bg-white/[0.03] border border-white/5 flex items-center justify-center text-[10px] uppercase font-black text-zinc-600">
               {session.trainer.fullName.charAt(0)}
             </div>
             {session.trainer.fullName}
          </p>
        </div>

        {session.status === "SCHEDULED" && (
          <div className="flex items-center gap-1.5 shrink-0">
            <button onClick={onViewBookings} title="View bookings"
              className="p-3 bg-white/[0.03] text-zinc-500 hover:text-white hover:bg-white/[0.08] rounded-2xl transition-all border border-white/5">
              <Users size={16} />
            </button>
            <button onClick={onEdit}
              className="p-3 bg-white/[0.03] text-zinc-500 hover:text-[#F1C40F] hover:bg-white/[0.08] rounded-2xl transition-all border border-white/5">
              <Edit2 size={16} />
            </button>
            <button onClick={onCancel} title="Cancel session"
              className="p-3 bg-white/[0.03] text-zinc-500 hover:text-red-400 hover:bg-red-500/10 rounded-2xl transition-all border border-white/5">
              <XCircle size={16} />
            </button>
          </div>
        )}
        {session.status !== "SCHEDULED" && (
          <button onClick={onDelete}
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-red-400 hover:bg-red-500/10 rounded-2xl transition-all border border-white/5">
            <Trash2 size={16} />
          </button>
        )}
      </div>

      {/* Time & location */}
      <div className="flex items-center gap-6 text-xs text-zinc-400 font-bold relative z-10 py-1">
        <span className="flex items-center gap-2">
          <div className="p-1.5 bg-white/5 rounded-lg text-[#F1C40F]"><Clock size={14} /></div>
          {fmtTime(session.startTime)} – {fmtTime(session.endTime)}
          <span className="text-zinc-600">({durMin(session.startTime, session.endTime)}min)</span>
        </span>
        {session.location && (
          <span className="flex items-center gap-2">
            <div className="p-1.5 bg-white/5 rounded-lg text-[#F1C40F]"><MapPin size={14} /></div>
            {session.location}
          </span>
        )}
      </div>

      {/* Capacity bar */}
      <div className="space-y-2 pt-2 relative z-10">
        <div className="flex justify-between text-[10px] font-black uppercase tracking-[0.15em] text-zinc-600">
          <span className="flex items-center gap-1.5"><Users size={12} /> {session.bookingCount} / {session.maxCapacity} booked</span>
          {session.attendedCount > 0 && (
            <span className="flex items-center gap-1.5 text-green-400/80"><CheckCircle2 size={12} /> {session.attendedCount} attended</span>
          )}
        </div>
        <div className="w-full bg-white/[0.03] h-2 rounded-full overflow-hidden border border-white/5">
          <div
            className={clsx("h-full transition-all duration-700", fillPct >= 90 ? "bg-orange-500" : "bg-[#F1C40F]")}
            style={{ width: `${Math.min(100, fillPct)}%` }}
          />
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function SessionsPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const { token } = useAuthStore();
  const queryClient = useQueryClient();
  const gymId = selectedGymId as string;

  // Week navigation
  const [weekOffset, setWeekOffset] = useState(0);
  const [editingSession, setEditingSession] = useState<TrainingSession | null | undefined>(undefined);
  const [viewingBookings, setViewingBookings] = useState<TrainingSession | null>(null);
  const [showStats, setShowStats] = useState(false);

  const weekStart = new Date();
  weekStart.setDate(weekStart.getDate() + weekOffset * 7 - weekStart.getDay() + 1); // Monday
  weekStart.setHours(0, 0, 0, 0);
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekEnd.getDate() + 6);
  weekEnd.setHours(23, 59, 59, 999);

  const { data, isLoading } = useQuery({
    queryKey: ["sessions", gymId, weekOffset],
    queryFn: () => sessionsApi.list(gymId, {
      from: weekStart.toISOString(),
      to: weekEnd.toISOString(),
    }, token!),
    enabled: !!token,
  });

  const sessions: TrainingSession[] = data?.data ?? [];

  const createMutation = useMutation({
    mutationFn: (d: CreateSessionData) => sessionsApi.create(gymId, d, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["sessions", gymId] });
      queryClient.invalidateQueries({ queryKey: ["trainer-stats", gymId] });
      setEditingSession(undefined);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data: updateData }: { id: string; data: Partial<CreateSessionData> & { status?: SessionStatus } }) => sessionsApi.update(gymId, id, updateData, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["sessions", gymId] });
      setEditingSession(undefined);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => sessionsApi.delete(gymId, id, token!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["sessions", gymId] }),
  });

  const handleSave = (formData: CreateSessionData) => {
    if (editingSession) {
      updateMutation.mutate({ id: editingSession.id, data: formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  // Group by date
  const grouped = sessions.reduce((acc, s) => {
    const day = fmtDate(s.startTime);
    if (!acc[day]) acc[day] = [];
    acc[day].push(s);
    return acc;
  }, {} as Record<string, TrainingSession[]>);

  const weekLabel = `${weekStart.toLocaleDateString("en-US", { month: "short", day: "numeric" })} – ${weekEnd.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}`;
  const totalBookings = sessions.reduce((s, x) => s + x.bookingCount, 0);
  const scheduledCount = sessions.filter((s) => s.status === "SCHEDULED").length;

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="Sessions"
        description="Schedule classes, 1-on-1 sessions, and workshops for your members."
        icon={<Calendar size={32} />}
        actions={
          <>
            <button
              onClick={() => setShowStats(!showStats)}
              className={clsx(
                "p-4 rounded-2xl border transition-all duration-300",
                showStats 
                  ? "bg-[#F1C40F]/20 border-[#F1C40F]/50 text-[#F1C40F] shadow-lg shadow-[#F1C40F]/5" 
                  : "bg-white/[0.03] border-white/10 text-zinc-400 hover:text-white hover:border-white/20"
              )}
            >
              <BarChart3 size={20} />
            </button>
            
            <button
              onClick={() => setEditingSession(null)}
              className="amirani-input !w-auto !px-6 !py-4 !bg-[#F1C40F] !text-black font-bold flex items-center gap-2 shadow-lg shadow-[#F1C40F]/10 hover:!bg-[#F1C40F]/90 transition-all rounded-2xl"
            >
              <Plus size={20} />
              <span className="text-[11px] uppercase tracking-widest font-black">Schedule</span>
            </button>

            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </>
        }
      />

      {/* Stats panel */}
      {showStats && <TrainerStatsPanel gymId={gymId} token={token!} />}

      {/* Week nav + stats */}
      <div className="flex items-center justify-between gap-4 bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-3">
        <div className="flex items-center gap-2">
          <button onClick={() => setWeekOffset((w) => w - 1)}
            className="p-1.5 rounded-lg hover:bg-zinc-800 transition-colors text-zinc-400 hover:text-white">
            <ChevronLeft size={16} />
          </button>
          <p className="text-sm font-semibold text-white min-w-[200px] text-center">{weekLabel}</p>
          <button onClick={() => setWeekOffset((w) => w + 1)}
            className="p-1.5 rounded-lg hover:bg-zinc-800 transition-colors text-zinc-400 hover:text-white">
            <ChevronRight size={16} />
          </button>
        </div>
        <div className="flex items-center gap-4 text-xs text-zinc-500">
          <span className="flex items-center gap-1.5"><Calendar size={11} /> {scheduledCount} sessions</span>
          <span className="flex items-center gap-1.5"><Users size={11} /> {totalBookings} bookings</span>
          {weekOffset !== 0 && (
            <button onClick={() => setWeekOffset(0)} className="text-[#F1C40F] hover:underline text-xs">Today</button>
          )}
        </div>
      </div>

      {/* Sessions list */}
      {isLoading ? (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="bg-zinc-900 border border-zinc-800 rounded-xl h-28 animate-pulse" />
          ))}
        </div>
      ) : Object.keys(grouped).length === 0 ? (
        <div className="flex flex-col items-center justify-center text-center py-20 bg-zinc-900 border border-zinc-800 border-dashed rounded-2xl">
          <Calendar size={32} className="text-zinc-700 mb-3" />
          <p className="text-zinc-400 font-medium italic uppercase tracking-widest text-xs">No sessions this week</p>
          <p className="text-zinc-600 text-[10px] mt-1 uppercase tracking-wider">Schedule a class or 1-on-1 session for your members.</p>
          <button
            onClick={() => setEditingSession(null)}
            className="mt-8 flex items-center justify-center gap-2 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
          >
            <Plus size={18} />
            Schedule New Session
          </button>
        </div>
      ) : (
        <div className="space-y-5">
          {Object.entries(grouped).map(([day, daySessions]) => (
            <div key={day}>
              <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2 px-1">{day}</p>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {daySessions.map((s) => (
                  <SessionCard
                    key={s.id}
                    session={s}
                    onEdit={() => setEditingSession(s)}
                    onCancel={() => updateMutation.mutate({ id: s.id, data: { status: "CANCELLED" } })}
                    onDelete={() => { if (confirm(`Delete "${s.title}"?`)) deleteMutation.mutate(s.id); }}
                    onViewBookings={() => setViewingBookings(s)}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Modals */}
      {editingSession !== undefined && (
        <SessionModal
          gymId={gymId}
          token={token!}
          session={editingSession}
          onClose={() => setEditingSession(undefined)}
          onSave={handleSave}
          loading={createMutation.isPending || updateMutation.isPending}
        />
      )}
      {viewingBookings && (
        <BookingsSheet
          session={viewingBookings}
          gymId={gymId}
          token={token!}
          onClose={() => setViewingBookings(null)}
        />
      )}
    </div>
  );
}

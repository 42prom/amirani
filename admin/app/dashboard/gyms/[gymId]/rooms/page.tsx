"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import { PageHeader } from "@/components/ui/PageHeader";
import { roomsAdminApi, ProgressRoom, RoomMetric, RoomPeriod } from "@/lib/api";
import {
  Trophy,
  Plus,
  Trash2,
  Users,
  Lock,
  Globe,
  RefreshCw,
  Copy,
  Check,
  BarChart3,
  Zap,
  TrendingUp,
  X,
  Loader2,
} from "lucide-react";
import clsx from "clsx";

// ─── Metadata ─────────────────────────────────────────────────────────────────

const METRIC_META: Record<RoomMetric, { label: string; icon: React.ElementType; color: string }> = {
  CHECKINS: { label: "Check-ins",       icon: Zap,        color: "text-yellow-400" },
  SESSIONS: { label: "Classes Attended",icon: BarChart3,   color: "text-blue-400"   },
  STREAK:   { label: "Streak",          icon: TrendingUp,  color: "text-green-400"  },
};

const PERIOD_LABELS: Record<RoomPeriod, string> = {
  WEEKLY:  "Resets weekly (Mon)",
  MONTHLY: "Resets monthly (1st)",
  ONGOING: "Cumulative, no reset",
  CUSTOM:  "Fixed date range",
};

function timeAgo(iso: string) {
  const d = Math.floor((Date.now() - new Date(iso).getTime()) / 86400000);
  return d === 0 ? "Today" : d === 1 ? "Yesterday" : `${d}d ago`;
}

function CopyCode({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      onClick={() => { navigator.clipboard.writeText(code); setCopied(true); setTimeout(() => setCopied(false), 2000); }}
      className="flex items-center gap-1 text-xs font-mono text-zinc-400 hover:text-white transition-colors"
    >
      <span className="tracking-widest">{code}</span>
      {copied ? <Check size={10} className="text-green-400" /> : <Copy size={10} />}
    </button>
  );
}

// ─── Create Room Modal ────────────────────────────────────────────────────────

function CreateRoomModal({ gymId, onClose }: { gymId: string; onClose: () => void }) {
  const { token } = useAuthStore();
  const qc = useQueryClient();

  const [name, setName] = useState("");
  const [desc, setDesc] = useState("");
  const [metric, setMetric] = useState<RoomMetric>("CHECKINS");
  const [period, setPeriod] = useState<RoomPeriod>("WEEKLY");
  const [isPublic, setIsPublic] = useState(true);
  const [maxMembers, setMaxMembers] = useState(30);
  const [endDate, setEndDate] = useState("");

  const create = useMutation({
    mutationFn: () => roomsAdminApi.create(gymId, {
      name, description: desc || undefined, metric, period,
      endDate: endDate || undefined, isPublic, maxMembers,
    }, token!),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["rooms-admin", gymId] }); onClose(); },
  });

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
      <div className="flex flex-col bg-[#0D1320] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[92vh] shadow-[0_0_120px_rgba(0,0,0,0.6)] overflow-hidden">
        
        {/* Header */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-2xl font-black text-white uppercase tracking-tighter italic flex items-center gap-3">
              <Trophy className="text-[#F1C40F]" size={24} />
              Create Competition
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mt-1">
              Members join and compete on a live leaderboard
            </p>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-red-500/10 rounded-2xl text-zinc-500 hover:text-red-400 transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8 space-y-6">
          {/* Room Name */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Room Name *</label>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. January Check-in Challenge"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all font-bold"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Description</label>
            <textarea
              value={desc}
              onChange={(e) => setDesc(e.target.value)}
              rows={2}
              placeholder="Optional details for participants..."
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all resize-none shadow-sm"
            />
          </div>

          {/* Metric */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-3 px-1">Compete On *</label>
            <div className="grid grid-cols-3 gap-3">
              {(Object.keys(METRIC_META) as RoomMetric[]).map((m) => {
                const meta = METRIC_META[m];
                const Icon = meta.icon;
                const active = metric === m;
                return (
                  <button
                    key={m}
                    onClick={() => setMetric(m)}
                    className={`flex flex-col items-center gap-2 py-4 rounded-2xl border transition-all font-bold text-sm ${
                      active
                        ? "bg-[#F1C40F]/10 border-[#F1C40F]/40 text-[#F1C40F]"
                        : "bg-white/[0.03] border-white/10 text-zinc-600 hover:border-white/20"
                    }`}
                  >
                    <Icon size={20} className={active ? meta.color : ""} />
                    <span className="text-[10px] uppercase tracking-widest font-black">{meta.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Period */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-3 px-1">Competition Period *</label>
            <div className="grid grid-cols-2 gap-3">
              {(Object.keys(PERIOD_LABELS) as RoomPeriod[]).map((p) => {
                const active = period === p;
                return (
                  <button
                    key={p}
                    onClick={() => setPeriod(p)}
                    className={`flex flex-col items-start gap-1 p-4 rounded-2xl border transition-all ${
                      active
                        ? "bg-[#F1C40F]/10 border-[#F1C40F]/40"
                        : "bg-white/[0.02] border-white/5 hover:border-white/15"
                    }`}
                  >
                    <p className={`font-black text-sm uppercase tracking-tight ${active ? "text-[#F1C40F]" : "text-white"}`}>{p}</p>
                    <p className="text-[10px] text-zinc-500 font-bold uppercase tracking-wider">{PERIOD_LABELS[p]}</p>
                  </button>
                );
              })}
            </div>
          </div>

          {period === "CUSTOM" && (
            <div className="animate-in slide-in-from-top-2 duration-200">
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">End Date *</label>
              <input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
                className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
              />
            </div>
          )}

          <div className="flex gap-4">
            <div className="flex-1">
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Max Members</label>
              <input
                type="number"
                value={maxMembers}
                min={2}
                max={500}
                onChange={(e) => setMaxMembers(Number(e.target.value))}
                className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all font-bold"
              />
            </div>
            <div className="flex-1">
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Visibility</label>
              <button
                onClick={() => setIsPublic(!isPublic)}
                className={`w-full flex items-center justify-center gap-2 py-4 rounded-2xl border transition-all font-bold text-sm ${
                  isPublic
                    ? "bg-green-500/10 border-green-500/30 text-green-400"
                    : "bg-white/[0.03] border-white/10 text-zinc-600"
                }`}
              >
                {isPublic ? <Globe size={16} /> : <Lock size={16} />}
                <span className="text-[10px] uppercase tracking-widest font-black">{isPublic ? "Public" : "Private"}</span>
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex justify-end gap-3 shrink-0">
          <button
            onClick={onClose}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-all"
          >
            Cancel
          </button>
          <button
            onClick={() => create.mutate()}
            disabled={!name.trim() || create.isPending}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-40 flex items-center gap-2 transition-all shadow-lg"
          >
            {create.isPending && <Loader2 className="animate-spin" size={14} />}
            {create.isPending ? "Creating…" : "Create Room"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Room Card ────────────────────────────────────────────────────────────────

function RoomCard({ room, gymId }: { room: ProgressRoom; gymId: string }) {
  const { token } = useAuthStore();
  const qc = useQueryClient();
  const meta = METRIC_META[room.metric];
  const Icon = meta.icon;

  const del = useMutation({
    mutationFn: () => roomsAdminApi.delete(gymId, room.id, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["rooms-admin", gymId] }),
  });

  const isExpired = room.endDate && new Date(room.endDate) < new Date();

  return (
    <div className="bg-[#121721] border border-white/5 rounded-3xl p-6 space-y-4 hover:border-white/10 transition-all group overflow-hidden relative shadow-xl">
      <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
      
      <div className="flex items-start justify-between gap-3 relative z-10">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-2">
            <span className={clsx("text-[10px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-md bg-white/[0.03] border border-white/5", meta.color)}>
              {meta.label}
            </span>
            <span className="text-[10px] text-zinc-500 uppercase tracking-widest font-bold">{room.period}</span>
            {isExpired && <span className="text-[10px] font-black uppercase tracking-widest px-2 py-0.5 rounded-md bg-red-500/10 text-red-400 border border-red-500/10">Ended</span>}
          </div>
          <p className="text-xl font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors">{room.name}</p>
          {room.description && <p className="text-xs text-zinc-500 mt-2 font-medium line-clamp-2 leading-relaxed">{room.description}</p>}
        </div>
        <button onClick={() => { if (confirm(`Delete "${room.name}"?`)) del.mutate(); }}
          disabled={del.isPending}
          className="p-3 bg-white/[0.03] text-zinc-600 hover:text-red-400 hover:bg-red-500/10 rounded-2xl transition-all border border-white/5 flex-shrink-0">
          <Trash2 size={16} />
        </button>
      </div>

      <div className="flex items-center gap-6 text-xs relative z-10 py-2">
        <div className="flex items-center gap-2 text-zinc-400 font-bold">
          <div className="p-1.5 bg-white/5 rounded-lg"><Users size={14} /></div>
          <span>{room._count.members} / {room.maxMembers}</span>
        </div>
        <div className="flex items-center gap-2 text-zinc-400 font-bold">
          <div className="p-1.5 bg-white/5 rounded-lg"><Icon size={14} className={meta.color} /></div>
          <span>{meta.label}</span>
        </div>
        <div className="flex items-center gap-2 text-zinc-400 font-bold">
          <div className="p-1.5 bg-white/5 rounded-lg">{room.isPublic ? <Globe size={14} /> : <Lock size={14} />}</div>
          <span>{room.isPublic ? "Public" : "Private"}</span>
        </div>
      </div>

      <div className="flex items-center justify-between pt-4 border-t border-white/5 relative z-10">
        <div className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">
          {room.creator.fullName} · {timeAgo(room.createdAt)}
        </div>
        <div className="p-1.5 bg-white/5 rounded-xl border border-white/5">
          <CopyCode code={room.inviteCode} />
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function RoomsPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const { token } = useAuthStore();
  const gymId = selectedGymId as string;
  const [showCreate, setShowCreate] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["rooms-admin", gymId],
    queryFn: () => roomsAdminApi.list(gymId, token!),
    enabled: !!token && !!gymId,
    staleTime: 30000,
  });

  const rooms: ProgressRoom[] = data?.data ?? [];
  const activeRooms = rooms.filter(r => r.isActive && (!r.endDate || new Date(r.endDate) >= new Date()));
  const totalMembers = rooms.reduce((s, r) => s + r._count.members, 0);

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="Progress Rooms"
        description="Social competitions to boost member engagement."
        icon={<Trophy size={32} />}
        actions={
          <>
            <button
              onClick={() => setShowCreate(true)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              Create Room
            </button>

            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {[
          { label: "Total Rooms",     value: rooms.length, color: "text-white" },
          { label: "Active",          value: activeRooms.length, color: "text-green-400" },
          { label: "Total Competing", value: totalMembers, color: "text-[#F1C40F]" },
        ].map(s => (
          <div key={s.label} className="bg-[#121721] border border-white/5 rounded-3xl p-6 shadow-xl relative overflow-hidden group">
            <div className="absolute top-0 right-0 w-32 h-32 bg-white/[0.02] rounded-full -mr-16 -mt-16 transition-transform group-hover:scale-110" />
            <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 mb-2">{s.label}</p>
            <p className={clsx("text-4xl font-black tracking-tighter italic", s.color)}>{s.value}</p>
          </div>
        ))}
      </div>

      {isLoading ? (
        <div className="flex items-center justify-center py-16 text-zinc-500">
          <RefreshCw size={18} className="animate-spin mr-2" /> Loading…
        </div>
      ) : rooms.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 bg-[#121721] border border-white/5 rounded-[2.5rem] border-dashed">
          <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
            <Trophy className="text-zinc-700" size={48} />
          </div>
          <h3 className="text-xl font-black text-white uppercase tracking-tight italic">No Active Rooms</h3>
          <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest text-center">
            There are no competitions running yet. Create one to foster engagement and community.
          </p>
          <button 
            onClick={() => setShowCreate(true)}
            className="mt-10 flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
          >
            <Plus size={16} />
            Create First Room
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {rooms.map(r => <RoomCard key={r.id} room={r} gymId={gymId} />)}
        </div>
      )}

      {showCreate && <CreateRoomModal gymId={gymId} onClose={() => setShowCreate(false)} />}
    </div>
  );
}

"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import {
  announcementsApi,
  GymAnnouncement,
  PublishAnnouncementData,
} from "@/lib/api";
import { PageHeader } from "@/components/ui/PageHeader";
import {
  Megaphone,
  Plus,
  Pin,
  PinOff,
  Trash2,
  Send,
  CheckCircle2,
  Clock,
  X,
  Smartphone,
  Bell,
  Mail,
  Loader2,
} from "lucide-react";
import clsx from "clsx";

const AUDIENCE_OPTIONS = [
  { value: "ALL",       label: "All Members", desc: "Everyone currently active in the gym" },
  { value: "CHECKEDIN", label: "Checked-in Now", desc: "Only members currently inside the facility" },
  { value: "NEW",       label: "New Members", desc: "Joined within the last 7 days" },
];

// ─── Compose Modal ────────────────────────────────────────────────────────────

function ComposeModal({
  onClose,
  onPublish,
  loading,
}: {
  onClose: () => void;
  onPublish: (data: PublishAnnouncementData) => void;
  loading: boolean;
}) {
  const [form, setForm] = useState<PublishAnnouncementData>({
    title: "",
    body: "",
    imageUrl: "",
    isPinned: false,
    targetAudience: "ALL",
    channels: ["PUSH", "IN_APP"],
  });

  const toggleChannel = (ch: string) => {
    setForm((f) => ({
      ...f,
      channels: f.channels.includes(ch)
        ? f.channels.filter((c) => c !== ch)
        : [...f.channels, ch],
    }));
  };

  const isValid = form.title.trim() && form.body.trim() && form.channels.length > 0;

  const CHANNELS = [
    { id: "PUSH", label: "Push", icon: Smartphone, color: "text-purple-400", border: "border-purple-400/50", bg: "bg-purple-400/10" },
    { id: "IN_APP", label: "In-App", icon: Bell, color: "text-yellow-400", border: "border-yellow-400/50", bg: "bg-yellow-400/10" },
    { id: "EMAIL", label: "Email", icon: Mail, color: "text-blue-400", border: "border-blue-400/50", bg: "bg-blue-400/10" },
  ];

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
      <div className="flex flex-col bg-[#0D1320] border border-white/10 rounded-[2.5rem] w-full max-w-2xl max-h-[92vh] shadow-[0_0_120px_rgba(0,0,0,0.6)] overflow-hidden">
        
        {/* Header */}
        <div className="p-8 border-b border-white/5 flex items-center justify-between shrink-0 bg-white/[0.02]">
          <div>
            <h2 className="text-2xl font-black text-white uppercase tracking-tighter italic flex items-center gap-3">
              <Megaphone className="text-[#F1C40F]" size={24} />
              New Announcement
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mt-1">
              Published immediately — members receive a notification
            </p>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-red-500/10 rounded-2xl text-zinc-500 hover:text-red-400 transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8 space-y-6">
          {/* Title */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Title *</label>
            <input
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              maxLength={100}
              placeholder="e.g. New classes this week!"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
            />
          </div>

          {/* Message */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Message *</label>
            <textarea
              value={form.body}
              onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
              rows={5}
              placeholder="Write your announcement here..."
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all resize-none"
            />
            <p className="text-right text-[10px] text-zinc-600 mt-1">{form.body.length} characters</p>
          </div>

          {/* Audience */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-3 px-1">Target Audience *</label>
            <div className="space-y-2">
              {AUDIENCE_OPTIONS.map((opt) => {
                const active = form.targetAudience === opt.value;
                return (
                  <label
                    key={opt.value}
                    className={`flex items-center gap-3 p-4 rounded-2xl cursor-pointer transition-all border ${
                      active
                        ? "bg-[#F1C40F]/10 border-[#F1C40F]/40"
                        : "bg-white/[0.02] border-white/5 hover:border-white/15"
                    }`}
                  >
                    <input
                      type="radio"
                      name="audience"
                      value={opt.value}
                      checked={active}
                      onChange={() => setForm((f) => ({ ...f, targetAudience: opt.value }))}
                      className="sr-only"
                    />
                    <div className={`w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0 ${active ? "border-[#F1C40F]" : "border-zinc-600"}`}>
                      {active && <div className="w-2 h-2 bg-[#F1C40F] rounded-full" />}
                    </div>
                    <div className="flex-1">
                      <p className={`font-black text-sm ${active ? "text-[#F1C40F]" : "text-white"}`}>{opt.label}</p>
                      <p className="text-xs text-zinc-500">{opt.desc}</p>
                    </div>
                  </label>
                );
              })}
            </div>
          </div>

          {/* Channels */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-3 px-1">Delivery Channels *</label>
            <div className="flex gap-3">
              {CHANNELS.map((ch) => {
                const Icon = ch.icon;
                const active = form.channels.includes(ch.id);
                return (
                  <button
                    key={ch.id}
                    type="button"
                    onClick={() => toggleChannel(ch.id)}
                    className={`flex-1 flex flex-col items-center gap-2 py-4 rounded-2xl border transition-all font-bold text-sm ${
                      active
                        ? `${ch.bg} ${ch.border} ${ch.color}`
                        : "bg-white/[0.03] border-white/10 text-zinc-600 hover:border-white/20"
                    }`}
                  >
                    <Icon size={20} />
                    <span className="text-[10px] uppercase tracking-widest font-black">{ch.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Pin option */}
          <label className={`flex items-center gap-3 p-4 rounded-2xl cursor-pointer transition-all border ${
            form.isPinned ? "bg-[#F1C40F]/10 border-[#F1C40F]/40" : "bg-white/[0.02] border-white/5 hover:border-white/15"
          }`}>
            <input
              type="checkbox"
              checked={form.isPinned ?? false}
              onChange={(e) => setForm((f) => ({ ...f, isPinned: e.target.checked }))}
              className="sr-only"
            />
            <div className={`w-5 h-5 rounded-md border-2 flex items-center justify-center shrink-0 ${form.isPinned ? "border-[#F1C40F] bg-[#F1C40F]" : "border-zinc-600"}`}>
              {form.isPinned && <CheckCircle2 size={12} className="text-black" />}
            </div>
            <div className="flex-1">
              <p className={`font-black text-sm ${form.isPinned ? "text-[#F1C40F]" : "text-white"}`}>Pin this announcement</p>
              <p className="text-xs text-zinc-500">Pinned posts appear at the top of the feed</p>
            </div>
          </label>
        </div>

        {/* Footer */}
        <div className="p-8 bg-white/[0.02] border-t border-white/5 flex justify-end gap-3 shrink-0">
          <button
            onClick={onClose}
            disabled={loading}
            className="px-8 py-4 bg-white/[0.03] text-zinc-500 hover:text-white rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 transition-all"
          >
            Cancel
          </button>
          <button
            onClick={() => isValid && onPublish(form)}
            disabled={!isValid || loading}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-40 flex items-center gap-2 transition-all"
          >
            {loading ? <Loader2 className="animate-spin" size={14} /> : <Send size={14} />}
            {loading ? "Publishing..." : "Publish Now"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── AnnouncementCard ─────────────────────────────────────────────────────────

function AnnouncementCard({
  item,
  onTogglePin,
  onDelete,
}: {
  item: GymAnnouncement;
  onTogglePin: () => void;
  onDelete: () => void;
}) {
  const audienceLabel = AUDIENCE_OPTIONS.find((a) => a.value === item.targetAudience)?.label ?? item.targetAudience;

  return (
    <div
      className={clsx(
        "bg-[#121721] border border-white/5 rounded-3xl p-6 space-y-4 hover:border-white/10 transition-all group overflow-hidden relative shadow-xl",
        item.isPinned ? "ring-1 ring-[#F1C40F]/30" : ""
      )}
    >
      <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
      
      {/* Header */}
      <div className="flex items-start justify-between gap-3 relative z-10">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-2">
            {item.isPinned && (
              <span className="flex items-center gap-1.5 text-[10px] font-black uppercase tracking-[0.1em] text-[#F1C40F] bg-[#F1C40F]/10 px-2 py-0.5 rounded-md border border-[#F1C40F]/10">
                <Pin size={10} /> Pinned
              </span>
            )}
            <span className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.1em] px-2 py-0.5 rounded-md border border-white/5 bg-white/[0.03]">
              {audienceLabel}
            </span>
          </div>
          <h3 className="text-xl font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors line-clamp-2">{item.title}</h3>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          <button
            onClick={onTogglePin}
            title={item.isPinned ? "Unpin" : "Pin"}
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-[#F1C40F] hover:bg-[#F1C40F]/10 rounded-2xl transition-all border border-white/5"
          >
            {item.isPinned ? <PinOff size={16} /> : <Pin size={16} />}
          </button>
          <button
            onClick={onDelete}
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-red-400 hover:bg-red-500/10 rounded-2xl transition-all border border-white/5"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </div>

      {/* Body */}
      <p className="text-sm text-zinc-400 leading-relaxed whitespace-pre-wrap font-medium line-clamp-4 relative z-10">{item.body}</p>

      {/* Footer */}
      <div className="flex flex-col gap-4 pt-4 border-t border-white/5 relative z-10">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4 text-[10px] font-black text-zinc-500 uppercase tracking-widest leading-none">
            <span className="flex items-center gap-1.5">
              <Clock size={12} className="text-[#F1C40F]" />
              {new Date(item.publishedAt).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}
            </span>
            <span className="flex items-center gap-1.5 border-l border-white/5 pl-4">
              <Send size={12} className="text-[#F1C40F]" />
              {item.totalDelivered.toLocaleString()} delivered
            </span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-5 h-5 rounded-full bg-white/[0.03] border border-white/5 flex items-center justify-center text-[10px] uppercase font-black text-zinc-600">
              {item.author.fullName.charAt(0)}
            </div>
            <span className="text-[10px] font-black text-white uppercase tracking-wider">{item.author.fullName}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function AnnouncementsPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const { token } = useAuthStore();
  const queryClient = useQueryClient();
  const gymId = selectedGymId as string;

  const [composing, setComposing] = useState(false);
  const [justPublished, setJustPublished] = useState(false);

  const { data, isLoading } = useQuery({
    queryKey: ["announcements", gymId],
    queryFn: () => announcementsApi.list(gymId, token!),
    enabled: !!token,
  });

  const announcements: GymAnnouncement[] = (data as { data: GymAnnouncement[] })?.data ?? (Array.isArray(data) ? data : []);
  const pinned = announcements.filter((a) => a.isPinned);
  const unpinned = announcements.filter((a) => !a.isPinned);

  const publishMutation = useMutation({
    mutationFn: (d: PublishAnnouncementData) => announcementsApi.publish(gymId, d, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["announcements", gymId] });
      setComposing(false);
      setJustPublished(true);
      setTimeout(() => setJustPublished(false), 3500);
    },
  });

  const pinMutation = useMutation({
    mutationFn: (id: string) => announcementsApi.togglePin(gymId, id, token!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["announcements", gymId] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => announcementsApi.delete(gymId, id, token!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["announcements", gymId] }),
  });

  const totalDelivered = announcements.reduce((s, a) => s + a.totalDelivered, 0);

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="Announcements"
        description="Post updates, news, and events. Members receive an instant notification."
        icon={<Megaphone size={32} />}
        actions={
          <>
            <button
              onClick={() => setComposing(true)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              Post Announcement
            </button>
            <GymSwitcher 
              gyms={gyms} 
              isLoading={gymsLoading} 
              disabled={userRole === "BRANCH_ADMIN"}
            />
          </>
        }
      />

      {/* Stats row - premium cards */}
      <div className="grid grid-cols-2 lg:grid-cols-3 gap-6">
        {[
          { label: "Total Posts", value: announcements.length, icon: Megaphone, color: "blue" },
          { label: "Pinned", value: pinned.length, icon: Pin, color: "yellow" },
          { label: "Total Delivered", value: totalDelivered.toLocaleString(), icon: Send, color: "green" },
        ].map((s) => {
          const Icon = s.icon;
          const colorClass = s.color === "blue" ? "text-blue-400" : s.color === "yellow" ? "text-yellow-400" : "text-green-400";
          const bgClass = s.color === "blue" ? "bg-blue-500/10" : s.color === "yellow" ? "bg-yellow-500/10" : "bg-green-500/10";
          
          return (
            <div key={s.label} className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-2xl p-5 hover:border-[#F1C40F]/30 transition-all duration-300">
              <div className="relative flex items-center gap-4">
                <div className={`p-3 ${bgClass} rounded-xl group-hover:scale-110 transition-transform duration-300`}>
                  <Icon className={colorClass} size={24} />
                </div>
                <div>
                  <p className="text-xs font-medium text-zinc-500 uppercase tracking-wider">{s.label}</p>
                  <p className="text-3xl font-bold text-white mt-1">{s.value}</p>
                </div>
              </div>
            </div>
          );
        })}
      </div>


      {/* Success toast */}
      {justPublished && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-sm text-green-400 flex items-center gap-2">
          <CheckCircle2 size={16} />
          Announcement published — members are being notified now.
        </div>
      )}

      {/* Content */}
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="animate-spin text-[#F1C40F]" size={32} />
        </div>
      ) : announcements.length === 0 ? (
        <div className="text-center py-24 bg-[#121721] border border-white/5 border-dashed rounded-[2.5rem] flex flex-col items-center justify-center">
          <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
            <Megaphone size={48} className="text-zinc-700" />
          </div>
          <h3 className="text-xl font-black text-white uppercase tracking-tight italic">No announcements yet</h3>
          <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest">Post your first update to synchronize with all facility members instantly.</p>
          <button
            onClick={() => setComposing(true)}
            className="mt-8 flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
          >
            <Plus size={16} />
            Compose First Message
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {pinned.length > 0 && (
            <div className="space-y-3">
              <p className="text-[10px] font-black uppercase tracking-[0.2em] text-[#F1C40F] px-1">
                Pinned ({pinned.length})
              </p>
              {pinned.map((item) => (
                <AnnouncementCard
                  key={item.id}
                  item={item}
                  onTogglePin={() => pinMutation.mutate(item.id)}
                  onDelete={() => {
                    if (confirm("Delete this announcement?")) deleteMutation.mutate(item.id);
                  }}
                />
              ))}
            </div>
          )}

          {unpinned.length > 0 && (
            <div className="space-y-3">
              {pinned.length > 0 && (
                <p className="text-[10px] font-black uppercase tracking-[0.2em] text-zinc-500 px-1">
                  Recent ({unpinned.length})
                </p>
              )}
              {unpinned.map((item) => (
                <AnnouncementCard
                  key={item.id}
                  item={item}
                  onTogglePin={() => pinMutation.mutate(item.id)}
                  onDelete={() => {
                    if (confirm("Delete this announcement?")) deleteMutation.mutate(item.id);
                  }}
                />
              ))}
            </div>
          )}
        </div>
      )}

      {/* Compose Modal */}
      {composing && (
        <ComposeModal
          onClose={() => setComposing(false)}
          onPublish={(d) => publishMutation.mutate(d)}
          loading={publishMutation.isPending}
        />
      )}
    </div>
  );
}

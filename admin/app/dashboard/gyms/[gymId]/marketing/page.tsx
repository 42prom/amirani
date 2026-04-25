"use client";

import { useAuthStore } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import {
  marketingApi,
  MarketingCampaign,
  CreateCampaignData,
  CampaignAudience,
} from "@/lib/api";
import { useState, useEffect } from "react";
import { PageHeader } from "@/components/ui/PageHeader";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import {
  Megaphone,
  Plus,
  Send,
  Trash2,
  RefreshCw,
  X,
  Users,
  Bell,
  Mail,
  Smartphone,
  CheckCircle2,
  Clock,
  AlertCircle,
  Eye,
  Loader2,
} from "lucide-react";

// ─── Helpers ──────────────────────────────────────────────────────────────────

const AUDIENCE_OPTIONS: { value: CampaignAudience; label: string; description: string; color: string }[] = [
  { value: "ALL", label: "All Members", description: "Every member with any status", color: "text-zinc-300" },
  { value: "ACTIVE", label: "Active Members", description: "Current paying members", color: "text-green-400" },
  { value: "EXPIRED", label: "Expired Members", description: "Memberships that have lapsed", color: "text-red-400" },
  { value: "PENDING", label: "Pending Members", description: "Awaiting activation", color: "text-yellow-400" },
  { value: "INACTIVE_30D", label: "Inactive 30+ Days", description: "Active but haven't visited in 30 days", color: "text-orange-400" },
  { value: "INACTIVE_60D", label: "Inactive 60+ Days", description: "Active but haven't visited in 60 days", color: "text-red-300" },
];

const STATUS_CONFIG: Record<string, { label: string; icon: typeof CheckCircle2; bg: string; text: string }> = {
  DRAFT: { label: "Draft", icon: Clock, bg: "bg-zinc-700/50", text: "text-zinc-400" },
  SENDING: { label: "Sending…", icon: Loader2, bg: "bg-blue-500/10", text: "text-blue-400" },
  SENT: { label: "Sent", icon: CheckCircle2, bg: "bg-green-500/10", text: "text-green-400" },
  FAILED: { label: "Failed", icon: AlertCircle, bg: "bg-red-500/10", text: "text-red-400" },
};

function StatusBadge({ status }: { status: string }) {
  const cfg = STATUS_CONFIG[status] ?? STATUS_CONFIG.DRAFT;
  const Icon = cfg.icon;
  return (
    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-widest ${cfg.bg} ${cfg.text}`}>
      <Icon size={10} className={status === "SENDING" ? "animate-spin" : ""} />
      {cfg.label}
    </span>
  );
}

function ChannelBadge({ channel }: { channel: string }) {
  const map: Record<string, { icon: typeof Bell; color: string }> = {
    PUSH: { icon: Smartphone, color: "text-purple-400" },
    EMAIL: { icon: Mail, color: "text-blue-400" },
    IN_APP: { icon: Bell, color: "text-yellow-400" },
  };
  const cfg = map[channel] ?? { icon: Bell, color: "text-zinc-400" };
  const Icon = cfg.icon;
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-0.5 bg-white/5 rounded text-[10px] font-bold uppercase ${cfg.color}`}>
      <Icon size={10} />
      {channel.replace("_", " ")}
    </span>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function MarketingPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const gymId = selectedGymId as string;
  const { token } = useAuthStore();
  const queryClient = useQueryClient();

  const [showComposer, setShowComposer] = useState(false);
  const [confirmSendId, setConfirmSendId] = useState<string | null>(null);

  const { data, isLoading, isError } = useQuery({
    queryKey: ["marketing-campaigns", gymId],
    queryFn: () => marketingApi.list(gymId, token!),
    enabled: !!token && !!gymId,
    refetchInterval: (query) => {
      const campaigns = query.state.data as MarketingCampaign[] | undefined;
      return campaigns?.some((c) => c.status === "SENDING") ? 3000 : false;
    },
  });

  const campaigns = data ?? [];

  const sendMutation = useMutation({
    mutationFn: (campaignId: string) => marketingApi.send(gymId, campaignId, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["marketing-campaigns", gymId] });
      setConfirmSendId(null);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (campaignId: string) => marketingApi.delete(gymId, campaignId, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["marketing-campaigns", gymId] });
    },
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="animate-spin text-[#F1C40F]" size={32} />
      </div>
    );
  }

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="Marketing Campaigns"
        description="Send targeted push notifications and emails to your members"
        icon={<Megaphone size={32} />}
        actions={
          <>
            <button
              onClick={() => setShowComposer(true)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              New Campaign
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
      {campaigns.length > 0 && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
          {[
            { label: "Total Campaigns", value: campaigns.length, icon: Megaphone, color: "blue" },
            { label: "Sent", value: campaigns.filter((c: MarketingCampaign) => c.status === "SENT").length, icon: CheckCircle2, color: "green" },
            { label: "Total Reached", value: campaigns.reduce((s: number, c: MarketingCampaign) => s + c.totalDelivered, 0).toLocaleString(), icon: Send, color: "yellow" },
            { label: "Drafts", value: campaigns.filter((c: MarketingCampaign) => c.status === "DRAFT").length, icon: Clock, color: "red" },
          ].map((s) => {
            const Icon = s.icon;
            const colorClass = s.color === "blue" ? "text-blue-400" : s.color === "green" ? "text-green-400" : s.color === "yellow" ? "text-yellow-400" : "text-red-400";
            const bgClass = s.color === "blue" ? "bg-blue-500/10" : s.color === "green" ? "bg-green-500/10" : s.color === "yellow" ? "bg-yellow-500/10" : "bg-red-500/10";
            
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
      )}

      {/* Campaign List */}
      {isError ? (
        <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-12 text-center">
          <AlertCircle className="mx-auto text-red-400 mb-3" size={48} />
          <p className="text-red-400 font-bold uppercase tracking-widest text-[10px]">Failed to load campaigns</p>
        </div>
      ) : campaigns.length === 0 ? (
        <div className="text-center py-24 bg-[#121721] border border-white/5 border-dashed rounded-[2.5rem] flex flex-col items-center justify-center">
          <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
            <Megaphone size={48} className="text-zinc-700" />
          </div>
          <h3 className="text-xl font-black text-white uppercase tracking-tight italic">No campaigns yet</h3>
          <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest">Reach your members with targeted messages to re-engage or announce promotions.</p>
          <button
            onClick={() => setShowComposer(true)}
            className="mt-8 flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
          >
            <Plus size={16} />
            Create First Campaign
          </button>
        </div>
      ) : (
        <div className="space-y-3">
          {campaigns.map((campaign: MarketingCampaign) => (
            <div
              key={campaign.id}
              className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-3xl p-6 flex flex-col md:flex-row md:items-center gap-6 hover:border-white/10 transition-all shadow-xl"
            >
              <div className="absolute top-0 right-0 w-32 h-32 bg-white/[0.02] rounded-full -mr-16 -mt-16 transition-transform group-hover:scale-110" />

              {/* Left: icon/status */}
              <div className="relative z-10 shrink-0 hidden md:flex flex-col items-center gap-3 w-20">
                <div className="w-12 h-12 rounded-2xl bg-white/[0.03] border border-white/5 flex items-center justify-center text-[#F1C40F] group-hover:bg-[#F1C40F]/10 transition-colors">
                  <Megaphone size={22} />
                </div>
                <StatusBadge status={campaign.status} />
              </div>

              {/* Middle: info */}
              <div className="flex-1 min-w-0 relative z-10">
                <div className="flex flex-wrap items-center gap-2 mb-2 md:hidden">
                  <StatusBadge status={campaign.status} />
                </div>
                
                <h3 className="text-xl font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors truncate">
                  {campaign.name}
                </h3>
                
                {campaign.subject && (
                  <p className="text-sm font-bold text-zinc-400 mt-1 truncate">
                    Subject: {campaign.subject}
                  </p>
                )}
                
                <p className="text-xs text-zinc-500 mt-2 font-medium line-clamp-1 leading-relaxed bg-white/[0.02] px-3 py-1.5 rounded-xl inline-block border border-white/5">
                  {campaign.body}
                </p>

                <div className="flex flex-wrap items-center gap-4 mt-4">
                  <div className="flex items-center gap-4 text-[10px] font-black text-zinc-500 uppercase tracking-widest leading-none">
                    <span className="flex items-center gap-1.5">
                      <Users size={12} className="text-[#F1C40F]" />
                      {AUDIENCE_OPTIONS.find((a) => a.value === campaign.targetAudience)?.label ?? campaign.targetAudience}
                    </span>
                    <span className="flex items-center gap-1.5 border-l border-white/5 pl-4">
                      <Clock size={12} className="text-[#F1C40F]" />
                      {new Date(campaign.createdAt).toLocaleDateString()}
                    </span>
                    <span className="flex items-center gap-1.5 border-l border-white/5 pl-4">
                      <Send size={12} className="text-[#F1C40F]" />
                      {campaign.totalDelivered.toLocaleString()} delivered
                    </span>
                  </div>
                  
                  <div className="flex gap-1.5 ml-auto">
                    {campaign.channels.map((ch: string) => (
                      <ChannelBadge key={ch} channel={ch} />
                    ))}
                  </div>
                </div>
              </div>

              {/* Right: actions */}
              <div className="flex items-center gap-2 shrink-0">
                {campaign.status === "DRAFT" && (
                  <>
                    <button
                      onClick={() => setConfirmSendId(campaign.id)}
                      className="flex items-center gap-1.5 px-4 py-2 bg-[#F1C40F] !text-black rounded-xl font-black uppercase tracking-widest text-[10px] hover:bg-[#F1C40F]/90 transition-all"
                    >
                      <Send size={14} />
                      Send Now
                    </button>
                    <button
                      onClick={() => {
                        if (confirm(`Delete "${campaign.name}"?`)) deleteMutation.mutate(campaign.id);
                      }}
                      className="p-2.5 hover:bg-red-500/10 rounded-xl transition-colors border border-white/5"
                    >
                      <Trash2 size={16} className="text-red-400" />
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Campaign Composer Modal */}
      {showComposer && (
        <CampaignComposer
          gymId={gymId}
          token={token!}
          onClose={() => setShowComposer(false)}
          onCreated={() => {
            queryClient.invalidateQueries({ queryKey: ["marketing-campaigns", gymId] });
            setShowComposer(false);
          }}
        />
      )}

      {/* Send Confirmation Modal */}
      {confirmSendId && (
        <SendConfirmModal
          campaign={campaigns.find((c: MarketingCampaign) => c.id === confirmSendId)!}
          gymId={gymId}
          token={token!}
          isSending={sendMutation.isPending}
          onConfirm={() => sendMutation.mutate(confirmSendId)}
          onClose={() => setConfirmSendId(null)}
        />
      )}
    </div>
  );
}

// ─── Campaign Composer ────────────────────────────────────────────────────────

function CampaignComposer({
  gymId,
  token,
  onClose,
  onCreated,
}: {
  gymId: string;
  token: string;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [form, setForm] = useState<CreateCampaignData>({
    name: "",
    subject: "",
    body: "",
    channels: ["PUSH", "IN_APP"],
    targetAudience: "ACTIVE",
  });

  const [previewCount, setPreviewCount] = useState<number | null>(null);
  const [isPreviewing, setIsPreviewing] = useState(false);

  const createMutation = useMutation({
    mutationFn: (data: CreateCampaignData) => marketingApi.create(gymId, data, token),
    onSuccess: onCreated,
  });

  // Debounced audience preview
  useEffect(() => {
    const t = setTimeout(async () => {
      if (!form.targetAudience) return;
      setIsPreviewing(true);
      try {
        const res = await marketingApi.previewAudience(gymId, form.targetAudience, token);
        setPreviewCount(res.count);
      } catch {
        setPreviewCount(null);
      } finally {
        setIsPreviewing(false);
      }
    }, 400);
    return () => clearTimeout(t);
  }, [form.targetAudience, gymId, token]);

  const toggleChannel = (channel: string) => {
    setForm((prev) => ({
      ...prev,
      channels: prev.channels.includes(channel)
        ? prev.channels.filter((c: string) => c !== channel)
        : [...prev.channels, channel],
    }));
  };

  const isValid = form.name.trim() && form.body.trim() && form.channels.length > 0;

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
              New Campaign
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mt-1">Compose & Target Your Message</p>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-red-500/10 rounded-2xl text-zinc-500 hover:text-red-400 transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8 space-y-6">

          {/* Campaign Name */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Campaign Name *</label>
            <input
              type="text"
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              placeholder="e.g., January Win-Back Promo"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
            />
          </div>

          {/* Subject (email) */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">
              Email Subject <span className="text-zinc-600 normal-case font-normal">(optional — used for email channel)</span>
            </label>
            <input
              type="text"
              value={form.subject ?? ""}
              onChange={(e) => setForm({ ...form, subject: e.target.value })}
              placeholder="e.g., We miss you! Come back with 20% off"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
            />
          </div>

          {/* Message Body */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Message Body *</label>
            <textarea
              value={form.body}
              onChange={(e) => setForm({ ...form, body: e.target.value })}
              rows={4}
              placeholder="Write your message here…"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all resize-none"
            />
            <p className="text-right text-[10px] text-zinc-600 mt-1">{form.body.length} chars</p>
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
                      onChange={() => setForm({ ...form, targetAudience: opt.value })}
                      className="sr-only"
                    />
                    <div className={`w-4 h-4 rounded-full border-2 flex items-center justify-center shrink-0 ${active ? "border-[#F1C40F]" : "border-zinc-600"}`}>
                      {active && <div className="w-2 h-2 bg-[#F1C40F] rounded-full" />}
                    </div>
                    <div className="flex-1">
                      <p className={`font-black text-sm ${active ? "text-[#F1C40F]" : "text-white"}`}>{opt.label}</p>
                      <p className="text-xs text-zinc-500">{opt.description}</p>
                    </div>
                  </label>
                );
              })}
            </div>

            {/* Live preview count */}
            <div className={`mt-3 flex items-center gap-2 px-4 py-3 rounded-xl ${previewCount !== null ? "bg-[#F1C40F]/5 border border-[#F1C40F]/20" : "bg-white/[0.02] border border-white/5"}`}>
              {isPreviewing ? (
                <Loader2 size={14} className="animate-spin text-zinc-500" />
              ) : (
                <Eye size={14} className={previewCount !== null ? "text-[#F1C40F]" : "text-zinc-600"} />
              )}
              <span className={`text-sm font-bold ${previewCount !== null ? "text-[#F1C40F]" : "text-zinc-500"}`}>
                {isPreviewing
                  ? "Counting recipients…"
                  : previewCount !== null
                  ? `${previewCount} recipient${previewCount !== 1 ? "s" : ""} will receive this message`
                  : "Select an audience to preview recipient count"}
              </span>
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
            onClick={() => createMutation.mutate(form)}
            disabled={!isValid || createMutation.isPending}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-40 flex items-center gap-2 transition-all"
          >
            {createMutation.isPending && <Loader2 className="animate-spin" size={14} />}
            Save as Draft
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Send Confirmation Modal ──────────────────────────────────────────────────

function SendConfirmModal({
  campaign,
  gymId,
  token,
  isSending,
  onConfirm,
  onClose,
}: {
  campaign: MarketingCampaign;
  gymId: string;
  token: string;
  isSending: boolean;
  onConfirm: () => void;
  onClose: () => void;
}) {
  const [recipientCount, setRecipientCount] = useState<number | null>(null);

  useEffect(() => {
    marketingApi
      .previewAudience(gymId, campaign.targetAudience, token)
      .then((res) => setRecipientCount(res.count))
      .catch(() => {});
  }, [gymId, campaign.targetAudience, token]);

  return (
    <div className="fixed inset-0 bg-black/80 backdrop-blur-md flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
      <div className="bg-[#0D1320] border border-white/10 rounded-[2rem] w-full max-w-md shadow-[0_0_80px_rgba(0,0,0,0.5)] overflow-hidden">

        <div className="p-8">
          <div className="flex items-center gap-3 mb-6">
            <div className="w-12 h-12 bg-[#F1C40F]/10 rounded-2xl flex items-center justify-center">
              <Send className="text-[#F1C40F]" size={22} />
            </div>
            <div>
              <h3 className="text-lg font-black text-white">Send Campaign?</h3>
              <p className="text-xs text-zinc-500">This action cannot be undone</p>
            </div>
          </div>

          <div className="bg-white/[0.03] border border-white/5 rounded-2xl p-4 mb-6 space-y-3">
            <div>
              <p className="text-[10px] text-zinc-500 uppercase tracking-widest font-black">Campaign</p>
              <p className="text-white font-bold">{campaign.name}</p>
            </div>
            <div>
              <p className="text-[10px] text-zinc-500 uppercase tracking-widest font-black">Audience</p>
              <p className="text-white font-bold">
                {AUDIENCE_OPTIONS.find((a) => a.value === campaign.targetAudience)?.label ?? campaign.targetAudience}
              </p>
            </div>
            <div>
              <p className="text-[10px] text-zinc-500 uppercase tracking-widest font-black">Channels</p>
              <div className="flex gap-2 mt-1">
                {campaign.channels.map((ch) => <ChannelBadge key={ch} channel={ch} />)}
              </div>
            </div>
            <div>
              <p className="text-[10px] text-zinc-500 uppercase tracking-widest font-black">Recipients</p>
              <p className={`font-black text-lg ${recipientCount !== null ? "text-[#F1C40F]" : "text-zinc-500"}`}>
                {recipientCount !== null ? `~${recipientCount} members` : "Counting…"}
              </p>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              onClick={onClose}
              disabled={isSending}
              className="flex-1 py-4 bg-white/[0.03] text-zinc-400 rounded-2xl font-black uppercase tracking-widest text-[10px] border border-white/10 hover:text-white transition-all disabled:opacity-50"
            >
              Cancel
            </button>
            <button
              onClick={onConfirm}
              disabled={isSending}
              className="flex-1 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] flex items-center justify-center gap-2 disabled:opacity-50 transition-all"
            >
              {isSending ? <Loader2 className="animate-spin" size={14} /> : <Send size={14} />}
              {isSending ? "Sending…" : "Send Now"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

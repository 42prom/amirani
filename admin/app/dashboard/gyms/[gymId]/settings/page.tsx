"use client";

import { useState } from "react";
import { useParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import {
  api,
  gymsApi,
  webhooksApi,
  WebhookEndpoint,
  WebhookDelivery,
  WEBHOOK_EVENTS,
  WebhookEvent,
} from "@/lib/api";
import {
  Palette,
  Webhook,
  Settings,
  Check,
  RefreshCw,
  Smartphone,
  Plus,
  Trash2,
  Eye,
  EyeOff,
  ChevronLeft,
  ChevronRight,
  CheckCircle,
  XCircle,
  RotateCcw,
  Copy,
  ToggleLeft,
  ToggleRight,
  Languages,
  Globe,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import clsx from "clsx";

type Tab = "branding" | "webhooks" | "language";

// ─── Shared ───────────────────────────────────────────────────────────────────

function timeAgo(iso: string) {
  const diff = Date.now() - new Date(iso).getTime();
  const mins = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  if (hours < 24) return `${hours}h ago`;
  return `${days}d ago`;
}

function truncateUrl(url: string, max = 50) {
  return url.length > max ? url.slice(0, max) + "…" : url;
}

function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      onClick={() => {
        navigator.clipboard.writeText(value);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }}
      className="p-1 text-zinc-500 hover:text-white transition-colors"
    >
      {copied ? <Check size={12} className="text-green-400" /> : <Copy size={12} />}
    </button>
  );
}

// ─── BRANDING TAB ─────────────────────────────────────────────────────────────

const PRESET_COLORS = [
  { label: "Gold",    value: "#F1C40F" },
  { label: "Orange",  value: "#E67E22" },
  { label: "Red",     value: "#E74C3C" },
  { label: "Pink",    value: "#E91E8C" },
  { label: "Purple",  value: "#9B59B6" },
  { label: "Blue",    value: "#3498DB" },
  { label: "Teal",    value: "#1ABC9C" },
  { label: "Green",   value: "#2ECC71" },
  { label: "White",   value: "#FFFFFF" },
];

function MobilePreview({
  gymName,
  themeColor,
  welcomeMessage,
  logoUrl,
}: {
  gymName: string;
  themeColor: string;
  welcomeMessage: string;
  logoUrl?: string;
}) {
  const safe = themeColor || "#F1C40F";
  return (
    <div className="flex flex-col items-center">
      <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Live Preview</p>
      <div className="w-[200px] bg-[#0d1117] rounded-[28px] border-2 border-zinc-700 overflow-hidden shadow-2xl">
        <div className="h-6 bg-black flex items-center justify-center">
          <div className="w-16 h-1.5 bg-zinc-700 rounded-full" />
        </div>
        <div className="px-4 pt-4 pb-3" style={{ backgroundColor: safe + "18" }}>
          <div className="flex items-center gap-2 mb-2">
            {logoUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={logoUrl} alt="logo" className="w-8 h-8 rounded-full object-cover" />
            ) : (
              <div
                className="w-8 h-8 rounded-full flex items-center justify-center text-black font-bold text-xs"
                style={{ backgroundColor: safe }}
              >
                {gymName.charAt(0)}
              </div>
            )}
            <p className="text-white text-xs font-bold truncate">{gymName || "Your Gym"}</p>
          </div>
          {welcomeMessage && (
            <p className="text-[10px] leading-snug" style={{ color: safe }}>
              {welcomeMessage.slice(0, 60)}{welcomeMessage.length > 60 ? "…" : ""}
            </p>
          )}
        </div>
        <div className="p-3 space-y-2">
          <div
            className="w-full py-2 rounded-xl text-center text-[10px] font-bold text-black"
            style={{ backgroundColor: safe }}
          >
            Book a Class
          </div>
          {[1, 2].map((i) => (
            <div key={i} className="bg-zinc-800 rounded-xl p-2.5 flex items-center gap-2">
              <div className="w-6 h-6 rounded-lg" style={{ backgroundColor: safe + "30" }} />
              <div className="flex-1 space-y-1">
                <div className="h-1.5 bg-zinc-700 rounded w-3/4" />
                <div className="h-1 bg-zinc-700/50 rounded w-1/2" />
              </div>
            </div>
          ))}
          <div className="flex justify-around pt-1 mt-2 border-t border-zinc-800">
            {[0, 1, 2, 3].map((i) => (
              <div key={i} className="w-6 h-6 rounded-lg" style={{ backgroundColor: i === 0 ? safe + "30" : "transparent" }}>
                <div className="w-2 h-2 mx-auto mt-2 rounded-sm" style={{ backgroundColor: i === 0 ? safe : "#3f3f46" }} />
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function BrandingTab({ gymId, token }: { gymId: string; token: string }) {
  const qc = useQueryClient();

  const { data: gymData, isLoading } = useQuery({
    queryKey: ["gym", gymId],
    queryFn: () => gymsApi.getById(gymId, token),
    enabled: !!token,
  });

  const [themeColor, setThemeColor] = useState("#F1C40F");
  const [customColor, setCustomColor] = useState("");
  const [welcomeMessage, setWelcomeMessage] = useState("");
  const [dirty, setDirty] = useState(false);

  // Sync from server - modern React pattern to avoid cascading renders
  const [prevGymData, setPrevGymData] = useState(gymData);
  if (gymData !== prevGymData) {
    setPrevGymData(gymData);
    if (gymData && !dirty) {
      setThemeColor(gymData.themeColor || "#F1C40F");
      setCustomColor(gymData.themeColor || "");
      setWelcomeMessage(gymData.welcomeMessage || "");
    }
  }

  const save = useMutation({
    mutationFn: () =>
      gymsApi.update(gymId, {
        themeColor: themeColor || undefined,
        welcomeMessage: welcomeMessage || undefined,
      }, token),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["gym", gymId] });
      setDirty(false);
    },
  });

  function pickColor(c: string) {
    setThemeColor(c);
    setCustomColor(c);
    setDirty(true);
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-48 text-zinc-500">
        <RefreshCw size={18} className="animate-spin mr-2" /> Loading…
      </div>
    );
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Controls */}
      <div className="lg:col-span-2 space-y-5">
        {/* Save banner */}
        {dirty && (
          <div className="flex items-center justify-between bg-[#F1C40F]/10 border border-[#F1C40F]/30 rounded-xl px-5 py-3">
            <p className="text-sm text-[#F1C40F] font-medium">You have unsaved changes</p>
            <button
              onClick={() => save.mutate()}
              disabled={save.isPending}
              className="flex items-center gap-2 px-4 py-1.5 bg-[#F1C40F] !text-black text-sm font-bold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-60"
            >
              {save.isPending ? <RefreshCw size={12} className="animate-spin" /> : <Check size={12} />}
              {save.isPending ? "Saving…" : "Save"}
            </button>
          </div>
        )}

        {/* Theme color */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 space-y-4">
          <div>
            <h3 className="text-sm font-bold text-white">Primary Color</h3>
            <p className="text-xs text-zinc-500 mt-0.5">Buttons, accents and highlights in the member app</p>
          </div>
          <div className="flex flex-wrap gap-2.5">
            {PRESET_COLORS.map((c) => (
              <button
                key={c.value}
                onClick={() => pickColor(c.value)}
                title={c.label}
                className={clsx(
                  "w-8 h-8 rounded-full border-2 transition-all",
                  themeColor === c.value ? "border-white scale-110" : "border-transparent hover:scale-105"
                )}
                style={{ backgroundColor: c.value }}
              />
            ))}
          </div>
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-lg border border-zinc-700 flex-shrink-0" style={{ backgroundColor: customColor || "#3f3f46" }} />
            <div className="flex-1">
              <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1">Custom Hex</label>
              <input
                type="text"
                value={customColor}
                onChange={(e) => {
                  setCustomColor(e.target.value);
                  if (/^#[0-9A-Fa-f]{6}$/.test(e.target.value)) { setThemeColor(e.target.value); setDirty(true); }
                }}
                placeholder="#F1C40F"
                maxLength={7}
                className="w-full bg-zinc-800 border border-zinc-700 text-white text-sm font-mono rounded-lg px-3 py-2 focus:outline-none focus:border-[#F1C40F]"
              />
            </div>
            <input
              type="color"
              value={themeColor}
              onChange={(e) => pickColor(e.target.value)}
              className="w-10 h-10 rounded-lg border border-zinc-700 bg-zinc-800 cursor-pointer p-0.5"
            />
          </div>
        </div>

        {/* Welcome message */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 space-y-3">
          <div>
            <h3 className="text-sm font-bold text-white">Welcome Message</h3>
            <p className="text-xs text-zinc-500 mt-0.5">Short greeting shown to members when they open the app</p>
          </div>
          <textarea
            value={welcomeMessage}
            onChange={(e) => { setWelcomeMessage(e.target.value); setDirty(true); }}
            placeholder="Welcome! Book your next class and crush your goals."
            rows={3}
            maxLength={120}
            className="w-full bg-zinc-800 border border-zinc-700 text-white text-sm rounded-lg px-3 py-2.5 focus:outline-none focus:border-[#F1C40F] resize-none placeholder-zinc-600"
          />
          <p className="text-xs text-zinc-600 text-right">{welcomeMessage.length}/120</p>
        </div>

        <div className="bg-zinc-800/30 border border-zinc-700/50 rounded-xl p-4 text-xs text-zinc-500 flex items-start gap-3">
          <Smartphone size={14} className="text-zinc-400 flex-shrink-0 mt-0.5" />
          <p>Logo and banner images are updated from the <strong className="text-zinc-300">gym detail page</strong>.</p>
        </div>
      </div>

      {/* Preview */}
      <div className="lg:col-span-1 flex justify-center lg:justify-start lg:pt-10">
        <MobilePreview
          gymName={gymData?.name ?? "Your Gym"}
          themeColor={themeColor}
          welcomeMessage={welcomeMessage}
          logoUrl={gymData?.logoUrl}
        />
      </div>
    </div>
  );
}

// ─── WEBHOOKS TAB ─────────────────────────────────────────────────────────────

const EVENT_LABELS: Record<WebhookEvent, string> = {
  "member.created":          "Member Created",
  "member.cancelled":        "Member Cancelled",
  "membership.frozen":       "Membership Frozen",
  "membership.unfrozen":     "Membership Unfrozen",
  "payment.received":        "Payment Received",
  "session.created":         "Session Created",
  "session.cancelled":       "Session Cancelled",
  "checkin.recorded":        "Check-in Recorded",
  "support.ticket_created":  "Support Ticket Created",
};

const EVENT_CATEGORIES = [
  { label: "Members",     events: ["member.created", "member.cancelled"] as WebhookEvent[] },
  { label: "Memberships", events: ["membership.frozen", "membership.unfrozen"] as WebhookEvent[] },
  { label: "Payments",    events: ["payment.received"] as WebhookEvent[] },
  { label: "Sessions",    events: ["session.created", "session.cancelled"] as WebhookEvent[] },
  { label: "Operations",  events: ["checkin.recorded", "support.ticket_created"] as WebhookEvent[] },
];

function DeliveryHistory({
  gymId, endpoint, token, onClose,
}: {
  gymId: string;
  endpoint: WebhookEndpoint;
  token: string;
  onClose: () => void;
}) {
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ["webhook-deliveries", endpoint.id, page],
    queryFn: () => webhooksApi.getDeliveries(gymId, endpoint.id, page, token),
    enabled: !!token,
    staleTime: 10000,
  });

  const result = data?.data;
  const deliveries = result?.deliveries ?? [];

  return (
    <div className="fixed inset-0 z-50 flex">
      <div className="flex-1 bg-black/50" onClick={onClose} />
      <div className="w-full max-w-xl bg-[#121721] border-l border-zinc-800 flex flex-col h-full overflow-hidden">
        <div className="p-5 border-b border-zinc-800 flex items-center justify-between">
          <div>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Delivery History</p>
            <p className="text-sm text-white mt-0.5 font-medium truncate max-w-xs">{truncateUrl(endpoint.url)}</p>
          </div>
          <button onClick={onClose} className="p-2 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors">✕</button>
        </div>

        <div className="flex-1 overflow-y-auto">
          {isLoading ? (
            <div className="flex items-center justify-center py-16 text-zinc-500">
              <RefreshCw size={18} className="animate-spin mr-2" /> Loading…
            </div>
          ) : deliveries.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-16 text-zinc-500">
              <Webhook size={28} className="mb-2 opacity-30" />
              <p className="text-sm">No deliveries yet</p>
            </div>
          ) : (
            <div className="divide-y divide-zinc-800">
              {deliveries.map((d: WebhookDelivery) => (
                <div key={d.id} className="px-5 py-3 hover:bg-zinc-800/30 transition-colors">
                  <div className="flex items-center justify-between mb-1">
                    <div className="flex items-center gap-2">
                      {d.success
                        ? <CheckCircle size={13} className="text-green-400 flex-shrink-0" />
                        : <XCircle size={13} className="text-red-400 flex-shrink-0" />}
                      <span className="text-xs font-mono text-zinc-300">{d.event}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      {d.statusCode && (
                        <span className={clsx("text-[10px] font-bold px-1.5 py-0.5 rounded",
                          d.success ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400")}>
                          {d.statusCode}
                        </span>
                      )}
                      {d.duration && <span className="text-[10px] text-zinc-600">{d.duration}ms</span>}
                    </div>
                  </div>
                  <div className="flex justify-between items-center">
                    {d.responseBody && <span className="text-[11px] text-zinc-600 truncate max-w-xs">{d.responseBody}</span>}
                    <span className="text-[11px] text-zinc-600 ml-auto">{timeAgo(d.attemptedAt)}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {result && result.pages > 1 && (
          <div className="p-4 border-t border-zinc-800 flex items-center justify-between">
            <span className="text-xs text-zinc-500">{result.total} deliveries</span>
            <div className="flex gap-1">
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                className="p-1.5 rounded text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-40">
                <ChevronLeft size={14} />
              </button>
              <span className="px-2 py-1 text-xs text-zinc-400">{page}/{result.pages}</span>
              <button onClick={() => setPage(p => Math.min(result.pages, p + 1))} disabled={page === result.pages}
                className="p-1.5 rounded text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-40">
                <ChevronRight size={14} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function EndpointModal({
  gymId, token, endpoint, onClose,
}: {
  gymId: string;
  token: string;
  endpoint?: WebhookEndpoint;
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const isEdit = !!endpoint;
  const [url, setUrl] = useState(endpoint?.url ?? "");
  const [selectedEvents, setSelectedEvents] = useState<Set<string>>(new Set(endpoint?.events ?? []));

  const save = useMutation({
    mutationFn: () =>
      isEdit
        ? webhooksApi.update(gymId, endpoint!.id, { url, events: [...selectedEvents] }, token)
        : webhooksApi.create(gymId, { url, events: [...selectedEvents] }, token),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["webhooks", gymId] }); onClose(); },
  });

  const toggleEvent = (e: string) => { 
    const n = new Set(selectedEvents); 
    if (n.has(e)) n.delete(e); else n.add(e); 
    setSelectedEvents(n); 
  };
  const toggleCategory = (events: WebhookEvent[]) => {
    const all = events.every(e => selectedEvents.has(e));
    const n = new Set(selectedEvents);
    events.forEach(e => all ? n.delete(e) : n.add(e));
    setSelectedEvents(n);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div className="p-6 border-b border-zinc-800">
          <h2 className="text-lg font-bold text-white">{isEdit ? "Edit Endpoint" : "Add Endpoint"}</h2>
          <p className="text-xs text-zinc-500 mt-1">We&apos;ll POST signed JSON to your URL on each selected event.</p>
        </div>
        <div className="p-6 space-y-5">
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1.5">Endpoint URL</label>
            <input
              type="url"
              value={url}
              onChange={e => setUrl(e.target.value)}
              placeholder="https://your-server.com/webhooks/amirani"
              className="w-full bg-zinc-800 border border-zinc-700 text-white text-sm rounded-lg px-3 py-2.5 focus:outline-none focus:border-[#F1C40F] placeholder-zinc-600"
            />
          </div>
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">Subscribe to Events</label>
            <div className="space-y-3">
              {EVENT_CATEGORIES.map(cat => (
                <div key={cat.label}>
                  <button type="button" onClick={() => toggleCategory(cat.events)}
                    className="text-[10px] font-black uppercase tracking-widest text-zinc-600 hover:text-zinc-400 transition-colors mb-1.5 flex items-center gap-1">
                    {cat.label}
                    <span className="text-zinc-700">({cat.events.filter(e => selectedEvents.has(e)).length}/{cat.events.length})</span>
                  </button>
                  <div className="grid grid-cols-2 gap-1.5">
                    {cat.events.map(e => (
                      <button key={e} type="button" onClick={() => toggleEvent(e)}
                        className={clsx("flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium transition-colors text-left",
                          selectedEvents.has(e)
                            ? "bg-[#F1C40F]/10 text-[#F1C40F] border border-[#F1C40F]/20"
                            : "bg-zinc-800/50 text-zinc-400 hover:text-white border border-transparent")}>
                        <div className={clsx("w-1.5 h-1.5 rounded-full flex-shrink-0", selectedEvents.has(e) ? "bg-[#F1C40F]" : "bg-zinc-600")} />
                        {EVENT_LABELS[e as WebhookEvent]}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
        <div className="p-6 border-t border-zinc-800 flex justify-end gap-3">
          <button onClick={onClose} className="px-4 py-2 text-sm text-zinc-400 hover:text-white transition-colors">Cancel</button>
          <button onClick={() => save.mutate()} disabled={!url || selectedEvents.size === 0 || save.isPending}
            className="px-5 py-2 bg-[#F1C40F] !text-black text-sm font-bold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed">
            {save.isPending ? "Saving…" : isEdit ? "Save Changes" : "Create Endpoint"}
          </button>
        </div>
      </div>
    </div>
  );
}

function EndpointCard({
  gymId, token, ep, onViewHistory, onEdit,
}: {
  gymId: string;
  token: string;
  ep: WebhookEndpoint;
  onViewHistory: () => void;
  onEdit: () => void;
}) {
  const qc = useQueryClient();
  const [showSecret, setShowSecret] = useState(false);

  const toggle = useMutation({
    mutationFn: () => webhooksApi.update(gymId, ep.id, { isActive: !ep.isActive }, token),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["webhooks", gymId] }),
  });
  const rotate = useMutation({
    mutationFn: () => webhooksApi.rotateSecret(gymId, ep.id, token),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["webhooks", gymId] }),
  });
  const del = useMutation({
    mutationFn: () => webhooksApi.delete(gymId, ep.id, token),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["webhooks", gymId] }),
  });

  return (
    <div className={clsx("bg-zinc-900 border rounded-xl p-5 space-y-4 transition-opacity",
      ep.isActive ? "border-zinc-800" : "border-zinc-800/50 opacity-60")}>
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <div className={clsx("w-2 h-2 rounded-full flex-shrink-0", ep.isActive ? "bg-green-500" : "bg-zinc-600")} />
            <p className="text-sm font-medium text-white truncate">{truncateUrl(ep.url)}</p>
          </div>
          <p className="text-[11px] text-zinc-500 mt-1 ml-4">{ep._count.deliveries} deliveries · {timeAgo(ep.createdAt)}</p>
        </div>
        <div className="flex items-center gap-1 flex-shrink-0">
          <button onClick={onEdit} className="px-2 py-1.5 text-xs font-medium text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors">Edit</button>
          <button onClick={() => toggle.mutate()} disabled={toggle.isPending}
            className="p-1.5 text-zinc-500 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors"
            title={ep.isActive ? "Disable" : "Enable"}>
            {ep.isActive ? <ToggleRight size={16} className="text-green-400" /> : <ToggleLeft size={16} />}
          </button>
          <button onClick={() => { if (confirm("Delete this endpoint?")) del.mutate(); }}
            disabled={del.isPending}
            className="p-1.5 text-zinc-500 hover:text-red-400 hover:bg-zinc-800 rounded-lg transition-colors">
            <Trash2 size={14} />
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-1.5">
        {ep.events.map(e => (
          <span key={e} className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400">{e}</span>
        ))}
      </div>

      <div className="flex items-center gap-2 bg-zinc-800/50 rounded-lg px-3 py-2">
        <span className="text-[10px] font-black uppercase tracking-widest text-zinc-600 flex-shrink-0">Secret</span>
        <span className="text-xs font-mono text-zinc-400 flex-1 truncate">
          {showSecret ? ep.secret : "••••••••••••••••••••••••"}
        </span>
        <button onClick={() => setShowSecret(!showSecret)} className="p-1 text-zinc-500 hover:text-white transition-colors">
          {showSecret ? <EyeOff size={12} /> : <Eye size={12} />}
        </button>
        {showSecret && <CopyButton value={ep.secret} />}
        <button
          onClick={() => { if (confirm("Rotate signing secret? All existing integrations must be updated.")) rotate.mutate(); }}
          disabled={rotate.isPending}
          className="p-1 text-zinc-500 hover:text-[#F1C40F] transition-colors"
          title="Rotate secret"
        >
          <RotateCcw size={12} className={rotate.isPending ? "animate-spin" : ""} />
        </button>
      </div>

      <button onClick={onViewHistory} className="w-full text-center text-xs text-zinc-500 hover:text-[#F1C40F] transition-colors py-1">
        View delivery history →
      </button>
    </div>
  );
}

function WebhooksTab({ gymId, token }: { gymId: string; token: string }) {
  const [showCreate, setShowCreate] = useState(false);
  const [editEndpoint, setEditEndpoint] = useState<WebhookEndpoint | null>(null);
  const [historyEndpoint, setHistoryEndpoint] = useState<WebhookEndpoint | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["webhooks", gymId],
    queryFn: () => webhooksApi.list(gymId, token),
    enabled: !!token,
    staleTime: 30000,
  });

  const endpoints = data?.data ?? [];
  const activeCount = endpoints.filter(e => e.isActive).length;

  return (
    <div className="space-y-5">
      {/* Stats + Add button */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          {[
            { label: "Endpoints", value: endpoints.length },
            { label: "Active", value: activeCount },
            { label: "Events Available", value: WEBHOOK_EVENTS.length },
          ].map(s => (
            <div key={s.label} className="text-center">
              <p className="text-xl font-bold text-white">{s.value}</p>
              <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">{s.label}</p>
            </div>
          ))}
        </div>
        <button onClick={() => setShowCreate(true)}
          className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0">
          <Plus size={18} /> Add Endpoint
        </button>
      </div>

      {/* Signature info */}
      <div className="bg-zinc-800/30 border border-zinc-700/50 rounded-xl p-4 text-sm text-zinc-400 space-y-1">
        <p className="text-white font-medium text-sm">Verifying signatures</p>
        <p>Each request includes <span className="font-mono text-zinc-300">X-Amirani-Signature: sha256=…</span></p>
        <p>Verify: <span className="font-mono text-zinc-300">HMAC-SHA256(secret, rawBody)</span> matches the header.</p>
      </div>

      {/* Endpoint list */}
      {isLoading ? (
        <div className="flex items-center justify-center py-16 text-zinc-500">
          <RefreshCw size={18} className="animate-spin mr-2" /> Loading…
        </div>
      ) : endpoints.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 bg-zinc-900 border border-zinc-800 rounded-xl text-zinc-500">
          <Webhook size={32} className="mb-3 opacity-20" />
          <p className="text-sm">No endpoints yet</p>
          <p className="text-xs mt-1">Add your first endpoint to start receiving events</p>
          <button onClick={() => setShowCreate(true)}
            className="mt-4 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium rounded-lg transition-colors">
            Add Endpoint
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {endpoints.map(ep => (
            <EndpointCard
              key={ep.id}
              gymId={gymId}
              token={token}
              ep={ep}
              onViewHistory={() => setHistoryEndpoint(ep)}
              onEdit={() => setEditEndpoint(ep)}
            />
          ))}
        </div>
      )}

      {(showCreate || editEndpoint) && (
        <EndpointModal
          gymId={gymId}
          token={token}
          endpoint={editEndpoint ?? undefined}
          onClose={() => { setShowCreate(false); setEditEndpoint(null); }}
        />
      )}
      {historyEndpoint && (
        <DeliveryHistory
          gymId={gymId}
          token={token}
          endpoint={historyEndpoint}
          onClose={() => setHistoryEndpoint(null)}
        />
      )}
    </div>
  );
}

// ─── LANGUAGE TAB ────────────────────────────────────────────────────────────

interface LanguagePack {
  code: string;
  displayName: string;
  englishName: string;
  countryCode: string;
  isPublished: boolean;
}

function langFlag(code: string, countryCode?: string): string {
  const country = (countryCode || code).toUpperCase().slice(0, 2);
  if (country.length !== 2) return "🌐";
  const cp = (c: string) => 0x1f1e6 + c.charCodeAt(0) - 65;
  return String.fromCodePoint(cp(country[0]), cp(country[1]));
}

function LanguageTab({ gymId, token }: { gymId: string; token: string }) {
  const qc = useQueryClient();

  const { data: gymData } = useQuery({
    queryKey: ["gym", gymId],
    queryFn: () => gymsApi.getById(gymId, token),
    enabled: !!token,
  });

  const { data: packsRes, isLoading: packsLoading } = useQuery({
    queryKey: ["language-packs-published"],
    queryFn: async () => {
      const res = await api<{ packs: LanguagePack[] }>("/admin/language-packs", { token });
      return res.packs.filter(p => p.isPublished);
    },
    enabled: !!token,
  });

  const publishedPacks = packsRes ?? [];
  const currentCode: string = (gymData as { languageCode?: string })?.languageCode ?? "en";
  const [selected, setSelected] = useState<string>(currentCode);
  const [dirty, setDirty] = useState(false);

  // Sync from server when gymData arrives
  const [prevGym, setPrevGym] = useState(gymData);
  if (gymData !== prevGym) {
    setPrevGym(gymData);
    if (!dirty) setSelected((gymData as { languageCode?: string })?.languageCode ?? "en");
  }

  const save = useMutation({
    mutationFn: () =>
      api(`/admin/gyms/${gymId}/language`, {
        method: "PUT",
        body: { languageCode: selected },
        token,
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["gym", gymId] });
      setDirty(false);
    },
  });

  const currentPack = publishedPacks.find(p => p.code === selected);
  const englishOption = { code: "en", displayName: "English", englishName: "English", countryCode: "gb", isPublished: true };
  const allOptions = [englishOption, ...publishedPacks];

  return (
    <div className="max-w-xl space-y-6">
      {dirty && (
        <div className="flex items-center justify-between bg-[#F1C40F]/10 border border-[#F1C40F]/30 rounded-xl px-5 py-3">
          <p className="text-sm text-[#F1C40F] font-medium">You have unsaved changes</p>
          <button
            onClick={() => save.mutate()}
            disabled={save.isPending}
            className="flex items-center gap-2 px-4 py-1.5 bg-[#F1C40F] !text-black text-sm font-bold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-60"
          >
            {save.isPending ? <RefreshCw size={12} className="animate-spin" /> : <Check size={12} />}
            {save.isPending ? "Saving…" : "Save"}
          </button>
        </div>
      )}

      <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-5 space-y-4">
        <div>
          <h3 className="text-sm font-bold text-white">App Language</h3>
          <p className="text-xs text-zinc-500 mt-0.5">
            The language members see in the mobile app. Only published packs are available.
          </p>
        </div>

        {/* Current selection preview */}
        <div className="flex items-center gap-3 bg-zinc-800/60 rounded-xl px-4 py-3">
          <span className="text-3xl leading-none">
            {langFlag(selected, currentPack?.countryCode ?? (selected === "en" ? "gb" : selected))}
          </span>
          <div>
            <p className="text-sm font-semibold text-white">
              {currentPack?.displayName ?? "English"}
            </p>
            <p className="text-[10px] text-zinc-500 font-mono uppercase">{selected}</p>
          </div>
        </div>

        {/* Pack picker grid */}
        {packsLoading ? (
          <div className="flex items-center gap-2 text-zinc-500 text-sm py-4">
            <RefreshCw size={14} className="animate-spin" /> Loading published packs…
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
            {allOptions.map(pack => {
              const isSelected = selected === pack.code;
              return (
                <button
                  key={pack.code}
                  onClick={() => { setSelected(pack.code); setDirty(pack.code !== currentCode); }}
                  className={clsx(
                    "flex items-center gap-2.5 px-3 py-2.5 rounded-xl border text-left transition-all",
                    isSelected
                      ? "bg-[#F1C40F]/10 border-[#F1C40F]/40 text-[#F1C40F]"
                      : "bg-zinc-800/40 border-zinc-700/50 text-zinc-400 hover:border-zinc-600 hover:text-white"
                  )}
                >
                  <span className="text-xl leading-none">
                    {langFlag(pack.code, pack.countryCode)}
                  </span>
                  <div className="min-w-0">
                    <p className="text-xs font-semibold truncate">{pack.displayName}</p>
                    <p className="text-[10px] font-mono text-zinc-500">{pack.code}</p>
                  </div>
                  {isSelected && <Check size={12} className="ml-auto flex-shrink-0" />}
                </button>
              );
            })}
          </div>
        )}

        {publishedPacks.length === 0 && !packsLoading && (
          <div className="flex items-center gap-2 text-xs text-zinc-500 bg-zinc-800/30 rounded-xl px-4 py-3">
            <Globe size={14} />
            No additional language packs published yet. Go to{" "}
            <a href="/dashboard/language-packs" className="text-[#F1C40F] hover:underline ml-1">
              Language Packs →
            </a>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

const TABS: { id: Tab; label: string; icon: React.ElementType; desc: string }[] = [
  { id: "branding",  label: "Branding",    icon: Palette,   desc: "App colors and welcome message" },
  { id: "language",  label: "Language",    icon: Languages, desc: "Member app language pack" },
  { id: "webhooks",  label: "Webhooks",    icon: Webhook,   desc: "HTTP event integrations" },
];

export default function SettingsPage() {
  const { gymId } = useParams<{ gymId: string }>();
  const { token } = useAuthStore();
  const [tab, setTab] = useState<Tab>("branding");

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Facility Settings"
        description="Customize your facility's appearance and integrations"
        icon={<Settings size={24} />}
      />

      {/* Tab bar */}
      <div className="flex gap-2">
        {TABS.map(t => {
          const Icon = t.icon;
          return (
            <button
              key={t.id}
              onClick={() => setTab(t.id)}
              className={clsx(
                "flex items-center gap-2.5 px-5 py-2.5 rounded-xl text-sm font-medium transition-all border",
                tab === t.id
                  ? "bg-[#F1C40F]/10 text-[#F1C40F] border-[#F1C40F]/30"
                  : "text-zinc-400 hover:text-white border-transparent hover:bg-zinc-800"
              )}
            >
              <Icon size={15} />
              {t.label}
            </button>
          );
        })}
      </div>

      {/* Content */}
      {tab === "branding"  && <BrandingTab  gymId={gymId} token={token!} />}
      {tab === "language"  && <LanguageTab  gymId={gymId} token={token!} />}
      {tab === "webhooks"  && <WebhooksTab  gymId={gymId} token={token!} />}
    </div>
  );
}

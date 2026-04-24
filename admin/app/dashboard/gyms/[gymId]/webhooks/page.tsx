"use client";

import { useState } from "react";
import { useParams } from "next/navigation";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import {
  webhooksApi,
  WebhookEndpoint,
  WebhookDelivery,
  WEBHOOK_EVENTS,
  WebhookEvent,
} from "@/lib/api";
import {
  Webhook,
  Plus,
  Trash2,
  RefreshCw,
  Eye,
  EyeOff,
  ChevronLeft,
  ChevronRight,
  CheckCircle,
  XCircle,
  RotateCcw,
  Copy,
  Check,
  ToggleLeft,
  ToggleRight,
} from "lucide-react";
import { PageHeader } from "@/components/ui/PageHeader";
import clsx from "clsx";

// ─── Event metadata ───────────────────────────────────────────────────────────

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
  { label: "Members",    events: ["member.created", "member.cancelled"] as WebhookEvent[] },
  { label: "Memberships", events: ["membership.frozen", "membership.unfrozen"] as WebhookEvent[] },
  { label: "Payments",   events: ["payment.received"] as WebhookEvent[] },
  { label: "Sessions",   events: ["session.created", "session.cancelled"] as WebhookEvent[] },
  { label: "Operations", events: ["checkin.recorded", "support.ticket_created"] as WebhookEvent[] },
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

function truncateUrl(url: string, max = 45) {
  return url.length > max ? url.slice(0, max) + "…" : url;
}

// ─── Copy Button ──────────────────────────────────────────────────────────────

function CopyButton({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);
  const copy = () => {
    navigator.clipboard.writeText(value);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <button onClick={copy} className="p-1 text-zinc-500 hover:text-white transition-colors">
      {copied ? <Check size={12} className="text-green-400" /> : <Copy size={12} />}
    </button>
  );
}

// ─── Delivery History Sheet ───────────────────────────────────────────────────

function DeliveryHistory({
  gymId, endpoint, onClose,
}: {
  gymId: string;
  endpoint: WebhookEndpoint;
  onClose: () => void;
}) {
  const { token } = useAuthStore();
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ["webhook-deliveries", endpoint.id, page],
    queryFn: () => webhooksApi.getDeliveries(gymId, endpoint.id, page, token!),
    enabled: !!token,
    staleTime: 10000,
  });

  const result = data?.data;
  const deliveries = result?.deliveries ?? [];

  return (
    <div className="fixed inset-0 z-50 flex">
      <div className="flex-1 bg-black/50" onClick={onClose} />
      <div className="w-full max-w-xl bg-[#121721] border-l border-zinc-800 flex flex-col h-full overflow-hidden">
        {/* Header */}
        <div className="p-5 border-b border-zinc-800">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500">Delivery History</p>
              <p className="text-sm text-white mt-0.5 font-medium truncate max-w-xs">{truncateUrl(endpoint.url)}</p>
            </div>
            <button onClick={onClose} className="p-2 text-zinc-400 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors">
              ✕
            </button>
          </div>
        </div>

        {/* List */}
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
                        <span className={clsx(
                          "text-[10px] font-bold px-1.5 py-0.5 rounded",
                          d.success ? "bg-green-500/10 text-green-400" : "bg-red-500/10 text-red-400"
                        )}>
                          {d.statusCode}
                        </span>
                      )}
                      {d.duration && (
                        <span className="text-[10px] text-zinc-600">{d.duration}ms</span>
                      )}
                    </div>
                  </div>
                  <div className="flex justify-between items-center">
                    {d.responseBody && (
                      <span className="text-[11px] text-zinc-600 truncate max-w-xs">{d.responseBody}</span>
                    )}
                    <span className="text-[11px] text-zinc-600 ml-auto">{timeAgo(d.attemptedAt)}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Pagination */}
        {result && result.pages > 1 && (
          <div className="p-4 border-t border-zinc-800 flex items-center justify-between">
            <span className="text-xs text-zinc-500">{result.total} deliveries</span>
            <div className="flex gap-1">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page === 1}
                className="p-1.5 rounded text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-40"
              >
                <ChevronLeft size={14} />
              </button>
              <span className="px-2 py-1 text-xs text-zinc-400">{page}/{result.pages}</span>
              <button
                onClick={() => setPage((p) => Math.min(result.pages, p + 1))}
                disabled={page === result.pages}
                className="p-1.5 rounded text-zinc-400 hover:text-white hover:bg-zinc-800 transition-colors disabled:opacity-40"
              >
                <ChevronRight size={14} />
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Create/Edit Modal ────────────────────────────────────────────────────────

function EndpointModal({
  gymId,
  endpoint,
  onClose,
}: {
  gymId: string;
  endpoint?: WebhookEndpoint;
  onClose: () => void;
}) {
  const { token } = useAuthStore();
  const qc = useQueryClient();
  const isEdit = !!endpoint;

  const [url, setUrl] = useState(endpoint?.url ?? "");
  const [selectedEvents, setSelectedEvents] = useState<Set<string>>(
    new Set(endpoint?.events ?? [])
  );

  const save = useMutation({
    mutationFn: () =>
      isEdit
        ? webhooksApi.update(gymId, endpoint!.id, { url, events: [...selectedEvents] }, token!)
        : webhooksApi.create(gymId, { url, events: [...selectedEvents] }, token!),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["webhooks", gymId] });
      onClose();
    },
  });

  const toggleEvent = (e: string) => {
    const next = new Set(selectedEvents);
    if (next.has(e)) {
      next.delete(e);
    } else {
      next.add(e);
    }
    setSelectedEvents(next);
  };

  const toggleCategory = (events: WebhookEvent[]) => {
    const allSelected = events.every((e) => selectedEvents.has(e));
    const next = new Set(selectedEvents);
    events.forEach((e) => allSelected ? next.delete(e) : next.add(e));
    setSelectedEvents(next);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60">
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl w-full max-w-lg">
        <div className="p-6 border-b border-zinc-800">
          <h2 className="text-lg font-bold text-white">{isEdit ? "Edit Endpoint" : "Add Endpoint"}</h2>
          <p className="text-xs text-zinc-500 mt-1">We&apos;ll POST signed JSON to your URL on each event.</p>
        </div>

        <div className="p-6 space-y-5">
          {/* URL */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-1.5">
              Endpoint URL
            </label>
            <input
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="https://your-server.com/webhooks/amirani"
              className="w-full bg-zinc-800 border border-zinc-700 text-white text-sm rounded-lg px-3 py-2.5 focus:outline-none focus:border-[#F1C40F] placeholder-zinc-600"
            />
          </div>

          {/* Events */}
          <div>
            <label className="block text-[10px] font-black uppercase tracking-widest text-zinc-500 mb-3">
              Subscribe to Events
            </label>
            <div className="space-y-3">
              {EVENT_CATEGORIES.map((cat) => (
                <div key={cat.label}>
                  <button
                    type="button"
                    onClick={() => toggleCategory(cat.events)}
                    className="text-[10px] font-black uppercase tracking-widest text-zinc-600 hover:text-zinc-400 transition-colors mb-1.5 flex items-center gap-1"
                  >
                    {cat.label}
                    <span className="text-zinc-700">
                      ({cat.events.filter((e) => selectedEvents.has(e)).length}/{cat.events.length})
                    </span>
                  </button>
                  <div className="grid grid-cols-2 gap-1.5">
                    {cat.events.map((e) => (
                      <button
                        key={e}
                        type="button"
                        onClick={() => toggleEvent(e)}
                        className={clsx(
                          "flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium transition-colors text-left",
                          selectedEvents.has(e)
                            ? "bg-[#F1C40F]/10 text-[#F1C40F] border border-[#F1C40F]/20"
                            : "bg-zinc-800/50 text-zinc-400 hover:text-white border border-transparent"
                        )}
                      >
                        <div className={clsx(
                          "w-1.5 h-1.5 rounded-full flex-shrink-0",
                          selectedEvents.has(e) ? "bg-[#F1C40F]" : "bg-zinc-600"
                        )} />
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
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm text-zinc-400 hover:text-white transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={() => save.mutate()}
            disabled={!url || selectedEvents.size === 0 || save.isPending}
            className="px-5 py-2 bg-[#F1C40F] !text-black text-sm font-bold rounded-lg hover:bg-yellow-400 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {save.isPending ? "Saving…" : isEdit ? "Save Changes" : "Create Endpoint"}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Endpoint Card ────────────────────────────────────────────────────────────

function EndpointCard({
  gymId,
  ep,
  onViewHistory,
  onEdit,
}: {
  gymId: string;
  ep: WebhookEndpoint;
  onViewHistory: () => void;
  onEdit: () => void;
}) {
  const { token } = useAuthStore();
  const qc = useQueryClient();
  const [showSecret, setShowSecret] = useState(false);

  const toggle = useMutation({
    mutationFn: () => webhooksApi.update(gymId, ep.id, { isActive: !ep.isActive }, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["webhooks", gymId] }),
  });

  const rotate = useMutation({
    mutationFn: () => webhooksApi.rotateSecret(gymId, ep.id, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["webhooks", gymId] }),
  });

  const del = useMutation({
    mutationFn: () => webhooksApi.delete(gymId, ep.id, token!),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["webhooks", gymId] }),
  });

  return (
    <div className={clsx(
      "bg-zinc-900 border rounded-xl p-5 space-y-4 transition-colors",
      ep.isActive ? "border-zinc-800" : "border-zinc-800/50 opacity-60"
    )}>
      {/* Top row */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <div className={clsx("w-2 h-2 rounded-full flex-shrink-0", ep.isActive ? "bg-green-500" : "bg-zinc-600")} />
            <p className="text-sm font-medium text-white truncate">{truncateUrl(ep.url, 50)}</p>
          </div>
          <p className="text-[11px] text-zinc-500 mt-1">
            {ep._count.deliveries} deliveries · created {timeAgo(ep.createdAt)}
          </p>
        </div>
        <div className="flex items-center gap-1 flex-shrink-0">
          <button
            onClick={onEdit}
            className="p-1.5 text-zinc-500 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors text-xs font-medium px-2"
          >
            Edit
          </button>
          <button
            onClick={() => toggle.mutate()}
            disabled={toggle.isPending}
            className="p-1.5 text-zinc-500 hover:text-white hover:bg-zinc-800 rounded-lg transition-colors"
            title={ep.isActive ? "Disable" : "Enable"}
          >
            {ep.isActive ? <ToggleRight size={16} className="text-green-400" /> : <ToggleLeft size={16} />}
          </button>
          <button
            onClick={() => { if (confirm("Delete this endpoint?")) del.mutate(); }}
            disabled={del.isPending}
            className="p-1.5 text-zinc-500 hover:text-red-400 hover:bg-zinc-800 rounded-lg transition-colors"
          >
            <Trash2 size={14} />
          </button>
        </div>
      </div>

      {/* Events */}
      <div className="flex flex-wrap gap-1.5">
        {ep.events.map((e) => (
          <span key={e} className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-zinc-800 text-zinc-400">
            {e}
          </span>
        ))}
      </div>

      {/* Secret */}
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
          onClick={() => { if (confirm("Rotate signing secret? All existing integrations will need to be updated.")) rotate.mutate(); }}
          disabled={rotate.isPending}
          className="p-1 text-zinc-500 hover:text-yellow-400 transition-colors"
          title="Rotate secret"
        >
          <RotateCcw size={12} className={rotate.isPending ? "animate-spin" : ""} />
        </button>
      </div>

      {/* Footer */}
      <button
        onClick={onViewHistory}
        className="w-full text-center text-xs text-zinc-500 hover:text-[#F1C40F] transition-colors py-1"
      >
        View delivery history →
      </button>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function WebhooksPage() {
  const { gymId } = useParams<{ gymId: string }>();
  const { token } = useAuthStore();
  const [showCreate, setShowCreate] = useState(false);
  const [editEndpoint, setEditEndpoint] = useState<WebhookEndpoint | null>(null);
  const [historyEndpoint, setHistoryEndpoint] = useState<WebhookEndpoint | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["webhooks", gymId],
    queryFn: () => webhooksApi.list(gymId, token!),
    enabled: !!token,
    staleTime: 30000,
  });

  const endpoints = data?.data ?? [];
  const activeCount = endpoints.filter((e) => e.isActive).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <PageHeader
        title="Webhooks"
        description="Receive real-time HTTP callbacks when events happen at your facility"
        icon={<Webhook size={24} />}
        actions={
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-4 py-2 bg-[#F1C40F] !text-black text-sm font-bold rounded-lg hover:bg-yellow-400 transition-colors"
          >
            <Plus size={16} />
            Add Endpoint
          </button>
        }
      />

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "Endpoints", value: endpoints.length },
          { label: "Active", value: activeCount },
          { label: "Total Events", value: WEBHOOK_EVENTS.length },
        ].map((s) => (
          <div key={s.label} className="bg-zinc-900 border border-zinc-800 rounded-xl p-4 text-center">
            <p className="text-2xl font-bold text-white">{s.value}</p>
            <p className="text-[10px] font-black uppercase tracking-widest text-zinc-500 mt-1">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Signing info */}
      <div className="bg-zinc-800/30 border border-zinc-700/50 rounded-xl p-4 text-sm text-zinc-400 space-y-1">
        <p className="text-white font-medium text-sm">Verifying signatures</p>
        <p>Each request includes <span className="font-mono text-zinc-300">X-Amirani-Signature: sha256=...</span></p>
        <p>Verify: <span className="font-mono text-zinc-300">HMAC-SHA256(secret, rawBody)</span> matches the header value.</p>
      </div>

      {/* Endpoints */}
      {isLoading ? (
        <div className="flex items-center justify-center py-16 text-zinc-500">
          <RefreshCw size={18} className="animate-spin mr-2" /> Loading…
        </div>
      ) : endpoints.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 bg-zinc-900 border border-zinc-800 rounded-xl text-zinc-500">
          <Webhook size={36} className="mb-3 opacity-20" />
          <p className="text-sm">No endpoints yet</p>
          <p className="text-xs mt-1">Add your first endpoint to start receiving events</p>
          <button
            onClick={() => setShowCreate(true)}
            className="mt-4 px-4 py-2 bg-zinc-800 hover:bg-zinc-700 text-white text-sm font-medium rounded-lg transition-colors"
          >
            Add Endpoint
          </button>
        </div>
      ) : (
        <div className="space-y-4">
          {endpoints.map((ep) => (
            <EndpointCard
              key={ep.id}
              gymId={gymId}
              ep={ep}
              onViewHistory={() => setHistoryEndpoint(ep)}
              onEdit={() => setEditEndpoint(ep)}
            />
          ))}
        </div>
      )}

      {/* Modals */}
      {(showCreate || editEndpoint) && (
        <EndpointModal
          gymId={gymId}
          endpoint={editEndpoint ?? undefined}
          onClose={() => { setShowCreate(false); setEditEndpoint(null); }}
        />
      )}
      {historyEndpoint && (
        <DeliveryHistory
          gymId={gymId}
          endpoint={historyEndpoint}
          onClose={() => setHistoryEndpoint(null)}
        />
      )}
    </div>
  );
}

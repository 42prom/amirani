"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuthStore } from "@/lib/auth-store";
import { useGymSelection } from "@/hooks/useGymSelection";
import { GymSwitcher } from "@/components/GymSwitcher";
import {
  automationsApi,
  AutomationRule,
  AutomationTrigger,
  CreateAutomationRuleData,
  TRIGGER_LABELS,
  TRIGGER_DESCRIPTIONS,
} from "@/lib/api";
import { CustomSelect } from "@/components/ui/Select";
import { PageHeader } from "@/components/ui/PageHeader";
import {
  Zap,
  Plus,
  Play,
  Pause,
  Trash2,
  Edit2,
  RotateCcw,
  CheckCircle2,
  Clock,
  Send,
  X,
  Smartphone,
  Bell,
  Mail,
  Loader2,
} from "lucide-react";
import clsx from "clsx";

const ALL_TRIGGERS = Object.keys(TRIGGER_LABELS) as AutomationTrigger[];

const TRIGGER_CATEGORY: Record<AutomationTrigger, "retention" | "expiry" | "onboarding"> = {
  INACTIVE_14D:   "retention",
  INACTIVE_30D:   "retention",
  EXPIRY_5D:      "expiry",
  EXPIRY_1D:      "expiry",
  JUST_EXPIRED:   "expiry",
  NEW_MEMBER_DAY1: "onboarding",
  NEW_MEMBER_DAY3: "onboarding",
  NEW_MEMBER_DAY7: "onboarding",
};

const CATEGORY_COLORS = {
  retention:  { bg: "bg-orange-500/10", text: "text-orange-400", border: "border-orange-500/20" },
  expiry:     { bg: "bg-red-500/10",    text: "text-red-400",    border: "border-red-500/20" },
  onboarding: { bg: "bg-green-500/10",  text: "text-green-400",  border: "border-green-500/20" },
};

const CATEGORY_LABELS = {
  retention:  "Retention",
  onboarding: "Onboarding",
  expiry:     "Expiry",
};

// ─── RuleCard ─────────────────────────────────────────────────────────────────

function RuleCard({
  rule,
  onEdit,
  onToggle,
  onDelete,
  onRunNow,
}: {
  rule: AutomationRule;
  onEdit: (r: AutomationRule) => void;
  onToggle: (r: AutomationRule) => void;
  onDelete: (r: AutomationRule) => void;
  onRunNow: (r: AutomationRule) => void;
}) {
  const cat = TRIGGER_CATEGORY[rule.trigger];
  const colors = CATEGORY_COLORS[cat];

  return (
    <div
      className={clsx(
        "bg-[#121721] border border-white/5 rounded-3xl p-6 space-y-4 hover:border-white/10 transition-all group overflow-hidden relative shadow-xl",
        rule.isActive ? "" : "opacity-60 grayscale-[0.5]"
      )}
    >
      <div className="absolute top-0 right-0 w-24 h-24 bg-white/[0.02] rounded-full -mr-12 -mt-12 transition-transform group-hover:scale-110" />
      
      {/* Header */}
      <div className="flex items-start justify-between gap-3 relative z-10">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 flex-wrap mb-2">
            <span className={clsx("text-[10px] font-black uppercase tracking-[0.1em] px-2 py-0.5 rounded-md border", colors.bg, colors.text, colors.border)}>
              {CATEGORY_LABELS[cat]}
            </span>
            {rule.isActive ? (
              <span className="flex items-center gap-1 text-[10px] font-black uppercase tracking-[0.1em] text-green-400">
                <CheckCircle2 size={10} /> Active
              </span>
            ) : (
              <span className="text-[10px] font-black uppercase tracking-[0.1em] text-zinc-500">Paused</span>
            )}
          </div>
          <p className="text-xl font-black text-white tracking-tight leading-tight group-hover:text-[#F1C40F] transition-colors line-clamp-2">{rule.name}</p>
          <p className="text-xs text-zinc-500 mt-2 font-medium flex items-center gap-2">
            <Zap size={12} className="text-[#F1C40F]" />
            {TRIGGER_LABELS[rule.trigger]}
          </p>
        </div>

        <div className="flex items-center gap-1.5 shrink-0">
          <button
            onClick={() => onRunNow(rule)}
            title="Run now (24h window)"
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-[#F1C40F] hover:bg-[#F1C40F]/10 rounded-2xl transition-all border border-white/5"
          >
            <RotateCcw size={16} />
          </button>
          <button
            onClick={() => onEdit(rule)}
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-white hover:bg-white/[0.08] rounded-2xl transition-all border border-white/5"
          >
            <Edit2 size={16} />
          </button>
          <button
            onClick={() => onToggle(rule)}
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-[#F1C40F] hover:bg-white/[0.08] rounded-2xl transition-all border border-white/5"
          >
            {rule.isActive ? <Pause size={16} /> : <Play size={16} />}
          </button>
          <button
            onClick={() => onDelete(rule)}
            className="p-3 bg-white/[0.03] text-zinc-500 hover:text-red-400 hover:bg-red-500/10 rounded-2xl transition-all border border-white/5"
          >
            <Trash2 size={16} />
          </button>
        </div>
      </div>

      {/* Message preview */}
      <div className="relative z-10">
        <p className="text-sm text-zinc-400 line-clamp-2 bg-white/[0.03] border border-white/5 rounded-2xl px-4 py-3 leading-relaxed font-medium group-hover:bg-white/[0.05] transition-colors">
          {rule.body}
        </p>
      </div>

      {/* Footer stats */}
      <div className="flex items-center justify-between pt-4 border-t border-white/5 relative z-10">
        <div className="flex items-center gap-4 text-[10px] font-black text-zinc-500 uppercase tracking-widest">
          <span className="flex items-center gap-1.5">
            <Send size={12} className="text-[#F1C40F]" />
            {rule.totalFired.toLocaleString()} sent
          </span>
          {rule.lastRunAt && (
            <span className="flex items-center gap-1.5 border-l border-white/5 pl-4">
              <Clock size={12} className="text-[#F1C40F]" />
              Last: {new Date(rule.lastRunAt).toLocaleDateString()}
            </span>
          )}
        </div>
        <div className="flex gap-1.5">
          {rule.channels.map((ch) => (
            <span key={ch} className="bg-white/[0.03] text-zinc-500 px-2 py-0.5 rounded-md text-[9px] font-black uppercase tracking-widest border border-white/5">
              {ch}
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── RuleModal ────────────────────────────────────────────────────────────────

function RuleModal({
  rule,
  onClose,
  onSave,
  loading,
}: {
  rule: AutomationRule | null; // null = create mode
  onClose: () => void;
  onSave: (data: CreateAutomationRuleData) => void;
  loading: boolean;
}) {
  const [form, setForm] = useState<CreateAutomationRuleData>({
    name: rule?.name ?? "",
    trigger: rule?.trigger ?? "INACTIVE_14D",
    subject: rule?.subject ?? "",
    body: rule?.body ?? "",
    channels: rule?.channels ?? ["PUSH", "IN_APP"],
  });

  const toggleChannel = (ch: string) => {
    setForm((f) => ({
      ...f,
      channels: f.channels.includes(ch)
        ? f.channels.filter((c) => c !== ch)
        : [...f.channels, ch],
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
              <Zap className="text-[#F1C40F]" size={24} />
              {rule ? "Edit Automation Rule" : "New Automation Rule"}
            </h2>
            <p className="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em] mt-1">
              Rules run automatically hourly based on conditions
            </p>
          </div>
          <button onClick={onClose} className="p-3 hover:bg-red-500/10 rounded-2xl text-zinc-500 hover:text-red-400 transition-all border border-white/5">
            <X size={20} />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto amirani-scrollbar p-8 space-y-6">
          {/* Trigger (only for create) */}
          {!rule && (
            <div>
              <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Trigger *</label>
              <div className="space-y-4">
                <CustomSelect
                  value={form.trigger}
                  onChange={(val) => {
                    const t = val as AutomationTrigger;
                    setForm((f) => ({
                      ...f,
                      trigger: t,
                      name: f.name || TRIGGER_LABELS[t],
                    }));
                  }}
                  options={ALL_TRIGGERS.map((t) => ({
                    value: t,
                    label: TRIGGER_LABELS[t],
                  }))}
                />
              </div>
              <p className="text-[11px] text-zinc-500 mt-2 px-1">
                {TRIGGER_DESCRIPTIONS[form.trigger]}
              </p>
            </div>
          )}

          {/* Name */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Rule Name *</label>
            <input
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              placeholder="e.g. 14-Day Win-Back"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
            />
          </div>

          {/* Subject */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">
              Notification Title <span className="text-zinc-600 font-normal normal-case">(optional)</span>
            </label>
            <input
              value={form.subject ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, subject: e.target.value }))}
              placeholder="e.g. We miss you!"
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all"
            />
          </div>

          {/* Body */}
          <div>
            <label className="block text-[10px] font-black text-zinc-500 uppercase tracking-widest mb-2 px-1">Message Body *</label>
            <textarea
              value={form.body}
              onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
              rows={4}
              placeholder="Write your message here..."
              className="w-full bg-white/[0.03] border border-white/10 rounded-2xl px-5 py-4 text-white font-bold focus:outline-none focus:border-[#F1C40F]/50 transition-all resize-none"
            />
            <p className="text-right text-[10px] text-zinc-600 mt-1">{form.body.length} characters</p>
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
            {form.channels.length === 0 && (
              <p className="text-[10px] text-red-500 font-bold mt-2 px-1">Select at least one delivery channel</p>
            )}
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
            onClick={() => isValid && onSave(form)}
            disabled={!isValid || loading}
            className="px-8 py-4 bg-[#F1C40F] !text-black rounded-2xl font-black uppercase tracking-widest text-[10px] disabled:opacity-40 flex items-center gap-2 transition-all"
          >
            {loading && <Loader2 className="animate-spin" size={14} />}
            {rule ? (loading ? "Saving..." : "Save Changes") : (loading ? "Creating..." : "Create Rule")}
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── Page ─────────────────────────────────────────────────────────────────────

export default function AutomationsPage() {
  const { gyms, selectedGymId, isGymsLoading: gymsLoading, userRole } = useGymSelection();
  const { token } = useAuthStore();
  const queryClient = useQueryClient();
  const gymId = selectedGymId as string;

  const [editingRule, setEditingRule] = useState<AutomationRule | null | undefined>(undefined); // undefined = closed
  const [runResult, setRunResult] = useState<{ name: string; fired: number } | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ["automations", gymId],
    queryFn: () => automationsApi.list(gymId, token!),
    enabled: !!token,
  });

  const rules: AutomationRule[] = (data as { data: AutomationRule[] })?.data ?? (Array.isArray(data) ? data : []);

  const createMutation = useMutation({
    mutationFn: (d: CreateAutomationRuleData) => automationsApi.create(gymId, d, token!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["automations", gymId] });
      setEditingRule(undefined);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<CreateAutomationRuleData> & { isActive?: boolean } }) =>
      automationsApi.update(gymId, id, data, token!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["automations", gymId] }),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => automationsApi.delete(gymId, id, token!),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["automations", gymId] }),
  });

  const runNowMutation = useMutation({
    mutationFn: ({ id, name }: { id: string; name: string }) =>
      automationsApi.runNow(gymId, id, token!).then((res) => ({ res, name })),
    onSuccess: ({ res, name }) => {
      queryClient.invalidateQueries({ queryKey: ["automations", gymId] });
      const fired = res.data?.fired ?? 0;
      setRunResult({ name, fired });
      setTimeout(() => setRunResult(null), 4000);
    },
  });

  const handleSave = (formData: CreateAutomationRuleData) => {
    if (editingRule) {
      updateMutation.mutate({ id: editingRule.id, data: formData });
    } else {
      createMutation.mutate(formData);
    }
  };

  const activeCount = rules.filter((r) => r.isActive).length;
  const totalFired = rules.reduce((s, r) => s + r.totalFired, 0);

  const grouped = {
    onboarding: rules.filter((r) => TRIGGER_CATEGORY[r.trigger] === "onboarding"),
    retention:  rules.filter((r) => TRIGGER_CATEGORY[r.trigger] === "retention"),
    expiry:     rules.filter((r) => TRIGGER_CATEGORY[r.trigger] === "expiry"),
  };

  return (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <PageHeader
        title="Automation Rules"
        description="Set up rules that automatically send messages when members hit key milestones."
        icon={<Zap size={32} />}
        actions={
          <>
            <button
              onClick={() => setEditingRule(null)}
              className="flex items-center justify-center gap-2 px-6 py-3 bg-[#F1C40F] !text-black font-black rounded-xl hover:bg-[#F4D03F] transition-all whitespace-nowrap uppercase text-[10px] tracking-widest shadow-lg shadow-[#F1C40F]/10 shrink-0"
            >
              <Plus size={18} />
              New Rule
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
      {rules.length > 0 && (
        <div className="grid grid-cols-2 lg:grid-cols-3 gap-6">
          {[
            { label: "Total Rules", value: rules.length, sub: "configured", icon: Zap, color: "blue" },
            { label: "Active Rules", value: activeCount, sub: "running hourly", icon: Play, color: "green" },
            { label: "Total Sent", value: totalFired.toLocaleString(), sub: "messages fired", icon: Send, color: "yellow" },
          ].map((s) => {
            const Icon = s.icon;
            const colorClass = s.color === "blue" ? "text-blue-400" : s.color === "green" ? "text-green-400" : "text-yellow-400";
            const bgClass = s.color === "blue" ? "bg-blue-500/10" : s.color === "green" ? "bg-green-500/10" : "bg-yellow-500/10";
            
            return (
              <div key={s.label} className="group relative overflow-hidden bg-[#121721] border border-white/5 rounded-2xl p-5 hover:border-[#F1C40F]/30 transition-all duration-300">
                <div className="relative flex items-center gap-4">
                  <div className={`p-3 ${bgClass} rounded-xl group-hover:scale-110 transition-transform duration-300`}>
                    <Icon className={colorClass} size={24} />
                  </div>
                  <div>
                    <p className="text-xs font-medium text-zinc-500 uppercase tracking-wider">{s.label}</p>
                    <p className="text-3xl font-bold text-white mt-1">{s.value}</p>
                    <p className="text-[10px] text-zinc-600 mt-1 uppercase font-black tracking-widest leading-none">{s.sub}</p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Run feedback toast */}
      {runResult && (
        <div className="bg-green-500/10 border border-green-500/30 rounded-xl px-4 py-3 text-sm text-green-400 flex items-center gap-2">
          <CheckCircle2 size={16} />
          <span>
            <strong>{runResult.name}</strong> ran — {runResult.fired} message{runResult.fired !== 1 ? "s" : ""} sent.
          </span>
        </div>
      )}

      {/* Rules grouped */}
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="animate-spin text-[#F1C40F]" size={32} />
        </div>
      ) : rules.length === 0 ? (
        <div className="text-center py-24 bg-[#121721] border border-white/5 border-dashed rounded-[2.5rem] flex flex-col items-center justify-center">
          <div className="p-6 bg-zinc-900/50 rounded-3xl border border-white/5 mb-6">
            <Zap size={48} className="text-zinc-700" />
          </div>
          <h3 className="text-xl font-black text-white uppercase tracking-tight italic">No automation rules yet</h3>
          <p className="text-zinc-500 mt-2 max-w-xs font-black text-[10px] uppercase tracking-widest">Create your first rule to start automating member communications based on milestones.</p>
          <button
            onClick={() => setEditingRule(null)}
            className="mt-8 flex items-center justify-center gap-3 px-8 py-4 bg-[#F1C40F] !text-black font-black rounded-xl text-[10px] uppercase tracking-widest hover:bg-[#F4D03F] transition-all shadow-lg shadow-[#F1C40F]/10"
          >
            <Plus size={16} />
            Create First Rule
          </button>
        </div>
      ) : (
        <div className="space-y-6">
          {(["onboarding", "retention", "expiry"] as const).map((cat) => {
            if (grouped[cat].length === 0) return null;
            const colors = CATEGORY_COLORS[cat];
            return (
              <div key={cat}>
                <p className={clsx(
                  "text-[10px] font-black uppercase tracking-[0.2em] mb-3 px-1",
                  colors.text
                )}>
                  {CATEGORY_LABELS[cat]} ({grouped[cat].length})
                </p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {grouped[cat].map((rule) => (
                    <RuleCard
                      key={rule.id}
                      rule={rule}
                      onEdit={(r) => setEditingRule(r)}
                      onToggle={(r) => updateMutation.mutate({ id: r.id, data: { isActive: !r.isActive } })}
                      onDelete={(r) => {
                        if (confirm(`Delete rule "${r.name}"?`)) deleteMutation.mutate(r.id);
                      }}
                      onRunNow={(r) => runNowMutation.mutate({ id: r.id, name: r.name })}
                    />
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal */}
      {editingRule !== undefined && (
        <RuleModal
          rule={editingRule}
          onClose={() => setEditingRule(undefined)}
          onSave={handleSave}
          loading={createMutation.isPending || updateMutation.isPending}
        />
      )}
    </div>
  );
}

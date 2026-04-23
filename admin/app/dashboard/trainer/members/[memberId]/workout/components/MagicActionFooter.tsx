"use client";

import { Plus, Star, RefreshCw, ClipboardList, Check, Pencil } from "lucide-react";

interface MagicActionFooterProps {
  /** Label on the primary Add button. Defaults to "Add Session" */
  addLabel?: string;
  onAdd: () => void;
  onImport: () => void;
  onLibrary: () => void;
  onCopy?: () => void;
  /** Whether the current day has content (controls Repeat button active state) */
  hasItems?: boolean;
  /** Deprecated aliases — still accepted for backwards compatibility */
  hasRoutines?: boolean;
  hasMeals?: boolean;
  isDraft?: boolean;
  /** Workout path: one-way "Activate" button */
  onActivate?: () => void;
  /** Diet path: two-way Draft ↔ Published toggle */
  onToggleDraft?: () => void;
}

export function MagicActionFooter({
  addLabel = "Add Session",
  onAdd,
  onImport,
  onLibrary,
  onCopy,
  hasItems,
  hasRoutines,
  hasMeals,
  isDraft,
  onActivate,
  onToggleDraft,
}: MagicActionFooterProps) {
  const hasContent = hasItems ?? hasRoutines ?? hasMeals ?? false;
  const draftAction = onActivate ?? onToggleDraft;

  return (
    <div className="sticky bottom-0 left-0 right-0 z-[100] bg-zinc-950/80 backdrop-blur-3xl border-t border-white/5 p-4 animate-in slide-in-from-bottom-full duration-500">
      <div className="max-w-5xl mx-auto flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <button
            onClick={onAdd}
            className="group flex items-center gap-2 px-8 py-4 bg-[#F1C40F] text-black text-sm font-black uppercase tracking-wider rounded-2xl hover:bg-[#F4D03F] transition-all shadow-[0_8px_30px_rgba(241,196,15,0.2)] active:scale-95"
          >
            <Plus size={18} strokeWidth={3} className="transition-transform group-hover:rotate-90 duration-300" />
            {addLabel}
          </button>

          {/* AI Magic — disabled / coming soon */}
          <button
            disabled
            title="Coming soon"
            className="flex items-center gap-2 px-8 py-4 bg-zinc-900/50 text-zinc-600 text-sm font-black uppercase tracking-wider rounded-2xl border border-white/5 cursor-not-allowed select-none"
          >
            AI Magic ✨
          </button>
        </div>

        <div className="flex items-center gap-3">
          {draftAction && (
            <button
              onClick={draftAction}
              className={`flex items-center gap-2 px-6 py-4 rounded-2xl border transition-all font-black text-[10px] uppercase tracking-widest ${
                isDraft
                  ? "bg-amber-500/10 text-amber-500 border-amber-500/20 hover:bg-amber-500/20"
                  : "bg-emerald-500/10 text-emerald-500 border-emerald-500/20 hover:bg-emerald-500/20"
              }`}
            >
              {isDraft ? <Pencil size={14} /> : <Check size={14} />}
              {isDraft ? "Draft" : "Published"}
            </button>
          )}

          <div className="w-px h-8 bg-zinc-800 mx-2" />

          {onCopy && (
            <button
              onClick={onCopy}
              disabled={!hasContent}
              className={`group flex flex-col items-center justify-center p-3 transition-all rounded-2xl border ${
                hasContent
                  ? "bg-emerald-500/10 text-emerald-500 border-emerald-500/20 hover:bg-emerald-500/40 shadow-[0_0_20px_rgba(16,185,129,0.1)]"
                  : "bg-zinc-900/50 text-zinc-700 border-white/5 opacity-40 cursor-not-allowed"
              }`}
              title="Copy day"
            >
              <RefreshCw size={20} className={hasContent ? "group-hover:rotate-180 transition-transform duration-500" : ""} />
              <span className="text-[7px] font-black uppercase tracking-wider mt-1 opacity-60">Repeat</span>
            </button>
          )}

          <button
            onClick={onImport}
            className="group flex flex-col items-center justify-center p-3 bg-white/5 text-zinc-400 hover:text-white hover:bg-white/10 transition-all rounded-2xl border border-white/5"
            title="Import"
          >
            <ClipboardList size={20} />
            <span className="text-[7px] font-black uppercase tracking-wider mt-1 opacity-60">Import</span>
          </button>

          <button
            onClick={onLibrary}
            className="group flex flex-col items-center justify-center p-3 bg-violet-600/10 text-violet-400 hover:text-white hover:bg-violet-600/40 transition-all rounded-2xl border border-violet-500/20 shadow-[0_0_20px_rgba(139,92,246,0.1)]"
            title="Vault"
          >
            <Star size={20} />
            <span className="text-[7px] font-black uppercase tracking-wider mt-1 opacity-60">Vault</span>
          </button>
        </div>
      </div>
    </div>
  );
}

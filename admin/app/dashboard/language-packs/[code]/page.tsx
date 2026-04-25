"use client";

import { useState, useEffect, useRef, useMemo } from "react";
import { useRouter, useParams } from "next/navigation";
import { useAuthStore, isSuperAdmin } from "@/lib/auth-store";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "@/lib/api";
import {
  ArrowLeft,
  Save,
  Upload,
  Download,
  CheckCircle2,
  EyeOff,
  Loader2,
  AlertCircle,
  Send,
} from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────────

interface TranslationRow {
  key: string;
  english: string;
  translation: string;
  isMissing: boolean;
}

interface PackDetail {
  code: string;
  displayName: string;
  englishName: string;
  countryCode: string;
  version: number;
  gymCount: number;
  isPublished: boolean;
  isDraft: boolean;
  rows: TranslationRow[];
  totalKeys: number;
  translatedKeys: number;
  missingKeys: number;
}

// ── Flag helper ───────────────────────────────────────────────────────────────

function flag(countryCode: string): string {
  const c = (countryCode || "").toUpperCase();
  if (c.length !== 2) return "🌐";
  const cp = (ch: string) => 0x1f1e6 + ch.charCodeAt(0) - 65;
  return String.fromCodePoint(cp(c[0]), cp(c[1]));
}

// ── Page ──────────────────────────────────────────────────────────────────────

export default function PackEditorPage() {
  const params  = useParams();
  const code    = (params?.code as string) ?? "";
  const router  = useRouter();
  const { user, token } = useAuthStore();
  const queryClient = useQueryClient();

  const [localValues, setLocalValues] = useState<Record<string, string>>({});
  const [edits,       setEdits]       = useState<Record<string, string>>({});
  const [filter,      setFilter]      = useState<"all" | "missing" | "translated">("all");
  const [search,      setSearch]      = useState("");
  const [showImport,  setShowImport]  = useState(false);
  const [importText,  setImportText]  = useState("");
  const [importError, setImportError] = useState<string | null>(null);
  const loadedRef = useRef<string | null>(null);

  useEffect(() => {
    if (user && !isSuperAdmin(user.role)) router.push("/dashboard");
  }, [user, router]);

  // ── Load pack ──────────────────────────────────────────────────────────────

  const { data: pack, isLoading, error } = useQuery<PackDetail>({
    queryKey: ["language-pack", code],
    queryFn: () => api<PackDetail>(`/admin/language-packs/${code}`, { token: token! }),
    enabled: !!token && !!code,
  });

  // Initialise local values once when pack first loads (or changes code)
  useEffect(() => {
    if (pack && loadedRef.current !== code) {
      loadedRef.current = code;
      const init: Record<string, string> = {};
      pack.rows.forEach((r) => { init[r.key] = r.translation; });
      setLocalValues(init);
      setEdits({});
    }
  }, [pack, code]);

  // ── Mutations ──────────────────────────────────────────────────────────────

  const saveMutation = useMutation({
    mutationFn: async () => {
      const snapshot = { ...edits };
      await api(`/admin/language-packs/${code}`, {
        method: "PATCH",
        body: { translations: snapshot },
        token: token!,
      });
      return snapshot;
    },
    onSuccess: (saved) => {
      setLocalValues((prev) => ({ ...prev, ...saved }));
      setEdits({});
      queryClient.invalidateQueries({ queryKey: ["language-pack", code] });
      queryClient.invalidateQueries({ queryKey: ["language-packs"] });
    },
  });

  const publishMutation = useMutation({
    mutationFn: (isPublished: boolean) =>
      api(`/admin/language-packs/${code}`, {
        method: "PATCH",
        body: { isPublished },
        token: token!,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["language-pack", code] });
      queryClient.invalidateQueries({ queryKey: ["language-packs"] });
    },
  });

  const pushMutation = useMutation({
    mutationFn: () =>
      api(`/admin/language-packs/${code}/push`, { method: "POST", token: token! }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["language-pack", code] });
      queryClient.invalidateQueries({ queryKey: ["language-packs"] });
    },
  });

  // ── Derived state ──────────────────────────────────────────────────────────

  function getVal(key: string) {
    return localValues[key] ?? "";
  }

  function handleChange(key: string, val: string) {
    setLocalValues((prev) => ({ ...prev, [key]: val }));
    const original = pack?.rows.find((r) => r.key === key)?.translation ?? "";
    if (val !== original) {
      setEdits((prev) => ({ ...prev, [key]: val }));
    } else {
      setEdits((prev) => {
        const next = { ...prev };
        delete next[key];
        return next;
      });
    }
  }

  const liveStats = useMemo(() => {
    if (!pack) return { translated: 0, missing: 0, total: 0 };
    const translated = pack.rows.filter((r) => !!getVal(r.key)).length;
    return { translated, missing: pack.totalKeys - translated, total: pack.totalKeys };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pack, localValues]);

  const progress = liveStats.total > 0 ? (liveStats.translated / liveStats.total) * 100 : 0;

  const visibleRows = useMemo(() => {
    if (!pack) return [];
    return pack.rows
      .map((r) => ({
        ...r,
        currentVal: getVal(r.key),
        isMissing: !getVal(r.key),
        isDirty: r.key in edits,
      }))
      .filter((r) => {
        if (filter === "missing"    && !r.isMissing) return false;
        if (filter === "translated" &&  r.isMissing) return false;
        if (search) {
          const q = search.toLowerCase();
          return r.key.includes(q) || r.english.toLowerCase().includes(q) || r.currentVal.toLowerCase().includes(q);
        }
        return true;
      });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pack, localValues, edits, filter, search]);

  const dirtyCount = Object.keys(edits).length;

  // ── Export / Import ────────────────────────────────────────────────────────

  function handleExport() {
    if (!pack) return;
    const out: Record<string, string> = {};
    pack.rows.forEach((r) => { const v = getVal(r.key); if (v) out[r.key] = v; });
    const blob = new Blob([JSON.stringify(out, null, 2)], { type: "application/json" });
    const url  = URL.createObjectURL(blob);
    const a    = document.createElement("a");
    a.href = url; a.download = `${code}.json`; a.click();
    URL.revokeObjectURL(url);
  }

  function handleImport() {
    setImportError(null);
    try {
      const parsed = JSON.parse(importText);
      if (typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("Must be a JSON object");
      const next = { ...localValues };
      const nextEdits = { ...edits };
      Object.entries(parsed).forEach(([k, v]) => {
        if (typeof v === "string") {
          next[k] = v;
          const original = pack?.rows.find((r) => r.key === k)?.translation ?? "";
          if (v !== original) nextEdits[k] = v;
        }
      });
      setLocalValues(next);
      setEdits(nextEdits);
      setImportText("");
      setShowImport(false);
    } catch (e: unknown) {
      setImportError(e instanceof Error ? e.message : "Invalid JSON");
    }
  }

  // ── Render ─────────────────────────────────────────────────────────────────

  if (isLoading) return (
    <div className="flex items-center justify-center h-64 text-zinc-500">
      <Loader2 size={20} className="animate-spin mr-2" /> Loading pack…
    </div>
  );

  if (error || !pack) return (
    <div className="flex items-center gap-2 text-red-400 py-8">
      <AlertCircle size={16} /> Failed to load language pack.
    </div>
  );

  return (
    <div className="space-y-6 pb-32">

      {/* ── Breadcrumb + header ── */}
      <div className="flex items-start gap-4 flex-wrap">
        <button
          onClick={() => router.push("/dashboard/language-packs")}
          className="flex items-center gap-1.5 text-sm text-zinc-500 hover:text-white transition-colors mt-1"
        >
          <ArrowLeft size={14} /> Packs
        </button>

        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-3 flex-wrap">
            <span className="text-4xl leading-none">{flag(pack.countryCode)}</span>
            <div>
              <div className="flex items-center gap-2 flex-wrap">
                <h1 className="text-xl font-bold text-white">{pack.displayName}</h1>
                <span className="text-[10px] font-black text-zinc-600 bg-zinc-800 px-2 py-0.5 rounded uppercase tracking-widest">
                  v{pack.version}{dirtyCount > 0 ? "+" : ""}
                </span>
                <span className="text-[10px] font-mono text-zinc-600 uppercase">{pack.code}</span>
                {pack.isDraft && (
                  <span className="text-[10px] font-bold text-orange-400 bg-orange-400/10 border border-orange-400/25 px-2 py-0.5 rounded">
                    Draft
                  </span>
                )}
              </div>
              <p className="text-xs text-zinc-500 mt-0.5">
                {pack.gymCount} gym{pack.gymCount !== 1 ? "s" : ""} using this language
              </p>
            </div>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-2 flex-wrap">
          <button
            onClick={handleExport}
            className="flex items-center gap-1.5 px-3 py-2 text-xs font-bold text-zinc-400 hover:text-white border border-zinc-700 hover:border-zinc-600 rounded-xl transition-colors"
          >
            <Download size={13} /> Export JSON
          </button>
          <button
            onClick={() => setShowImport(true)}
            className="flex items-center gap-1.5 px-3 py-2 text-xs font-bold text-zinc-400 hover:text-white border border-zinc-700 hover:border-zinc-600 rounded-xl transition-colors"
          >
            <Upload size={13} /> Import JSON
          </button>
          <button
            onClick={() => {
              if (window.confirm(`Push to all ${pack.gymCount} gym(s) and publish? This will overwrite any gym-specific translations.`))
                pushMutation.mutate();
            }}
            disabled={pushMutation.isPending}
            className="flex items-center gap-1.5 px-3 py-2 text-xs font-bold text-zinc-400 hover:text-white border border-zinc-700 hover:border-zinc-600 rounded-xl transition-colors disabled:opacity-40"
          >
            {pushMutation.isPending ? <Loader2 size={13} className="animate-spin" /> : <Send size={13} />}
            Push to Gyms
          </button>
          <button
            onClick={() => publishMutation.mutate(!pack.isPublished)}
            disabled={publishMutation.isPending}
            className={`flex items-center gap-1.5 px-3 py-2 text-xs font-bold rounded-xl border transition-colors disabled:opacity-40 ${
              pack.isPublished
                ? "border-red-500/30 text-red-400 hover:bg-red-500/10"
                : "border-[#F1C40F]/40 text-[#F1C40F] hover:bg-[#F1C40F]/10"
            }`}
          >
            {publishMutation.isPending ? (
              <Loader2 size={13} className="animate-spin" />
            ) : pack.isPublished ? (
              <><EyeOff size={13} /> Unpublish</>
            ) : (
              <><CheckCircle2 size={13} /> Publish</>
            )}
          </button>
        </div>
      </div>

      {/* ── Progress bar ── */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl p-5 space-y-3">
        <div className="flex items-center justify-between text-xs">
          <span className="text-zinc-400 font-bold">
            {liveStats.translated} / {liveStats.total} keys translated
          </span>
          <span className={`font-bold ${
            progress === 100 ? "text-green-400" : progress >= 50 ? "text-[#F1C40F]" : "text-orange-400"
          }`}>
            {Math.round(progress)}%
          </span>
        </div>
        <div className="h-2 bg-zinc-800 rounded-full overflow-hidden">
          <div
            className={`h-full rounded-full transition-all duration-500 ${
              progress === 100 ? "bg-green-400" : progress >= 50 ? "bg-[#F1C40F]" : "bg-orange-400"
            }`}
            style={{ width: `${progress}%` }}
          />
        </div>
        <div className="flex items-center gap-4 text-[11px]">
          <span className="text-green-400/70">{liveStats.translated} translated</span>
          <span className="text-red-400/70">{liveStats.missing} missing</span>
          {dirtyCount > 0 && (
            <span className="text-[#F1C40F]/80">{dirtyCount} unsaved</span>
          )}
        </div>
      </div>

      {/* ── Toolbar ── */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="flex bg-[#121721] border border-zinc-800 rounded-xl p-1 gap-0.5">
          {[
            { key: "all",        label: `All (${liveStats.total})` },
            { key: "missing",    label: `Missing (${liveStats.missing})` },
            { key: "translated", label: `Done (${liveStats.translated})` },
          ].map((tab) => (
            <button
              key={tab.key}
              onClick={() => setFilter(tab.key as typeof filter)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-colors ${
                filter === tab.key
                  ? "bg-[#F1C40F]/15 text-[#F1C40F] border border-[#F1C40F]/30"
                  : "text-zinc-500 hover:text-white"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search key or text…"
          className="flex-1 min-w-[200px] bg-[#121721] border border-zinc-800 rounded-xl px-4 py-2 text-sm text-white placeholder-zinc-600 focus:outline-none focus:border-zinc-600 transition-colors"
        />
        <span className="text-xs text-zinc-600 tabular-nums">{visibleRows.length} rows</span>
      </div>

      {/* ── Translation table ── */}
      <div className="bg-[#121721] border border-zinc-800 rounded-2xl overflow-hidden">
        {/* Header */}
        <div className="grid grid-cols-[1fr_1.5fr_2fr_72px] gap-4 px-5 py-3 border-b border-zinc-800 bg-zinc-900/50 sticky top-0 z-10">
          <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Key</span>
          <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">English</span>
          <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest">Translation</span>
          <span className="text-[10px] font-black text-zinc-600 uppercase tracking-widest text-center">Status</span>
        </div>

        {/* Rows */}
        <div className="divide-y divide-zinc-800/50">
          {visibleRows.length === 0 ? (
            <div className="py-12 text-center text-sm text-zinc-600">
              No rows match your filter.
            </div>
          ) : (
            visibleRows.map((row) => (
              <div
                key={row.key}
                className={`grid grid-cols-[1fr_1.5fr_2fr_72px] gap-4 items-center px-5 py-3 hover:bg-zinc-800/20 transition-colors ${
                  row.isDirty    ? "border-l-2 border-l-[#F1C40F]/70" :
                  row.isMissing  ? "border-l-2 border-l-red-500/40"   : ""
                }`}
              >
                <span className="text-[11px] font-mono text-zinc-500 truncate" title={row.key}>
                  {row.key}
                </span>
                <span className="text-xs text-zinc-300 truncate" title={row.english}>
                  {row.english}
                </span>
                <input
                  type="text"
                  value={row.currentVal}
                  onChange={(e) => handleChange(row.key, e.target.value)}
                  placeholder="…"
                  className="w-full bg-zinc-900/60 border border-zinc-700/50 hover:border-zinc-600 focus:border-[#F1C40F]/50 rounded-lg px-3 py-1.5 text-xs text-white placeholder-zinc-600 focus:outline-none transition-colors"
                />
                <div className="flex justify-center">
                  {row.isMissing ? (
                    <span className="text-[9px] font-bold text-red-400 bg-red-400/10 border border-red-400/20 px-2 py-0.5 rounded whitespace-nowrap">
                      Missing
                    </span>
                  ) : (
                    <CheckCircle2 size={14} className="text-green-400/60" />
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* ── Import modal ── */}
      {showImport && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
          <div className="bg-[#121721] border border-zinc-800 rounded-2xl w-full max-w-lg shadow-2xl">
            <div className="flex items-center justify-between px-6 py-5 border-b border-zinc-800">
              <div className="flex items-center gap-2">
                <Upload size={16} className="text-[#F1C40F]" />
                <h3 className="text-sm font-bold text-white">Import JSON</h3>
              </div>
              <button
                onClick={() => { setShowImport(false); setImportText(""); setImportError(null); }}
                className="text-zinc-500 hover:text-white transition-colors text-lg leading-none"
              >
                ✕
              </button>
            </div>
            <div className="p-6 space-y-4">
              <p className="text-xs text-zinc-500">
                Paste a JSON object. Existing keys will be overwritten in the editor.
                Changes aren&apos;t saved until you click &ldquo;Save &amp; Bump Version&rdquo;.
              </p>
              <textarea
                value={importText}
                onChange={(e) => setImportText(e.target.value)}
                placeholder={'{\n  "button.save": "შენახვა",\n  "button.cancel": "გაუქმება"\n}'}
                rows={10}
                className="w-full bg-zinc-900 border border-zinc-700 rounded-xl px-4 py-3 text-xs text-white font-mono placeholder-zinc-600 focus:outline-none focus:border-zinc-600 resize-none"
              />
              {importError && (
                <div className="flex items-center gap-2 text-red-400 text-xs">
                  <AlertCircle size={12} /> {importError}
                </div>
              )}
              <button
                onClick={handleImport}
                className="w-full py-2.5 bg-[#F1C40F] hover:bg-[#F1C40F]/90 text-black text-sm font-bold rounded-xl transition-colors"
              >
                Apply to Editor
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Floating save bar ── */}
      {dirtyCount > 0 && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40 pointer-events-none">
          <div className="pointer-events-auto flex items-center gap-3 bg-[#1A2035] border border-[#F1C40F]/30 rounded-2xl px-5 py-3 shadow-2xl shadow-black/60">
            <span className="text-xs text-zinc-400">
              <span className="text-[#F1C40F] font-bold">{dirtyCount}</span>{" "}
              unsaved change{dirtyCount !== 1 ? "s" : ""}
            </span>
            {saveMutation.isError && (
              <span className="text-xs text-red-400">Save failed — retry?</span>
            )}
            <button
              onClick={() => saveMutation.mutate()}
              disabled={saveMutation.isPending}
              className="flex items-center gap-1.5 px-4 py-1.5 bg-[#F1C40F] hover:bg-[#F1C40F]/90 disabled:opacity-60 text-black text-xs font-bold rounded-xl transition-colors"
            >
              {saveMutation.isPending
                ? <Loader2 size={13} className="animate-spin" />
                : <Save size={13} />
              }
              Save &amp; Bump Version
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
